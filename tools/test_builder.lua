--[[
  Offline test for a scenario builder.

    lua tools/test_builder.lua scenarios/<folder>/<builder>.lua

  Runs the builder against tools/cmo_mock.lua, then plays the scenario's
  scripted logic end to end three times, using the builder's own runtime
  configuration:

    single  single player, Anguilla AI
    coop    real-time multiplayer, both humans on the United Kingdom
    pvp     real-time multiplayer, one human per side

  Every lift lands, every objective falls, the police reach The Valley and
  the scenario ends.  Combat is not simulated; defenders are simply removed
  so the event logic can be exercised.
]]

local here = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
local path = assert(arg and arg[1], 'usage: lua tools/test_builder.lua <builder.lua>')

local failures = 0
local function check(cond, what)
  if cond then print('  ok    ' .. what) else failures = failures + 1 print('  FAIL  ' .. what) end
end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function dist(a1, o1, a2, o2)
  local r = math.pi / 180
  local h = math.sin((a2 - a1) * r / 2) ^ 2 + math.cos(a1 * r) * math.cos(a2 * r) * math.sin((o2 - o1) * r / 2) ^ 2
  return 2 * 6371000 * math.asin(math.min(1, math.sqrt(h)))
end

local function run(mode)
  print('')
  print('######## Mode: ' .. mode)
  local M = dofile(here .. 'cmo_mock.lua')  -- fresh game state; rebinds the API globals

  -- 1. Build.  Capture print() so the builder report is shown indented.
  local report = {}
  local realprint = print
  print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring(select(i, ...)) end
                        report[#report + 1] = table.concat(t, ' ') end
  -- A database that rejects the generic loadout 3 exercises the fallback chain.
  M.rejectLoadouts = { [3] = true }
  local ok, err = pcall(dofile, path)
  print = realprint
  if mode == 'single' then for _, l in ipairs(report) do print('   | ' .. l) end end
  check(ok, 'builder runs without error' .. (ok and '' or (': ' .. tostring(err))))
  if not ok then return end
  local failedLines = 0
  for _, l in ipairs(report) do if l:match('^FAILED') then failedLines = failedLines + 1 end end
  check(failedLines == 0, 'no failed placements, missions or events')

  -- 2. Pull the runtime configuration back out of the heartbeat action.
  local hb
  for name, script in pairs(M.actions) do if name:match('Heartbeat') then hb = script end end
  check(hb ~= nil, 'heartbeat action exists')
  local RT = load('return ' .. hb:match('^local RT = (.-)\n'))()
  local UK, AI = RT.uk, RT.opfor
  print(string.format('== Built %d units, %d missions, %d events', count(M.units), count(M.missions), count(M.events)))

  -- Session set-up for this mode.
  M.rtmp = (mode ~= 'single')
  M.humans = { [UK] = true, [AI] = (mode == 'pvp') }
  local pvp = (mode == 'pvp')

  -- Static checks (once is enough).
  if mode == 'single' then
    for cname, c in pairs(RT.craft) do
      check(M.unit(cname) ~= nil and M.unit(c.mother) ~= nil and RT.dest[c.dest] ~= nil, 'craft wiring: ' .. cname)
      for _, load in ipairs(c.loads) do
        for _, n in ipairs(load) do check(RT.spawn[n] ~= nil, '  spawn spec for ' .. n) end
      end
    end
    for _, n in ipairs(RT.defenders) do check(M.unit(n) ~= nil, 'defender exists: ' .. n) end
    for n in pairs(RT.kill) do check(M.unit(n) ~= nil, 'scored enemy exists: ' .. n) end
  end
  for _, st in ipairs(RT.stages) do
    if st.mission then check(M.missions[st.mission] and not M.missions[st.mission].active,
                             'staged mission starts inactive: ' .. st.mission) end
  end
  check(M.sideOptions[AI].computercontrolledonly == false, 'Anguilla is a playable side')

  -- 3. Play it through.
  local key = function(k) return M.keys[RT.prefix .. k] end
  local function dest(c) return RT.dest[c.dest] end
  local function sortedCraft()
    local t = {} for n in pairs(RT.craft) do t[#t + 1] = n end table.sort(t) return t
  end
  local function msgsFor(side)
    local n = 0
    for _, m in ipairs(M.messages) do if m:sub(1, #side + 2) == '[' .. side .. ']' then n = n + 1 end end
    return n
  end
  local function eventNamed(pat)
    for name, ev in pairs(M.events) do if name:match(pat) then return ev end end
  end

  M.tick(0)
  check(msgsFor(UK) >= 1 and M.messages[1]:match(RT.intro:sub(1, 20)), 'UK intro message shown')
  check(key('session') == (M.rtmp and 'RTMP' or 'single') .. (pvp and '/pvp' or '/vs-ai'),
        'session recorded as ' .. tostring(key('session')))
  check((msgsFor(AI) >= 1) == pvp, 'Anguillan intro only when Anguilla is human')
  check(M.doctrine[UK].weapon_control_status_land == 2 and M.doctrine[UK].weapon_control_status_air == 2,
        'UK starts on WEAPONS HOLD')

  -- Firing first is penalised for the UK and rewarded for Anguilla.
  local early
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.side == AI and u.type == 'Aircraft' then early = u.name break end
  end
  local su, sa = M.score[UK], M.score[AI]
  M.kill(early)
  check(M.score[UK] < su and M.score[AI] > sa - math.abs(RT.kill[early] or 0) + RT.roe_violation - 1,
        'ROE violation scored both ways (' .. early .. ')')

  -- Lose one helicopter while loaded to test the cargo-loss penalty.
  local victim
  for _, n in ipairs(sortedCraft()) do if dest(RT.craft[n]).air then victim = n end end
  local before, beforeAI = M.score[UK], M.score[AI]
  M.kill(victim)
  check(key('cs_' .. victim) == 'lost', 'loaded helicopter lost: ' .. victim)
  check(M.score[UK] < before - (RT.loss[victim] or 0), 'cargo-loss penalty applied for ' .. victim)
  check(M.score[AI] > beforeAI + (RT.loss[victim] or 0), 'Anguilla scores the helicopter and its troops')

  -- First waves.
  local barks0 = #M.barks
  for _, n in ipairs(sortedCraft()) do
    if n ~= victim then
      local d = dest(RT.craft[n])
      M.move(n, d.lat, d.lon, d.air and 100 or 0)
      M.tick(1)
      check(key('cs_' .. n) == 'empty', n .. ' delivered wave 1')
      for _, u in ipairs(RT.craft[n].loads[1]) do check(M.unit(u) ~= nil, '  ' .. u .. ' is ashore') end
    end
  end
  if mode == 'coop' then
    check(#M.barks > barks0, 'co-op: routine landing news shown as map barks')
  else
    check(#M.barks == barks0, mode .. ': no map barks (side-addressed messages only)')
  end

  -- A craft whose next wave is gated must wait.
  for _, n in ipairs(sortedCraft()) do
    local c = RT.craft[n]
    if c.loads[2] and c.loads[2].requires then
      local m = M.unit(c.mother)
      M.move(n, m.lat, m.lon)
      M.tick(1)
      check(key('cs_' .. n) == 'empty' and key('wait_' .. n) == '1', n .. ' waits for ' .. c.loads[2].requires)
    end
  end

  -- ROE release on a detected launch; that event must fire only once.
  M.fire('UnitDetected', { name = 'Inbound missile', side = AI, type = 'Weapon' })
  M.fire('UnitDetected', { name = 'Second missile', side = AI, type = 'Weapon' })
  check(key('roe') == '1' and M.doctrine[UK].weapon_control_status_land == 1 and M.doctrine[UK].weapon_control_status_air == 1,
        'ROE released on hostile launch')
  check(eventNamed('Hostile weapon detected').fired == 1, 'launch-detection event fired once, not per missile')
  local s0, a0 = M.score[UK], M.score[AI]
  local ship = sortedCraft()[1]
  M.damage(ship)
  M.damage(ship)
  check(M.score[UK] == s0 - RT.ship_hit and M.score[AI] == a0 + RT.ship_hit, 'ship hit scored once, both sides')
  local paras
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.side == UK and u.type == 'Facility' and RT.spawn[u.name] then paras = u.name break end
  end
  M.damage(paras); M.damage(paras)
  check(eventNamed('UK hit Facility').fired == 1, 'ground-hit event fired once, not per hit')

  -- Stage activations: AI only.
  M.tick(RT.stages[#RT.stages].at)
  for _, st in ipairs(RT.stages) do
    if st.mission then
      check(M.missions[st.mission].active == not pvp,
            (pvp and 'left for the human: ' or 'stage activated: ') .. st.mission)
    end
  end

  -- An hour passes with every objective still held.
  local aBefore = M.score[AI]
  M.tick(60)
  check(M.score[AI] == aBefore + #RT.objectives * RT.hold_pts, 'Anguilla scores each objective held at the hour')

  -- Objectives in order.  The scripted withdrawal only happens against the AI.
  local someUK = paras
  local W = RT.withdraw
  for _, o in ipairs(RT.objectives) do
    local a1 = M.score[AI]
    if W and o.name == W.name then
      for _, n in ipairs(W.needs_dead) do if M.unit(n) then M.kill(n) end end
      local moved = 0
      for _, g in ipairs(M.order) do
        local u = M.units[g]
        if u and u.side == UK and u.type == 'Facility' and RT.spawn[u.name] and moved < W.min_uk then
          M.move(u.name, W.lat + 0.004, W.lon - 0.004)
          moved = moved + 1
        end
      end
      M.tick(1)
      if pvp then
        check(key('wd') == nil, 'no scripted withdrawal against a human Anguilla')
      else
        check(key('wd') == '1', 'withdrawal triggered at ' .. W.name)
        for _, n in ipairs(W.units) do
          check(M.unit(n) and M.unit(n).course and M.unit(n).holdfire, '  ' .. n .. ' ordered to withdraw')
          M.move(n, W.dest_lat, W.dest_lon)
        end
        M.tick(1)
        check(key('wd') == '2', 'withdrawn units dispersed')
      end
    end
    for _, n in ipairs(RT.defenders) do
      local u = M.unit(n)
      if u and dist(u.lat, u.lon, o.lat, o.lon) <= o.r then M.kill(n) end
    end
    M.move(someUK, o.lat, o.lon)
    M.tick(1)
    local lost = false
    for _, l in ipairs(M.scorelog) do if l == string.format('%-15s %+5d  %s', AI, -o.pts, o.name .. ' lost') then lost = true end end
    check(key(o.key) == '1' and lost and M.score[AI] <= a1, 'objective secured (Anguilla loses it): ' .. o.name)
  end

  -- Gated second waves now go.
  for _, n in ipairs(sortedCraft()) do
    local c = RT.craft[n]
    if n ~= victim and c.loads[2] then
      local m = M.unit(c.mother)
      M.move(n, m.lat, m.lon)
      M.tick(1)
      check(key('cs_' .. n) == 'loaded' and key('cw_' .. n) == '2', n .. ' embarked wave 2')
      local d = dest(c)
      M.move(n, d.lat, d.lon, d.air and 100 or 0)
      M.tick(1)
      for _, u in ipairs(c.loads[2]) do check(M.unit(u) ~= nil, '  ' .. u .. ' is ashore') end
    end
  end

  -- Civilian losses cost both sides.
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.side == RT.civ then
      local s, a = M.score[UK], M.score[AI]
      M.kill(u.name)
      check(M.score[UK] == s - RT.civ_pts and M.score[AI] == a - RT.civ_pts, 'collateral cost to both sides: ' .. u.name)
      break
    end
  end

  -- End state.
  for _, n in ipairs(RT.police) do M.move(n, RT.valley.lat, RT.valley.lon) end
  M.tick(1)
  check(key('end_t') ~= nil, 'police in The Valley starts the end timer')
  M.tick(11)
  check(M.ended, 'scenario ends')

  local violations = 0
  for _, l in ipairs(M.scorelog) do if l:match('ROE violation') then violations = violations + 1 end end
  check(violations == 1, 'only the deliberate early kill counted as an ROE violation')

  print('== Score log')
  for _, l in ipairs(M.scorelog) do print('   ' .. l) end
  print(string.format('== %s: UK %d, Anguilla %d; %d UK messages, %d Anguilla messages, %d barks',
                      mode, M.score[UK], M.score[AI], msgsFor(UK), msgsFor(AI), #M.barks))
end

print('== Build: ' .. path)
for _, mode in ipairs({ 'single', 'coop', 'pvp' }) do run(mode) end
print('')
print(string.format('== %d failure(s)', failures))
if failures > 0 then os.exit(1) end
