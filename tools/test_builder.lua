--[[
  Offline test for a scenario builder.

    lua tools/test_builder.lua scenarios/<folder>/<builder>.lua

  Runs the builder against tools/cmo_mock.lua, then plays the scenario's
  scripted logic end to end using the builder's own runtime configuration:
  every lift lands, every objective falls, the withdrawal happens, the
  police reach The Valley and the scenario ends.  Combat is not simulated;
  defenders are simply removed so the event logic can be exercised.
]]

local here = (arg and arg[0] or ''):match('^(.*[/\\])') or './'
local M = dofile(here .. 'cmo_mock.lua')
local path = assert(arg and arg[1], 'usage: lua tools/test_builder.lua <builder.lua>')

local failures = 0
local function check(cond, what)
  if cond then print('  ok    ' .. what) else failures = failures + 1 print('  FAIL  ' .. what) end
end

-- 1. Build.  Capture print() so the builder report is shown indented.
local report = {}
local realprint = print
print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring(select(i, ...)) end
                      report[#report + 1] = table.concat(t, ' ') end
-- Simulate a database that rejects the generic loadout 3 to exercise the fallback chain.
M.rejectLoadouts = { [3] = true }
local ok, err = pcall(dofile, path)
print = realprint
print('== Build: ' .. path)
for _, l in ipairs(report) do print('   | ' .. l) end
check(ok, 'builder runs without error' .. (ok and '' or (': ' .. tostring(err))))
if not ok then os.exit(1) end
local failedLines = 0
for _, l in ipairs(report) do if l:match('^FAILED') then failedLines = failedLines + 1 end end
check(failedLines == 0, 'no failed placements, missions or events')

-- 2. Pull the runtime configuration back out of the heartbeat action.
local hb
for name, script in pairs(M.actions) do if name:match('Heartbeat') then hb = script end end
check(hb ~= nil, 'heartbeat action exists')
local RT = load('return ' .. hb:match('^local RT = (.-)\n'))()
local UK, AI = RT.uk, RT.opfor

local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
print(string.format('== Built %d units, %d missions, %d events', count(M.units), count(M.missions), count(M.events)))

-- Static checks: every name the runtime refers to must exist.
for cname, c in pairs(RT.craft) do
  check(M.unit(cname) ~= nil, 'craft exists: ' .. cname)
  check(M.unit(c.mother) ~= nil, 'mother exists: ' .. c.mother)
  check(RT.dest[c.dest] ~= nil, 'destination defined: ' .. c.dest)
  for _, load in ipairs(c.loads) do
    for _, n in ipairs(load) do check(RT.spawn[n] ~= nil, 'spawn spec for ' .. n) end
  end
end
for _, n in ipairs(RT.defenders) do check(M.unit(n) ~= nil, 'defender exists: ' .. n) end
for _, st in ipairs(RT.stages) do
  if st.mission then check(M.missions[st.mission] and not M.missions[st.mission].active,
                           'staged mission starts inactive: ' .. st.mission) end
end
for n in pairs(RT.kill) do check(M.unit(n) ~= nil, 'scored enemy exists: ' .. n) end

-- 3. Play it through.
local key = function(k) return M.keys[RT.prefix .. k] end
local function dest(c) return RT.dest[c.dest] end
local function sortedCraft()
  local t = {} for n in pairs(RT.craft) do t[#t + 1] = n end table.sort(t) return t
end

M.tick(0)
check(#M.messages >= 1 and M.messages[1]:match(RT.intro:sub(1, 20)), 'intro message shown')
check(M.doctrine[UK].weapon_control_status_land == 2 and M.doctrine[UK].weapon_control_status_air == 2,
      'UK starts on WEAPONS HOLD')

-- Lose one helicopter while loaded to test the cargo-loss penalty.
local victim
for _, n in ipairs(sortedCraft()) do if dest(RT.craft[n]).air then victim = n end end
local before = M.score[UK]
M.kill(victim)
check(key('cs_' .. victim) == 'lost', 'loaded helicopter lost: ' .. victim)
check(M.score[UK] < before - (RT.loss[victim] or 0), 'cargo-loss penalty applied for ' .. victim)

-- First waves.
for _, n in ipairs(sortedCraft()) do
  if n ~= victim then
    local d = dest(RT.craft[n])
    M.move(n, d.lat, d.lon, d.air and 100 or 0)
    M.tick(1)
    check(key('cs_' .. n) == 'empty', n .. ' delivered wave 1')
    for _, u in ipairs(RT.craft[n].loads[1]) do check(M.unit(u) ~= nil, '  ' .. u .. ' is ashore') end
  end
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

-- ROE release when a hostile weapon is detected, then a hit costs points.
M.fire('UnitDetected', { name = 'Inbound missile', side = AI, type = 'Weapon' })
check(key('roe') == '1' and M.doctrine[UK].weapon_control_status_land == 1 and M.doctrine[UK].weapon_control_status_air == 1,
      'ROE released on hostile launch')
local s0 = M.score[UK]
M.damage(sortedCraft()[1])
check(M.score[UK] == s0 - RT.ship_hit, 'ship hit penalty applied once')
M.damage(sortedCraft()[1])
check(M.score[UK] == s0 - RT.ship_hit, 'ship hit penalty not repeated')

-- Stage activations.
M.tick(RT.stages[#RT.stages].at)
for _, st in ipairs(RT.stages) do
  if st.mission then check(M.missions[st.mission].active, 'stage activated: ' .. st.mission) end
end

-- Objectives in order.  Withdrawal is exercised at its own objective.
local someUK  -- any UK ground unit to walk onto objectives
for _, g in ipairs(M.order) do
  local u = M.units[g]
  if u and u.side == UK and u.type == 'Facility' and RT.spawn[u.name] then someUK = u.name break end
end
local W = RT.withdraw
local function dist(a1, o1, a2, o2)
  local r = math.pi / 180
  local h = math.sin((a2 - a1) * r / 2) ^ 2 + math.cos(a1 * r) * math.cos(a2 * r) * math.sin((o2 - o1) * r / 2) ^ 2
  return 2 * 6371000 * math.asin(math.min(1, math.sqrt(h)))
end
for _, o in ipairs(RT.objectives) do
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
    check(key('wd') == '1', 'withdrawal triggered at ' .. W.name)
    for _, n in ipairs(W.units) do
      check(M.unit(n) and M.unit(n).course and M.unit(n).holdfire, '  ' .. n .. ' ordered to withdraw')
      M.move(n, W.dest_lat, W.dest_lon)
    end
    M.tick(1)
    check(key('wd') == '2', 'withdrawn units dispersed')
  end
  for _, n in ipairs(RT.defenders) do
    local u = M.unit(n)
    if u and dist(u.lat, u.lon, o.lat, o.lon) <= o.r then M.kill(n) end
  end
  M.move(someUK, o.lat, o.lon)
  M.tick(1)
  check(key(o.key) == '1', 'objective secured: ' .. o.name)
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

-- Civilian losses cost points.
for _, g in ipairs(M.order) do
  local u = M.units[g]
  if u and u.side == RT.civ then
    local s = M.score[UK]
    M.kill(u.name)
    check(M.score[UK] == s - RT.civ_pts, 'collateral penalty for ' .. u.name)
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
check(violations == 0, 'no ROE violations after release')

print('== Score log')
for _, l in ipairs(M.scorelog) do print('   ' .. l) end
print(string.format('== Final UK score %d; %d messages; %d failure(s)', M.score[UK], #M.messages, failures))
if failures > 0 then os.exit(1) end
