--[[
===============================================================================
  OPERATION SHEEPSKIN GONE HOT  (Anguilla, 19 March 1969)
  Command: Modern Operations scenario builder
-------------------------------------------------------------------------------
  Database : COLD WAR database (CWDB). Do NOT run this in a DB3000 scenario;
             the DBIDs below belong to the Cold War database.
  Usage    : 1. File > New Scenario, choose the Cold War database.
             2. Editor > Lua Script Console, paste this whole file, Run.
             3. Read the console report (units that failed, aircraft that need
                a loadout chosen in the editor).
             4. Paste the briefing text from briefing_1969.md into
                Scenario > Description and Side > Briefing, set the scoring
                thresholds listed there, then File > Save As.
  Player   : United Kingdom.  AI: Anguilla (Anguillian Defence Force and
             Cuban volunteers).  Neutral: Anguillian Civilians.
  Multiplayer: built for CMO v1.10 real-time multiplayer.  Single player and
             co-op: United Kingdom vs the Anguillan AI.  Head-to-head: one
             player per side; the scripted AI timeline switches off for a
             human Anguilla.  See docs/rtmp-test-plan.md.

  Every DBID was taken from the Cold War database listing at cmano-db.com
  (db v.509).  Loadout IDs are not published there, so aircraft are added with
  the IDs in LOADOUTS when you fill them in, and otherwise with a safe
  fallback; the console lists every aircraft you should re-arm.
===============================================================================
]]

-- ---------------------------------------------------------------------------
-- 0. OPTIONAL LOADOUT IDS
--    Open the aircraft in the in-game Database Viewer, note the loadout ID you
--    want (the number shown beside each loadout) and enter it here before
--    running.  0 means "not set": the builder then falls back and reports.
-- ---------------------------------------------------------------------------
local LOADOUTS = {
  WASP       = 0,  -- Wasp HAS.1 (DBID 1637).  Suggested: AS.12 x2 (armed lift).
  SHACKLETON = 0,  -- Shackleton MR.3 (DBID 252).  Suggested: maritime patrol / ASuW.
  T28        = 0,  -- T-28A Trojan (DBID 2077).  Suggested: gun pods + rockets.
}

-- ---------------------------------------------------------------------------
-- 1. CONSTANTS
-- ---------------------------------------------------------------------------
local UK  = 'United Kingdom'
local AI  = 'Anguilla'
local CIV = 'Anguillian Civilians'

local DB = {
  -- United Kingdom (Cold War DB)
  LEANDER      = 148,   -- F 109 Leander [Type 12I Batch 1] 1967, Seacat; stands in for Minerva (F45)
  ROTHESAY     = 1238,  -- F 107 Rothesay [Type 12M] 1967, Seacat
  LSL          = 19,    -- L 3029 Sir Lancelot [Round Table] 1964
  LCVP         = 1570,  -- LCVP
  WASP         = 1637,  -- Wasp HAS.1 1963
  SHACKLETON   = 252,   -- Shackleton MR.3 1966
  AIRFIELD_LG  = 400,   -- Single-Unit Airfield (1x 2001-2600m) for Coolidge, Antigua
  PARA_PLT     = 320,   -- Inf Plt (British Paratroopers)
  GPMG_SEC     = 1912,  -- Inf 7.62mm MG Support Sec
  FAC_SEC      = 21,    -- Inf Sec (Forward Air Controller); used as the NGFO party
  POLICE       = 1727,  -- Armed Police Sec
  -- Anguilla / Cuban volunteers
  MILITIA_PLT  = 3158,  -- Inf Plt (Generic)
  CUBAN_PLT    = 341,   -- Inf Plt (Cuban Army)
  DSHK_NEST    = 224,   -- Pillbox (12.7mm)
  MORTAR_SEC   = 1680,  -- Inf 81mm Mortar Section (82mm in the narrative)
  TECHNICAL    = 1618,  -- Vehicle (Truck, Armed Technical [12.7mm] x 1)
  P6_MTB       = 1560,  -- 88 [Pr.183] (P-6 torpedo boat), Cuba
  T28          = 2077,  -- T-28A Trojan, Cuba
  AIRFIELD_SM  = 785,   -- Single-Unit Airfield (1x 901-1400m) for Wallblake
  -- Civilians
  CHURCH       = 3004,  -- Building (Place of Worship)
  SCHOOL       = 82,    -- Building (School)
  HOSPITAL     = 83,    -- Building (Hospital)
  SMALL_BOAT   = 579,   -- Civilian Small boat [7m]
  SAILBOAT     = 664,   -- Civilian Sailboat [23m]
}

-- ---------------------------------------------------------------------------
-- 2. BUILD HELPERS
-- ---------------------------------------------------------------------------
local REPORT, ARM = {}, {}
local function note(s) REPORT[#REPORT + 1] = s end

local function copy(t) local r = {} for k, v in pairs(t) do r[k] = v end return r end

local function addUnit(t)
  local ok, u = pcall(ScenEdit_AddUnit, t)
  if ok and u then return u end
  note('FAILED: ' .. tostring(t.unitname) .. ' (DBID ' .. tostring(t.dbid) .. ') ' .. tostring(u))
  return nil
end

-- Ships: optionally hosted (docked) in a parent ship, otherwise placed at sea.
local function placeShip(side, name, dbid, lat, lon, prof, heading, host)
  if host then
    local ok, u = pcall(ScenEdit_AddUnit, { type = 'Ship', side = side, unitname = name,
                                            dbid = dbid, base = host, proficiency = prof or 'Regular' })
    if ok and u then return u end
    note('Note: could not dock ' .. name .. ' in ' .. host .. '; placed alongside instead.')
  end
  return addUnit({ type = 'Ship', side = side, unitname = name, dbid = dbid,
                   latitude = lat, longitude = lon, proficiency = prof or 'Regular',
                   heading = heading or 90 })
end

local function placeFacility(side, name, dbid, lat, lon, prof)
  return addUnit({ type = 'Facility', side = side, unitname = name, dbid = dbid,
                   latitude = lat, longitude = lon, proficiency = prof or 'Regular' })
end

-- Aircraft: try each base in turn, and for each base the configured loadout,
-- then the generic fallbacks.  Anything not on its configured loadout is
-- reported so it can be re-armed in the editor.
local function placeAircraft(side, name, dbid, key, bases, prof)
  local configured = LOADOUTS[key] or 0
  local tries = {}
  if configured > 0 then tries[#tries + 1] = configured end
  tries[#tries + 1] = 4      -- generic Ferry loadout in current databases
  tries[#tries + 1] = 3      -- generic Reserve loadout
  tries[#tries + 1] = false  -- let the game pick
  for _, base in ipairs(bases) do
    for _, lid in ipairs(tries) do
      local t = { type = 'Aircraft', side = side, unitname = name, dbid = dbid,
                  base = base, proficiency = prof or 'Regular' }
      if lid then t.loadoutid = lid end
      local ok, u = pcall(ScenEdit_AddUnit, t)
      if ok and u then
        if lid ~= configured then
          local lname = '?'
          pcall(function() lname = (u.loadout and u.loadout.name) or tostring(u.loadoutdbid) end)
          ARM[#ARM + 1] = name .. ' at ' .. base .. ': placeholder loadout "' .. tostring(lname) ..
                          '"; choose a combat loadout (LOADOUTS.' .. key .. ')'
        end
        return u
      end
    end
  end
  note('FAILED: aircraft ' .. name .. ' (DBID ' .. dbid .. ') could not be based anywhere')
  return nil
end

local function rp(side, name, lat, lon, color)
  pcall(ScenEdit_AddReferencePoint, { side = side, name = name, latitude = lat, longitude = lon,
                                      highlighted = false, color = color })
  return name
end

-- Four reference points forming a box; returns their names for mission zones.
local function box(side, prefix, lat, lon, dlat, dlon)
  return {
    rp(side, prefix .. '-1', lat + dlat, lon - dlon),
    rp(side, prefix .. '-2', lat + dlat, lon + dlon),
    rp(side, prefix .. '-3', lat - dlat, lon + dlon),
    rp(side, prefix .. '-4', lat - dlat, lon - dlon),
  }
end

local function patrol(side, name, subtype, zone, units, active)
  local ok, m = pcall(ScenEdit_AddMission, side, name, 'Patrol', { type = subtype, zone = zone })
  if not (ok and m) then note('FAILED: mission ' .. name .. ' ' .. tostring(m)) return end
  pcall(ScenEdit_SetMission, side, name, { OneThirdRule = false, CheckOPA = true, CheckWWR = true })
  for _, u in ipairs(units) do pcall(ScenEdit_AssignUnitToMission, u, name) end
  if active == false then pcall(ScenEdit_SetMission, side, name, { isactive = false }) end
end

-- Serialise a plain Lua table so event scripts carry their own configuration.
local function serialize(v, indent)
  indent = indent or ''
  local t = type(v)
  if t == 'string' then return string.format('%q', v)
  elseif t == 'number' or t == 'boolean' then return tostring(v)
  elseif t ~= 'table' then return 'nil' end
  local parts, n = {}, #v
  for i = 1, n do parts[#parts + 1] = serialize(v[i], indent .. '  ') end
  local keys = {}
  for k in pairs(v) do
    if not (type(k) == 'number' and k >= 1 and k <= n and math.floor(k) == k) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local ks = (type(k) == 'string' and k:match('^[%a_][%w_]*$')) and k or ('[' .. serialize(k) .. ']')
    parts[#parts + 1] = ks .. '=' .. serialize(v[k], indent .. '  ')
  end
  return '{' .. table.concat(parts, ',') .. '}'
end

local function luaEvent(name, trigger, script, repeatable)
  trigger.mode = 'add'
  trigger.name = name .. ' [trigger]'
  local okT, eT = pcall(ScenEdit_SetTrigger, trigger)
  local okA, eA = pcall(ScenEdit_SetAction, { mode = 'add', type = 'LuaScript',
                                              name = name .. ' [action]', ScriptText = script })
  local okE, eE = pcall(ScenEdit_SetEvent, name, { mode = 'add', IsRepeatable = repeatable,
                                                   IsShown = false, IsActive = true })
  local ok1 = pcall(ScenEdit_SetEventTrigger, name, { mode = 'add', description = name .. ' [trigger]' })
  local ok2 = pcall(ScenEdit_SetEventAction, name, { mode = 'add', description = name .. ' [action]' })
  if not (okT and okA and okE and ok1 and ok2) then
    note('FAILED: event ' .. name .. ' ' .. tostring(eT) .. ' ' .. tostring(eA) .. ' ' .. tostring(eE))
  end
end

-- Refuse to build twice into the same scenario.
do
  local ok, s = pcall(VP_GetSide, { side = UK })
  if ok and s and s.name == UK then
    error('This scenario already has a "' .. UK .. '" side. Run the builder on a blank Cold War scenario.')
  end
end

-- ---------------------------------------------------------------------------
-- 3. SCENARIO FRAME: title, time, weather, sides
-- ---------------------------------------------------------------------------
pcall(ScenEdit_ClearKeyValue, '')
pcall(SetScenarioTitle, 'Operation Sheepskin Gone Hot (1969)')
-- 05:00 local (AST, UTC-4) on 19 March 1969; twelve hours of daylight to work with.
pcall(ScenEdit_SetStartTime, { Date = '19.03.1969', Time = '09.00.00', Duration = '0:12:0', dateformat = 'DDMMYYYY' })
pcall(ScenEdit_SetTime, { Date = '19.03.1969', Time = '09.00.00', dateformat = 'DDMMYYYY' })
pcall(ScenEdit_SetWeather, 26, 0, 0.3, 3)

ScenEdit_AddSide({ side = UK })
ScenEdit_AddSide({ side = AI })
ScenEdit_AddSide({ side = CIV })
ScenEdit_SetSidePosture(UK, AI, 'H')
ScenEdit_SetSidePosture(AI, UK, 'H')
for _, s in ipairs({ UK, AI }) do
  ScenEdit_SetSidePosture(s, CIV, 'N')
  ScenEdit_SetSidePosture(CIV, s, 'N')
end
-- Anguilla is playable so the scenario supports head-to-head real-time
-- multiplayer.  In single player, choose the United Kingdom.
pcall(ScenEdit_SetSideOptions, { side = AI,  awareness = 'Normal', proficiency = 'Regular', computerControlledOnly = false })
pcall(ScenEdit_SetSideOptions, { side = CIV, awareness = 'Normal', proficiency = 'Novice',  computerControlledOnly = true })
pcall(ScenEdit_SetSideOptions, { side = UK,  awareness = 'Normal', proficiency = 'Regular' })

-- Rules of engagement.  The UK opens the day expecting a walkover, so every
-- axis is on WEAPONS HOLD (self-defence only).  The events release the side
-- to WEAPONS TIGHT the moment the defenders fire (a hit or a detected launch),
-- or after 30 minutes if nobody has fired yet.
pcall(ScenEdit_SetDoctrine, { side = UK },  { weapon_control_status_air = 2, weapon_control_status_surface = 2,
                                              weapon_control_status_land = 2 })
pcall(ScenEdit_SetDoctrine, { side = AI },  { weapon_control_status_air = 0, weapon_control_status_surface = 0,
                                              weapon_control_status_land = 0 })
pcall(ScenEdit_SetDoctrine, { side = CIV }, { weapon_control_status_air = 2, weapon_control_status_surface = 2,
                                              weapon_control_status_land = 2 })

-- ---------------------------------------------------------------------------
-- 4. UNITED KINGDOM
-- ---------------------------------------------------------------------------
-- Task force at anchor in Road Bay, west of Sandy Ground.
placeShip(UK, 'HMS Minerva',      DB.LEANDER,  18.2085, -63.1100, 'Regular', 90)
placeShip(UK, 'HMS Rothesay',     DB.ROTHESAY, 18.1955, -63.1130, 'Regular', 90)
-- Balance/logistics addition: the LSL carries the landing craft and the
-- company's follow-on waves (the narrative's boats have to come from somewhere).
placeShip(UK, 'RFA Sir Lancelot', DB.LSL,      18.2040, -63.1200, 'Regular', 90)
placeShip(UK, 'LCVP 1', DB.LCVP, 18.2032, -63.1158, 'Veteran', 100)
placeShip(UK, 'LCVP 2', DB.LCVP, 18.2012, -63.1158, 'Veteran', 100)

placeAircraft(UK, 'Wasp 1', DB.WASP, 'WASP', { 'HMS Minerva' },  'Veteran')
placeAircraft(UK, 'Wasp 2', DB.WASP, 'WASP', { 'HMS Rothesay' }, 'Veteran')

-- Balance addition: RAF maritime patrol from Coolidge Field, Antigua.
placeFacility(UK, 'Coolidge Field (Antigua)', DB.AIRFIELD_LG, 17.1366, -61.7926, 'Regular')
placeAircraft(UK, 'Shackleton 1', DB.SHACKLETON, 'SHACKLETON', { 'Coolidge Field (Antigua)' }, 'Regular')

-- UK reference points (visible to the player).
rp(UK, 'BEACH Sandy Ground',  18.1996, -63.0905, 'Yellow')
rp(UK, 'LZ Wallblake',        18.2045, -63.0610, 'Yellow')
rp(UK, 'OBJ Wallblake',       18.2055, -63.0570, 'Red')
rp(UK, 'OBJ The Quarter',     18.2085, -63.0400, 'Red')
rp(UK, 'OBJ The Valley',      18.2146, -63.0518, 'Red')
rp(UK, 'GUNLINE North',       18.2150, -63.1050, 'Green')
rp(UK, 'GUNLINE South',       18.1950, -63.1080, 'Green')
local ukWatch = box(UK, 'Maritime Watch', 18.2200, -63.0600, 0.0900, 0.1200)
patrol(UK, 'Maritime Watch', 'naval', ukWatch, { 'Shackleton 1' }, true)

-- ---------------------------------------------------------------------------
-- 5. ANGUILLA: Anguillian Defence Force and Cuban volunteers
-- ---------------------------------------------------------------------------
-- Sandy Ground: the beach the planners chose.
placeFacility(AI, 'Sandy Ground DShK',      DB.DSHK_NEST,   18.1985, -63.0855, 'Veteran')
placeFacility(AI, 'Sandy Ground Militia',   DB.MILITIA_PLT, 18.2010, -63.0862, 'Novice')
placeFacility(AI, 'Reverse Slope Mortar',   DB.MORTAR_SEC,  18.2008, -63.0800, 'Veteran')
-- Wallblake airstrip.
placeFacility(AI, 'Wallblake Airstrip',     DB.AIRFIELD_SM, 18.2055, -63.0561, 'Regular')
placeFacility(AI, 'Wallblake DShK',         DB.DSHK_NEST,   18.2085, -63.0600, 'Veteran')
placeFacility(AI, 'Wallblake Road Technical', DB.TECHNICAL, 18.2030, -63.0640, 'Regular')
-- Balance addition: a second militia platoon dug in around the strip.
placeFacility(AI, 'Wallblake Militia',      DB.MILITIA_PLT, 18.2072, -63.0545, 'Novice')
-- The Quarter: the strongest position, held by the Cuban cadre.
placeFacility(AI, 'Valley Road Technical',  DB.TECHNICAL,   18.2110, -63.0450, 'Regular')
placeFacility(AI, 'Cuban Volunteer Platoon', DB.CUBAN_PLT,  18.2082, -63.0395, 'Veteran')
placeFacility(AI, 'Quarter Militia',        DB.MILITIA_PLT, 18.2095, -63.0415, 'Novice')

-- Balance additions at sea and in the air (kept to one of each).
placeShip(AI, 'Torpedo Boat Libertad', DB.P6_MTB, 18.2240, -63.0765, 'Regular', 270)
placeAircraft(AI, 'Volunteer T-28', DB.T28, 'T28', { 'Wallblake Airstrip' }, 'Regular')

local roadBay = box(AI, 'Road Bay', 18.2050, -63.1050, 0.0300, 0.0350)
patrol(AI, 'Torpedo Run',     'naval', roadBay, { 'Torpedo Boat Libertad' }, false)
patrol(AI, 'T-28 Harassment', 'naval', roadBay, { 'Volunteer T-28' }, false)

-- ---------------------------------------------------------------------------
-- 6. CIVILIANS (destroying any of these costs the UK points)
-- ---------------------------------------------------------------------------
placeFacility(CIV, "St Mary's Church, The Valley", DB.CHURCH,   18.2160, -63.0530, 'Novice')
placeFacility(CIV, 'Valley Secondary School',      DB.SCHOOL,   18.2135, -63.0560, 'Novice')
placeFacility(CIV, 'Cottage Hospital',             DB.HOSPITAL, 18.2125, -63.0505, 'Novice')
placeShip(CIV, 'Fishing Boat Mary Rose',  DB.SMALL_BOAT, 18.2010, -63.0960, 'Novice', 200)
placeShip(CIV, 'Fishing Boat Island Girl', DB.SMALL_BOAT, 18.1990, -63.0975, 'Novice', 20)
placeShip(CIV, 'Schooner Warspite',       DB.SAILBOAT,   18.2025, -63.0990, 'Novice', 300)

-- ---------------------------------------------------------------------------
-- 7. RUNTIME CONFIGURATION (copied into every event script)
-- ---------------------------------------------------------------------------
local RT = {
  prefix = 'SGH_',
  uk = UK, opfor = AI, civ = CIV,
  not_ground = { Ship = true, Aircraft = true, Submarine = true, Weapon = true, Satellite = true },
  roe_fallback_min = 30,
  roe_msg = '<b>ROE CHANGE.</b> The defenders have opened fire. All engagements are released to ' ..
            'WEAPONS TIGHT; naval gunfire support may now be called.',
  reload_r = 700,
  intro = '<b>OPERATION SHEEPSKIN, 0500 local, 19 March 1969.</b><br/>The task force rides at anchor in Road Bay. ' ..
          'LCVP 1 and LCVP 2 are loaded with 1 and 2 Platoons for Sandy Ground; Wasp 1 and Wasp 2 carry 3 Platoon ' ..
          'and its GPMG section to the LZ at Wallblake.<br/>Troops go ashore when a craft reaches the beach marker, ' ..
          'or when a Wasp reaches the LZ below 350 m. Empty craft that return alongside their parent ship embark ' ..
          'the next wave.<br/><i>Rules of engagement: do not fire first.</i>',
  intro_ai = '<b>ANGUILLA, 0500 local, 19 March 1969.</b><br/>British frigates are at anchor in Road Bay and ' ..
             'landing craft are forming up off Sandy Ground. You command the Anguillan Defence Force and the Cuban ' ..
             'volunteers.<br/>Pre-built missions you may activate: <b>T-28 Harassment</b> and <b>Torpedo Run</b>. ' ..
             'You score for every British loss, for each objective you still hold at every full hour, and if the ' ..
             'British fire first. You lose points for each objective lost and each unit lost; civilian losses ' ..
             'cost both sides.<br/><i>The British are on Weapons Hold until you open fire.</i>',
  dest = {
    ['Sandy Ground']  = { lat = 18.1996, lon = -63.0905, r = 600, land_lat = 18.2001, land_lon = -63.0893 },
    ['LZ Wallblake']  = { lat = 18.2045, lon = -63.0610, r = 800, land_lat = 18.2045, land_lon = -63.0612,
                          air = true, maxalt = 350 },
  },
  spawn = {
    ['1 Platoon']              = { dbid = DB.PARA_PLT, prof = 'Veteran' },
    ['2 Platoon']              = { dbid = DB.PARA_PLT, prof = 'Veteran' },
    ['3 Platoon']              = { dbid = DB.PARA_PLT, prof = 'Veteran' },
    ['3 Platoon GPMG Section'] = { dbid = DB.GPMG_SEC, prof = 'Veteran' },
    ['Company HQ (NGFO)']      = { dbid = DB.FAC_SEC,  prof = 'Veteran' },
    ['Company Reserve']        = { dbid = DB.PARA_PLT, prof = 'Veteran' },
    ['Met Police Detachment']  = { dbid = DB.POLICE,   prof = 'Regular', pts = 10 },
  },
  craft = {
    ['LCVP 1'] = { mother = 'RFA Sir Lancelot', dest = 'Sandy Ground',
                   loads = { { '1 Platoon' }, { 'Company HQ (NGFO)', 'Company Reserve' } } },
    ['LCVP 2'] = { mother = 'RFA Sir Lancelot', dest = 'Sandy Ground',
                   loads = { { '2 Platoon' },
                             { 'Met Police Detachment', requires = 'obj_beach',
                               wait_msg = 'The Metropolitan Police will not embark until the Sandy Ground beachhead is secure.',
                               msg = 'The Metropolitan Police detachment comes ashore at Sandy Ground, roughly where the ' ..
                                     'planners had imagined it arriving hours earlier.' } } },
    ['Wasp 1'] = { mother = 'HMS Minerva',  dest = 'LZ Wallblake', loads = { { '3 Platoon' } } },
    ['Wasp 2'] = { mother = 'HMS Rothesay', dest = 'LZ Wallblake', loads = { { '3 Platoon GPMG Section' } } },
  },
  defenders = { 'Sandy Ground DShK', 'Sandy Ground Militia', 'Reverse Slope Mortar', 'Wallblake DShK',
                'Wallblake Road Technical', 'Wallblake Militia', 'Valley Road Technical',
                'Cuban Volunteer Platoon', 'Quarter Militia' },
  objectives = {
    { key = 'obj_beach', name = 'Sandy Ground beachhead', lat = 18.2000, lon = -63.0880, r = 700, pts = 15,
      msg = 'Sandy Ground is clear. The Paras push off the sand toward the interior.' },
    { key = 'obj_wallblake', name = 'Wallblake airstrip', lat = 18.2055, lon = -63.0570, r = 900, pts = 20,
      msg = 'Wallblake has fallen after close assault. The British hold a secure landing ground.' },
    { key = 'obj_quarter', name = 'The Quarter', lat = 18.2085, lon = -63.0400, r = 700, pts = 15,
      msg = 'The crossroads at The Quarter is in British hands.' },
    { key = 'obj_valley', name = 'The Valley', lat = 18.2146, lon = -63.0518, r = 700, pts = 30,
      msg = '2 PARA is in The Valley, the island capital.' },
  },
  withdraw = {
    name = 'The Quarter', needs_dead = { 'Valley Road Technical' }, lat = 18.2085, lon = -63.0400, r = 1500,
    min_uk = 2, units = { 'Cuban Volunteer Platoon', 'Quarter Militia' },
    dest_lat = 18.2500, dest_lon = -63.0060, pts = 15,
    msg = 'With the Valley road technical burning and British troops on their flank, the Cubans and militia ' ..
          'abandon The Quarter and withdraw east toward Island Harbour rather than die in place.',
  },
  police = { 'Met Police Detachment' },
  valley = { lat = 18.2146, lon = -63.0518, r = 900 },
  end_pts = 10,
  end_msg = '<b>By mid-afternoon 2 PARA holds every objective.</b> The Metropolitan Police have reached The Valley. ' ..
            'Britain wins, as it was always going to win; the question is what it cost. The scenario ends in ten minutes.',
  stages = {
    { at = 25, mission = 'T-28 Harassment' },
    { at = 40, mission = 'Torpedo Run' },
  },
  kill = {
    ['Sandy Ground DShK'] = 10, ['Wallblake DShK'] = 10, ['Reverse Slope Mortar'] = 10,
    ['Wallblake Road Technical'] = 5, ['Valley Road Technical'] = 5, ['Cuban Volunteer Platoon'] = 5,
    ['Sandy Ground Militia'] = -5, ['Wallblake Militia'] = -5, ['Quarter Militia'] = -5,
    ['Torpedo Boat Libertad'] = 15, ['Volunteer T-28'] = 10, ['Wallblake Airstrip'] = -10,
  },
  kill_type = { Aircraft = 10, Ship = 10, Facility = 3 },
  kill_msg = {
    ['Sandy Ground DShK'] = 'The beach DShK falls silent under 4.5-inch fire.',
    ['Reverse Slope Mortar'] = 'The mortar on the reverse slope is destroyed; pressure on the beachhead lifts.',
    ['Wallblake DShK'] = 'The Wallblake DShK is taken. The last threat to the helicopters is gone.',
    ['Valley Road Technical'] = 'The technical on the Valley road is burning.',
  },
  loss = {
    ['HMS Minerva'] = 100, ['HMS Rothesay'] = 100, ['RFA Sir Lancelot'] = 100,
    ['LCVP 1'] = 10, ['LCVP 2'] = 10, ['Wasp 1'] = 15, ['Wasp 2'] = 15, ['Shackleton 1'] = 30,
    ['1 Platoon'] = 25, ['2 Platoon'] = 25, ['3 Platoon'] = 25, ['Company Reserve'] = 25,
    ['3 Platoon GPMG Section'] = 10, ['Company HQ (NGFO)'] = 20, ['Met Police Detachment'] = 30,
  },
  loss_type = { Aircraft = 15, Ship = 20, Facility = 10 },
  ship_hit = 15,
  roe_violation = 20,
  hold_pts = 5,                -- Anguilla scores this per objective still held, every full hour
  routine_as_barks = true,     -- multiplayer co-op: routine news as map barks instead of pop-ups
  civ_pts = 20,
}

-- ---------------------------------------------------------------------------
-- 8. EVENT SCRIPTS (shared library + per-event bodies)
-- ---------------------------------------------------------------------------
local LIB = [==[
local function kv(k) local v = ScenEdit_GetKeyValue(RT.prefix .. k) if v == nil or v == '' then return nil end return v end
local function setkv(k, v) ScenEdit_SetKeyValue(RT.prefix .. k, tostring(v)) end
local function num(x) return tonumber(x) or 0 end

-- Session detection (CMO v1.10+).  Older builds lack these calls, so every
-- probe is wrapped and falls back to single-player behaviour.
local function isRTMP()
  local ok, r = pcall(ScenEdit_GetGameIsRTMP)
  return ok and r == true
end
local function isHuman(side)
  local ok, r = pcall(ScenEdit_GetSideIsPlayer, side)
  if ok and r ~= nil then return r == true end
  ok, r = pcall(ScenEdit_GetSideIsHuman, side)
  return ok and r == true
end
local OPFOR_HUMAN = isHuman(RT.opfor)
local RTMP = isRTMP()

-- Messages.  Critical news is always a side-addressed special message.
-- Routine news in a multiplayer co-op session becomes a map "bark" at the
-- spot it concerns, so pop-ups do not interrupt the other player.  Barks are
-- not side-addressed, so in head-to-head play routine news stays a special
-- message to avoid showing British positions to the Anguillan player.
local function plain(html) return (html:gsub('<br/>', ' '):gsub('<[^>]+>', '')) end
local function msg(html) pcall(ScenEdit_SpecialMessage, RT.uk, html) end
local function msgAI(html) if OPFOR_HUMAN then pcall(ScenEdit_SpecialMessage, RT.opfor, html) end end
local function note(html, lat, lon)
  if RTMP and RT.routine_as_barks and not OPFOR_HUMAN and lat and lon then
    local ok = pcall(ScenEdit_CreateBarkNotification_Geo, lon, lat, plain(html), 255, 215, 0, true, true, 12, 16)
    if ok then return end
  end
  msg(html)
end

-- Scores.  The UK score is the player's; the Anguillan score mirrors it so
-- head-to-head games have a winner on both sides.
local function addTo(side, n, why)
  if not n or n == 0 then return end
  local s = ScenEdit_GetScore(side) or 0
  ScenEdit_SetScore(side, s + n, why)
end
local function score(n, why) addTo(RT.uk, n, why) end
local function scoreAI(n, why) addTo(RT.opfor, n, why) end

local function getu(side, name)
  local ok, u = pcall(ScenEdit_GetUnit, { side = side, unitname = name })
  if ok and u then return u end
  return nil
end
local function getg(guid)
  local ok, u = pcall(ScenEdit_GetUnit, { guid = guid })
  if ok and u then return u end
  return nil
end
local function dist(a1, o1, a2, o2)
  local r = math.pi / 180
  local da, dl = (a2 - a1) * r, (o2 - o1) * r
  local h = math.sin(da / 2) ^ 2 + math.cos(a1 * r) * math.cos(a2 * r) * math.sin(dl / 2) ^ 2
  return 2 * 6371000 * math.asin(math.min(1, math.sqrt(h)))
end
local function near(u, lat, lon, r) return u and dist(num(u.latitude), num(u.longitude), lat, lon) <= r end

-- British ground positions are read once per script run and reused by every
-- objective check, which keeps the heartbeat light.
local UKG = nil
local function ukGround()
  if UKG then return UKG end
  UKG = {}
  local ok, s = pcall(VP_GetSide, { side = RT.uk })
  if not (ok and s) then return UKG end
  local list = nil
  pcall(function() list = s:unitsBy('Facility') end)
  if not list or next(list) == nil then list = s.units end
  for _, e in pairs(list or {}) do
    local u = getg(e.guid)
    if u and not RT.not_ground[u.type] then UKG[#UKG + 1] = { num(u.latitude), num(u.longitude) } end
  end
  return UKG
end
local function ukGroundNear(lat, lon, r)
  local n = 0
  for _, p in ipairs(ukGround()) do if dist(p[1], p[2], lat, lon) <= r then n = n + 1 end end
  return n
end
local function defenderNear(lat, lon, r)
  for _, name in ipairs(RT.defenders) do
    if near(getu(RT.opfor, name), lat, lon, r) then return true end
  end
  return false
end
local function releaseROE(reason)
  if kv('roe') then return end
  setkv('roe', 1)
  pcall(ScenEdit_SetDoctrine, { side = RT.uk }, { weapon_control_status_air = 1, weapon_control_status_surface = 1,
                                                 weapon_control_status_land = 1 })
  msg(RT.roe_msg .. '<br/><i>' .. reason .. '</i>')
  msgAI('<b>The British are now free to return fire.</b>')
end
]==]

local HEARTBEAT = [==[
local now = ScenEdit_CurrentTime()
local t0 = tonumber(kv('t0') or '')
if not t0 then
  t0 = now
  setkv('t0', now)
  setkv('session', (RTMP and 'RTMP' or 'single') .. (OPFOR_HUMAN and '/pvp' or '/vs-ai'))
  msg(RT.intro .. '<br/><br/><small>Session: ' .. (RTMP and 'real-time multiplayer' or 'single player') ..
      '; Anguilla is ' .. (OPFOR_HUMAN and 'human-controlled' or 'AI-controlled') .. '.</small>')
  msgAI(RT.intro_ai)
end
local T = (now - t0) / 60

-- 1. Timed AI activations.  A human Anguillan commander runs their own
--    missions instead; the pre-built ones are left for them to activate.
if not OPFOR_HUMAN then
  for i, st in ipairs(RT.stages) do
    if T >= st.at and not kv('stage' .. i) then
      setkv('stage' .. i, 1)
      if st.mission then pcall(ScenEdit_SetMission, RT.opfor, st.mission, { isactive = true }) end
      if st.msg then msg(st.msg) end
    end
  end
end

-- 2. ROE fallback: intelligence confirms hostile intent.
if T >= RT.roe_fallback_min then releaseROE('Hostile intent confirmed by observation; no further warning will be given.') end

-- 3. Landing craft and helicopter lifts.
for cname, c in pairs(RT.craft) do
  local st = kv('cs_' .. cname) or 'loaded'
  local w = tonumber(kv('cw_' .. cname) or '1')
  local u = (st ~= 'lost') and getu(RT.uk, cname) or nil
  if u then
    local d = RT.dest[c.dest]
    if st == 'loaded' then
      local low = (not d.air) or num(u.altitude) <= (d.maxalt or 350)
      if low and near(u, d.lat, d.lon, d.r) then
        local load = c.loads[w]
        for i, uname in ipairs(load) do
          local sp = RT.spawn[uname]
          pcall(ScenEdit_AddUnit, { type = 'Facility', side = RT.uk, unitname = uname, dbid = sp.dbid,
                                    latitude = d.land_lat + (i - 1) * 0.0008, longitude = d.land_lon + (i - 1) * 0.0006,
                                    proficiency = sp.prof or 'Regular' })
          if sp.pts then score(sp.pts, uname .. ' ashore') end
        end
        setkv('cs_' .. cname, 'empty')
        if load.msg then msg(load.msg) end
        note('<b>' .. cname .. '</b>: ' .. table.concat(load, ', ') .. ' ashore at ' .. c.dest .. '.', d.lat, d.lon)
      end
    elseif st == 'empty' and w < #c.loads then
      local m = getu(RT.uk, c.mother)
      if m and near(u, num(m.latitude), num(m.longitude), RT.reload_r) then
        local nxt = c.loads[w + 1]
        if nxt.requires and not kv(nxt.requires) then
          if not kv('wait_' .. cname) then
            setkv('wait_' .. cname, 1)
            note(nxt.wait_msg or 'Next wave is not ready.', num(m.latitude), num(m.longitude))
          end
        else
          setkv('cw_' .. cname, w + 1)
          setkv('cs_' .. cname, 'loaded')
          note('<b>' .. cname .. '</b> has embarked ' .. table.concat(nxt, ', ') .. ' from ' .. c.mother .. '.',
               num(m.latitude), num(m.longitude))
        end
      end
    end
  end
end

-- 4. Objectives: a UK ground unit inside and no listed defender left inside.
--    Every full hour, each objective still in Anguillan hands scores for Anguilla.
for _, o in ipairs(RT.objectives) do
  if not kv(o.key) and ukGroundNear(o.lat, o.lon, o.r) >= 1 and not defenderNear(o.lat, o.lon, o.r) then
    setkv(o.key, 1)
    score(o.pts, o.name .. ' secured')
    scoreAI(-o.pts, o.name .. ' lost')
    msg('<b>' .. o.name .. ' secured.</b> ' .. o.msg)
    msgAI('<b>' .. o.name .. ' has fallen to the British.</b>')
  end
end
local hour = math.floor(T / 60)
if hour > num(kv('hour')) then
  setkv('hour', hour)
  for _, o in ipairs(RT.objectives) do
    if not kv(o.key) then scoreAI(RT.hold_pts, o.name .. ' still held at H+' .. hour) end
  end
end

-- 5. Scripted withdrawal from the strongest position (AI defenders only).
local W = RT.withdraw
if W and not OPFOR_HUMAN and not kv('wd') then
  local go = true
  for _, n in ipairs(W.needs_dead) do if getu(RT.opfor, n) then go = false end end
  if go and ukGroundNear(W.lat, W.lon, W.r) >= W.min_uk then
    setkv('wd', 1); setkv('wd_t', now)
    for _, n in ipairs(W.units) do
      local u = getu(RT.opfor, n)
      if u then pcall(ScenEdit_SetUnit, { side = RT.opfor, guid = u.guid, holdFire = true,
                                          course = { { latitude = W.dest_lat, longitude = W.dest_lon } } }) end
    end
    score(W.pts, 'Defenders withdrew from ' .. W.name)
    msg(W.msg)
  end
elseif W and kv('wd') == '1' then
  local left = false
  for _, n in ipairs(W.units) do
    local u = getu(RT.opfor, n)
    if u then
      if near(u, W.dest_lat, W.dest_lon, 400) or (now - num(kv('wd_t'))) > 2700 then
        pcall(ScenEdit_DeleteUnit, { side = RT.opfor, guid = u.guid })
      else
        left = true
      end
    end
  end
  if not left then setkv('wd', 2) end
end

-- 6. End state: The Valley held and the police inside it.
if kv('obj_valley') and not kv('end_t') then
  for _, n in ipairs(RT.police) do
    if not kv('end_t') and near(getu(RT.uk, n), RT.valley.lat, RT.valley.lon, RT.valley.r) then
      setkv('end_t', now)
      score(RT.end_pts, 'Civil authority restored in The Valley')
      scoreAI(-RT.end_pts, 'British police in The Valley')
      msg(RT.end_msg)
      msgAI('<b>The Metropolitan Police are in The Valley.</b> The scenario ends in ten minutes.')
    end
  end
elseif kv('end_t') and now - num(kv('end_t')) >= 600 then
  pcall(ScenEdit_EndScenario)
end
]==]

local OPFOR_LOST = [==[
local u = ScenEdit_UnitX()
if u then
  if not kv('roe') then
    score(-RT.roe_violation, 'ROE violation: ' .. u.name .. ' destroyed before the defenders opened fire')
    scoreAI(RT.roe_violation, 'British fired first: ' .. u.name)
  end
  local v = RT.kill[u.name]
  if v == nil then v = RT.kill_type[u.type] or 0 end
  if v > 0 then score(v, 'Destroyed ' .. u.name)
  elseif v < 0 then score(v, 'Political cost: ' .. u.name .. ' killed') end
  scoreAI(-math.abs(v), 'Lost ' .. u.name)
  if RT.kill_msg[u.name] then note(RT.kill_msg[u.name], num(u.latitude), num(u.longitude)) end
end
]==]

local UK_LOST = [==[
local u = ScenEdit_UnitX()
if u then
  local v = RT.loss[u.name] or RT.loss_type[u.type] or 0
  score(-v, 'Lost ' .. u.name)
  scoreAI(v, 'British lost ' .. u.name)
  local c = RT.craft[u.name]
  if c then
    if (kv('cs_' .. u.name) or 'loaded') == 'loaded' then
      local load = c.loads[tonumber(kv('cw_' .. u.name) or '1')]
      for _, n in ipairs(load) do
        local lv = RT.loss[n] or 25
        score(-lv, n .. ' lost aboard ' .. u.name)
        scoreAI(lv, 'British lost ' .. n .. ' aboard ' .. u.name)
      end
      msg('<b>' .. u.name .. '</b> has been lost with ' .. table.concat(load, ', ') .. ' embarked.')
    end
    setkv('cs_' .. u.name, 'lost')
  end
end
]==]

local UK_HIT = [==[
local u = ScenEdit_UnitX()
releaseROE('British units are under fire' .. (u and (': ' .. u.name) or '') .. '.')
if u and u.type == 'Ship' and not kv('hit_' .. u.name) then
  setkv('hit_' .. u.name, 1)
  score(-RT.ship_hit, u.name .. ' hit')
  scoreAI(RT.ship_hit, 'Hit ' .. u.name)
end
]==]

local HOSTILE_FIRE = [==[
releaseROE('Hostile weapon launch detected.')
]==]

local CIV_LOST = [==[
local u = ScenEdit_UnitX()
if u then
  -- Either side can cause it, so both pay; nobody gains from shelling a church.
  score(-RT.civ_pts, 'Collateral damage: ' .. u.name)
  scoreAI(-RT.civ_pts, 'Civilian loss: ' .. u.name)
  msg('<b>Collateral damage.</b> ' .. u.name .. ' has been destroyed. Expect questions in the House.')
  msgAI('<b>Civilian loss.</b> ' .. u.name .. ' has been destroyed.')
end
]==]

local HEAD = 'local RT = ' .. serialize(RT) .. '\n' .. LIB .. '\n'

-- Heartbeat.  Interval index 3 is a short repeating interval (15 to 30
-- seconds depending on build); the logic uses elapsed game time, so the
-- exact period does not matter.
luaEvent('SGH Heartbeat', { type = 'RegularTime', Interval = 3 }, HEAD .. HEARTBEAT, true)

for code, kind in pairs({ [1] = 'Aircraft', [2] = 'Ship', [4] = 'Facility' }) do
  luaEvent('SGH Anguilla loses ' .. kind,
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = AI, TargetType = code } },
           HEAD .. OPFOR_LOST, true)
  luaEvent('SGH UK loses ' .. kind,
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = UK, TargetType = code } },
           HEAD .. UK_LOST, true)
end
-- Damage events.  Only ship hits score, so only the ship event repeats; the
-- aircraft and ground events exist to release the ROE and fire once.  Under
-- sustained fire this keeps the event engine from re-running scripts on every
-- hit, which matters in multiplayer.
luaEvent('SGH UK ship hit',
         { type = 'UnitDamaged', DamagePercent = 1, TargetFilter = { TargetSide = UK, TargetType = 2 } },
         HEAD .. UK_HIT, true)
for code, kind in pairs({ [1] = 'Aircraft', [4] = 'Facility' }) do
  luaEvent('SGH UK hit ' .. kind,
           { type = 'UnitDamaged', DamagePercent = 1, TargetFilter = { TargetSide = UK, TargetType = code } },
           HEAD .. UK_HIT, false)
end
-- One launch is enough to release the ROE, so this fires once; a repeating
-- version would run on every missile, shell and drone detection.
luaEvent('SGH Hostile weapon detected',
         { type = 'UnitDetected', DetectorSideID = UK, MCL = 0, TargetFilter = { TargetSide = AI, TargetType = 6 } },
         HEAD .. HOSTILE_FIRE, false)
for code, kind in pairs({ [2] = 'Ship', [4] = 'Facility' }) do
  luaEvent('SGH Civilian ' .. kind .. ' lost',
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = CIV, TargetType = code } },
           HEAD .. CIV_LOST, true)
end

-- ---------------------------------------------------------------------------
-- 9. REPORT
-- ---------------------------------------------------------------------------
print('=== Operation Sheepskin Gone Hot (1969): build complete ===')
if #REPORT == 0 then print('All units, missions and events created.') end
for _, s in ipairs(REPORT) do print(s) end
if #ARM > 0 then
  print('--- Aircraft to re-arm in the editor (Ready/Arm Aircraft) ---')
  for _, s in ipairs(ARM) do print(s) end
end
print('Next: paste the briefing from briefing_1969.md, set the scoring thresholds, and save.')
