--[[
  Minimal stand-in for the Command: Modern Operations Lua API, used only to
  test the scenario builders outside the game.  It implements the calls the
  builders and their event scripts make, validates arguments the way the game
  would reject them, and lets a test drive units around and fire events.
  It does not model combat, sensors or movement.
]]

local M = { units = {}, order = {}, sides = {}, rps = {}, missions = {}, keys = {},
            triggers = {}, actions = {}, events = {}, score = {}, messages = {},
            scorelog = {}, doctrine = {}, now = 0, ended = false, unitx = nil, seq = 0 }

local TYPECODE = { Aircraft = 1, Ship = 2, Submarine = 3, Facility = 4, Weapon = 6 }
local function lower(s) return type(s) == 'string' and s:lower() or s end
local function get(t, key)  -- case-insensitive table lookup, like the game's module functions
  for k, v in pairs(t) do if lower(k) == lower(key) then return v end end
  return nil
end

local function newguid() M.seq = M.seq + 1 return string.format('guid-%04d', M.seq) end

local function wrap(u)
  if not u then return nil end
  return { name = u.name, guid = u.guid, type = u.type, side = u.side, dbid = u.dbid,
           latitude = u.lat, longitude = u.lon, altitude = u.alt or 0,
           loadoutdbid = u.loadoutid, loadout = { name = 'Loadout ' .. tostring(u.loadoutid) },
           base = u.base }
end

local function findUnit(t)
  local guid = get(t, 'guid')
  if guid then return M.units[guid] end
  local name, side = get(t, 'unitname') or get(t, 'name'), get(t, 'side')
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.name == name and (side == nil or u.side == side) then return u end
  end
  return nil
end

function SetScenarioTitle(t) M.title = t return true end
function ScenEdit_SetStartTime(t) assert(get(t, 'date') and get(t, 'time'), 'start time needs date/time') return 0 end
function ScenEdit_SetTime(t) assert(get(t, 'date') and get(t, 'time'), 'time needs date/time') return 0 end
function ScenEdit_SetWeather(a, b, c, d)
  assert(type(a) == 'number' and b >= 0 and b <= 50 and c >= 0 and c <= 1 and d >= 0 and d <= 9, 'bad weather')
  return true
end
function ScenEdit_ClearKeyValue(k) if k == '' then M.keys = {} else M.keys[k] = nil end return true end
function ScenEdit_SetKeyValue(k, v) assert(type(v) == 'string', 'key values must be strings') M.keys[k] = v end
function ScenEdit_GetKeyValue(k) return M.keys[k] or '' end

function ScenEdit_AddSide(t)
  local s = get(t, 'side') or get(t, 'name')
  assert(s and not M.sides[s], 'bad or duplicate side ' .. tostring(s))
  M.sides[s] = { name = s, posture = {} }
  M.score[s] = 0
  return M.sides[s]
end
function ScenEdit_SetSidePosture(a, b, p)
  assert(M.sides[a] and M.sides[b], 'posture on unknown side')
  assert(({ F = 1, H = 1, N = 1, U = 1 })[p], 'bad posture ' .. tostring(p))
  M.sides[a].posture[b] = p
  return true
end
M.sideOptions = {}
function ScenEdit_SetSideOptions(t)
  local side = get(t, 'side')
  assert(M.sides[side], 'options on unknown side')
  M.sideOptions[side] = M.sideOptions[side] or {}
  for k, v in pairs(t) do M.sideOptions[side][lower(k)] = v end
  return {}
end
function ScenEdit_SetDoctrine(sel, d)
  local s = get(sel, 'side')
  assert(M.sides[s], 'doctrine on unknown side')
  M.doctrine[s] = M.doctrine[s] or {}
  for k, v in pairs(d) do
    assert(({ [0] = 1, [1] = 1, [2] = 1 })[v], 'bad WCS value for ' .. k)
    M.doctrine[s][k] = v
  end
  return M.doctrine[s]
end
function ScenEdit_SetEMCON() return true end

function ScenEdit_AddReferencePoint(t)
  local s = get(t, 'side')
  assert(M.sides[s], 'RP on unknown side')
  assert(get(t, 'name') and get(t, 'latitude') and get(t, 'longitude'), 'RP needs name and position')
  M.rps[s .. '|' .. get(t, 'name')] = true
  return { name = get(t, 'name') }
end

function ScenEdit_AddUnit(t)
  local typ, side, name, dbid = get(t, 'type'), get(t, 'side'), get(t, 'unitname'), get(t, 'dbid')
  assert(TYPECODE[typ], 'bad unit type ' .. tostring(typ))
  assert(M.sides[side], 'unit on unknown side ' .. tostring(side))
  assert(type(name) == 'string' and name ~= '', 'unit needs a name')
  assert(type(dbid) == 'number' and dbid > 0, 'unit needs a numeric dbid: ' .. name)
  local u = { name = name, type = typ, side = side, dbid = dbid, guid = newguid(),
              prof = get(t, 'proficiency') }
  local base = get(t, 'base')
  if base then
    local b = findUnit({ unitname = base })
    if not b then error('base not found: ' .. base) end
    u.lat, u.lon, u.base = b.lat, b.lon, b.name
  else
    u.lat, u.lon = get(t, 'latitude'), get(t, 'longitude')
    assert(type(u.lat) == 'number' and type(u.lon) == 'number', 'unit needs a position: ' .. name)
    assert(u.lat > -90 and u.lat < 90 and u.lon > -180 and u.lon < 180, 'position out of range: ' .. name)
  end
  if typ == 'Aircraft' then
    assert(base, 'test builders always base aircraft: ' .. name)
    u.loadoutid = get(t, 'loadoutid')
    if M.rejectLoadouts and u.loadoutid and M.rejectLoadouts[u.loadoutid] then error('invalid loadout') end
  end
  M.units[u.guid] = u
  M.order[#M.order + 1] = u.guid
  return wrap(u)
end

function ScenEdit_GetUnit(t)
  local u = findUnit(t)
  if not u then error('unit not found') end  -- console behaviour; scripts wrap this in pcall
  return wrap(u)
end
function ScenEdit_SetUnit(t)
  local u = findUnit(t)
  assert(u, 'SetUnit on unknown unit')
  local course = get(t, 'course')
  if course then
    assert(type(course[1]) == 'table' and course[1].latitude and course[1].longitude, 'bad course')
    u.course = course
  end
  if get(t, 'holdfire') ~= nil then u.holdfire = get(t, 'holdfire') end
  return wrap(u)
end
function ScenEdit_DeleteUnit(t)
  local u = findUnit(t)
  assert(u, 'DeleteUnit on unknown unit')
  M.units[u.guid] = nil
  return true
end

function VP_GetSide(t)
  local s = M.sides[get(t, 'side')]
  if not s then return nil end
  local list = {}
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.side == s.name then list[#list + 1] = { name = u.name, guid = u.guid, type = u.type } end
  end
  return { name = s.name, units = list,
           unitsBy = function(self, typ)
             local r = {}
             for _, e in ipairs(list) do if e.type == typ then r[#r + 1] = e end end
             return r
           end }
end

function ScenEdit_AddMission(side, name, mtype, opts)
  assert(M.sides[side], 'mission on unknown side')
  assert(not M.missions[name], 'duplicate mission ' .. name)
  for _, z in ipairs(get(opts, 'zone') or {}) do
    assert(M.rps[side .. '|' .. z], 'mission zone RP missing on side ' .. side .. ': ' .. z)
  end
  M.missions[name] = { side = side, type = mtype, active = true, units = {} }
  return { name = name }
end
function ScenEdit_SetMission(side, name, opts)
  local m = M.missions[name]
  assert(m and m.side == side, 'SetMission on unknown mission ' .. tostring(name))
  local a = get(opts, 'isactive')
  if a ~= nil then m.active = a end
  return { name = name }
end
function ScenEdit_AssignUnitToMission(unit, name)
  local m, u = M.missions[name], findUnit({ unitname = unit })
  assert(m and u and u.side == m.side, 'bad assignment ' .. tostring(unit) .. ' -> ' .. tostring(name))
  m.units[#m.units + 1] = unit
  return true
end

function ScenEdit_SetTrigger(t)
  local name, typ = get(t, 'name'), get(t, 'type')
  assert(get(t, 'mode') == 'add' and name and typ, 'bad trigger')
  local tf = get(t, 'targetfilter')
  if tf then assert(M.sides[get(tf, 'targetside')], 'trigger filter on unknown side') end
  M.triggers[name] = t
  return t
end
function ScenEdit_SetAction(t)
  local name, script = get(t, 'name'), get(t, 'scripttext')
  assert(get(t, 'type') == 'LuaScript' and name and script, 'bad action')
  local f, err = load(script, name, 't')
  assert(f, 'action does not compile: ' .. tostring(err))
  M.actions[name] = script
  return t
end
function ScenEdit_SetEvent(name, o)
  assert(get(o, 'mode') == 'add' and not M.events[name], 'bad event ' .. name)
  M.events[name] = { repeatable = get(o, 'isrepeatable'), triggers = {}, actions = {}, fired = 0 }
  return M.events[name]
end
function ScenEdit_SetEventTrigger(ev, o)
  local d = get(o, 'description')
  assert(M.events[ev] and M.triggers[d], 'event trigger link failed: ' .. ev)
  table.insert(M.events[ev].triggers, d)
  return {}
end
function ScenEdit_SetEventAction(ev, o)
  local d = get(o, 'description')
  assert(M.events[ev] and M.actions[d], 'event action link failed: ' .. ev)
  table.insert(M.events[ev].actions, d)
  return {}
end

function ScenEdit_SpecialMessage(side, html) M.messages[#M.messages + 1] = '[' .. side .. '] ' .. html return 1 end
function ScenEdit_GetScore(side) return M.score[side] end
function ScenEdit_SetScore(side, s, why)
  M.scorelog[#M.scorelog + 1] = string.format('%-15s %+5d  %s', side, s - M.score[side], why)
  M.score[side] = s
  return s
end
function ScenEdit_CurrentTime() return M.now end
-- v1.10 real-time multiplayer probes; a test sets M.rtmp and M.humans.
M.rtmp, M.humans, M.barks = false, {}, {}
function ScenEdit_GetGameIsRTMP() return M.rtmp end
function ScenEdit_GetSideIsPlayer(side) assert(M.sides[side], 'unknown side') return M.humans[side] == true end
function ScenEdit_GetSideIsHuman(side) assert(M.sides[side], 'unknown side') return M.humans[side] == true end
function ScenEdit_CreateBarkNotification_Geo(lon, lat, text, r, g, b)
  assert(type(lon) == 'number' and type(lat) == 'number' and type(text) == 'string', 'bad bark')
  assert(not text:match('<'), 'bark text must be plain')
  M.barks[#M.barks + 1] = text
  return true
end
function ScenEdit_EndScenario() M.ended = true end
function ScenEdit_UnitX() return wrap(M.unitx) end

-- ---------------------------------------------------------------- test API
local function runActions(ev, unit)
  M.unitx = unit
  for _, a in ipairs(ev.actions) do
    local f = assert(load(M.actions[a], a, 't'))
    local ok, err = pcall(f)
    if not ok then error('runtime error in ' .. a .. ': ' .. tostring(err)) end
  end
  M.unitx = nil
  ev.fired = ev.fired + 1
end

function M.fire(kind, unit)
  for _, ev in pairs(M.events) do
    for _, tn in ipairs(ev.triggers) do
      local t = M.triggers[tn]
      local tf = get(t, 'targetfilter')
      local match = (get(t, 'type') == kind)
      if match and tf and unit then
        match = get(tf, 'targetside') == unit.side and get(tf, 'targettype') == TYPECODE[unit.type]
      end
      if match and (ev.repeatable or ev.fired == 0) then runActions(ev, unit) end
    end
  end
end

function M.tick(minutes)
  M.now = M.now + (minutes or 0) * 60
  M.fire('RegularTime', nil)
end

function M.unit(name)
  for _, g in ipairs(M.order) do
    local u = M.units[g]
    if u and u.name == name then return u end
  end
  return nil
end

function M.move(name, lat, lon, alt)
  local u = assert(M.unit(name), 'move: no unit ' .. name)
  u.lat, u.lon, u.alt = lat, lon, alt or u.alt
end

function M.kill(name)
  local u = assert(M.unit(name), 'kill: no unit ' .. name)
  M.units[u.guid] = nil
  M.fire('UnitDestroyed', u)
end

function M.damage(name)
  local u = assert(M.unit(name), 'damage: no unit ' .. name)
  M.fire('UnitDamaged', u)
end

return M
