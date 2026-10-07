--[[
===============================================================================
  OPERATION SHEARLING  (Anguilla, 19 March 2026)
  "Operation Sheepskin Gone Hot" re-fought in a modern context
  Command: Modern Operations scenario builder
-------------------------------------------------------------------------------
  Database : DB3000.  Do NOT run this in a Cold War scenario; the DBIDs below
             belong to DB3000.
  Usage    : 1. File > New Scenario, choose DB3000.
             2. Editor > Lua Script Console, paste this whole file, Run.
             3. Read the console report (units that failed, aircraft that need
                a loadout chosen in the editor).
             4. Paste the briefing text from briefing_2026.md into
                Scenario > Description and Side > Briefing, set the scoring
                thresholds listed there, then File > Save As.
  Player   : United Kingdom.  AI: Anguilla (Anguillian Defence Force, its
             second-hand air arm and navy, and a foreign volunteer cadre).
             Neutral: Anguillian Civilians.
  Multiplayer: built for CMO v1.10 real-time multiplayer.  Single player and
             co-op: United Kingdom vs the Anguillan AI.  Head-to-head: one
             player per side; the scripted AI timeline switches off for a
             human Anguilla.  See docs/rtmp-test-plan.md.

  Every DBID was taken from the DB3000 listing at cmano-db.com (db v.511).
  Loadout IDs are not published there, so aircraft are added with the IDs in
  LOADOUTS when you fill them in, and otherwise with a safe fallback; the
  console lists every aircraft you should re-arm.
===============================================================================
]]

-- ---------------------------------------------------------------------------
-- 0. OPTIONAL LOADOUT IDS
--    Open the aircraft in the in-game Database Viewer, note the loadout ID you
--    want (the number shown beside each loadout) and enter it here before
--    running.  0 means "not set": the builder then falls back and reports.
-- ---------------------------------------------------------------------------
local LOADOUTS = {
  TYPHOON   = 0,  -- Typhoon FGR.4 2024 P3Ec (DBID 7090).  Suggested: Meteor/ASRAAM + Paveway IV.
  WILDCAT   = 0,  -- Wildcat HMA.2 2026 (DBID 6786).  Suggested: Sea Venom (anti-FAC).
  MERLIN    = 0,  -- Merlin HC.4 (DBID 4273).  Suggested: troop transport / GPMG.
  KFIR      = 0,  -- Kfir C.12 (DBID 5309).  Suggested: Python 5 + Derby (air to air).
  PAMPA     = 0,  -- IA-63 Pampa (DBID 143).  Suggested: rockets / bombs (anti-ship harassment).
  WINGLOONG = 0,  -- GJ-2 Wing Loong II (DBID 4725).  Suggested: anti-armour / AKD-10 missiles.
  HERMES    = 0,  -- Hermes 450 (DBID 2578).  Suggested: ISR (EO/IR).
}

-- ---------------------------------------------------------------------------
-- 1. CONSTANTS
-- ---------------------------------------------------------------------------
local UK  = 'United Kingdom'
local AI  = 'Anguilla'
local CIV = 'Anguillian Civilians'

local DB = {
  -- United Kingdom (DB3000)
  TYPE23       = 4131,  -- F 230 Norfolk [Type 23 Duke] 2023, NSM; stands in for HMS Iron Duke
  TYPE45       = 3437,  -- D 32 Daring [Type 45 Batch 1] 2023, CAMM; stands in for HMS Dauntless
  BAY          = 1451,  -- L 3006 Largs Bay [Bay Class]; stands in for RFA Mounts Bay
  RIVER2       = 2805,  -- P 222 Forth [River Class Batch 2]; stands in for HMS Medway
  LCU          = 2077,  -- LCU Mk.10
  LCVP         = 3701,  -- LCVP Mk.V
  TYPHOON      = 7090,  -- Typhoon FGR.4 2024, P3Ec
  WILDCAT      = 6786,  -- Wildcat HMA.2 [AW.159] 2026, Sea Venom
  MERLIN       = 4273,  -- Merlin HC.4 (Commando transport)
  AIRFIELD_LG  = 1877,  -- Single-Unit Airfield (1x 2600-3200m) for V.C. Bird, Antigua
  PARA_PLT     = 209,   -- Inf Plt (British Paratroopers)
  JTAC_SEC     = 2051,  -- Inf Sec (Forward Air Controller [Laser Designator])
  MORTAR_PLT   = 3422,  -- Mortar Plt (81mm Mortar)
  HMG_PLT      = 3678,  -- Inf Plt (12.7mm MG)
  POLICE       = 2272,  -- Inf Plt (Generic), stands in for the Met Police TSG
  -- Anguilla: purchased hardware and the volunteer cadre
  KFIR         = 5309,  -- Kfir C.12 2014 (ex-Colombian, Israeli-upgraded)
  PAMPA        = 143,   -- IA-63 Pampa (ex-Argentine)
  WINGLOONG    = 4725,  -- GJ-2 Wing Loong II UCAV (Chinese export)
  HERMES       = 2578,  -- Hermes 450 UAV (Israeli)
  FAC_148      = 3958,  -- P 73 Pezopoulos [Type 148, La Combattante IIa] 2001 (ex-Hellenic Navy)
  DABUR        = 743,   -- P 61 Baradero [Dabur Class] (ex-Argentine, Israeli-built)
  EXOCET_BTY   = 365,   -- SSM Bty (MM.40 Exocet) 1994, 2x launchers (ex-Hellenic Army)
  SEARCH_RADAR = 939,   -- Radar (Generic Surface Search Radar)
  MISTRAL      = 3520,  -- SAM Plt (Mistral III MANPADS x 3) (French)
  FN6          = 2351,  -- SAM Sec (CH-SA-10 [FN-6] MANPADS) (Chinese)
  ZU23_TECH    = 2738,  -- Vehicle (Truck, Armed Technical [ZU-23-2] x 1)
  KPV_TECH     = 3955,  -- Vehicle (Truck, Armed Technical [14.5mm] x 1)
  DSHK_TECH    = 1981,  -- Vehicle (Truck, Armed Technical [12.7mm] x 1)
  MILITIA_PLT  = 2272,  -- Inf Plt (Generic)
  CADRE_PLT    = 736,   -- Inf Plt (Cuban Army), the volunteer cadre
  AIRFIELD_MD  = 1593,  -- Single-Unit Airfield (1x 1401-2000m) for Clayton J. Lloyd (Wallblake)
  -- Civilians
  CHURCH       = 2290,  -- Building (Place of Worship)
  SCHOOL       = 319,   -- Building (School)
  HOSPITAL     = 318,   -- Building (Hospital)
  YACHT        = 1475,  -- Civilian Motor Yacht [38m]
  SMALL_BOAT   = 1789,  -- Civilian Small Boat [7m]
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
    error('This scenario already has a "' .. UK .. '" side. Run the builder on a blank DB3000 scenario.')
  end
end

-- ---------------------------------------------------------------------------
-- 3. SCENARIO FRAME: title, time, weather, sides
-- ---------------------------------------------------------------------------
pcall(ScenEdit_ClearKeyValue, '')
pcall(SetScenarioTitle, 'Operation Shearling (2026)')
-- 05:00 local (AST, UTC-4) on 19 March 2026, the 57th anniversary of Sheepskin.
pcall(ScenEdit_SetStartTime, { Date = '19.03.2026', Time = '09.00.00', Duration = '0:12:0', dateformat = 'DDMMYYYY' })
pcall(ScenEdit_SetTime, { Date = '19.03.2026', Time = '09.00.00', dateformat = 'DDMMYYYY' })
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

-- Rules of engagement.  Every axis starts on WEAPONS HOLD (self-defence
-- only), so the ships do not shoot the Kfir CAP down on their own initiative.
-- The events release the side to WEAPONS TIGHT the moment the defenders fire
-- (a hit or a detected launch), or after 30 minutes if nobody has fired yet.
pcall(ScenEdit_SetDoctrine, { side = UK },  { weapon_control_status_air = 2, weapon_control_status_surface = 2,
                                              weapon_control_status_land = 2 })
pcall(ScenEdit_SetDoctrine, { side = AI },  { weapon_control_status_air = 0, weapon_control_status_surface = 0,
                                              weapon_control_status_land = 0 })
pcall(ScenEdit_SetDoctrine, { side = CIV }, { weapon_control_status_air = 2, weapon_control_status_surface = 2,
                                              weapon_control_status_land = 2 })

-- ---------------------------------------------------------------------------
-- 4. UNITED KINGDOM: amphibious task group and RAF detachment
-- ---------------------------------------------------------------------------
-- Gunfire ship (the modern Minerva) and air-defence picket (the modern Rothesay).
placeShip(UK, 'HMS Iron Duke',  DB.TYPE23, 18.2090, -63.1100, 'Veteran', 90)
placeShip(UK, 'HMS Dauntless',  DB.TYPE45, 18.2350, -63.1500, 'Veteran', 45)
-- The ship actually on Caribbean station, and the patrol vessel that lives there.
placeShip(UK, 'RFA Mounts Bay', DB.BAY,    18.2040, -63.1250, 'Regular', 90)
placeShip(UK, 'HMS Medway',     DB.RIVER2, 18.1900, -63.1250, 'Regular', 60)
-- Landing craft start docked in the well; launch them from the Bay.
placeShip(UK, 'LCVP Alpha',  DB.LCVP, 18.2032, -63.1205, 'Veteran', 100, 'RFA Mounts Bay')
placeShip(UK, 'LCVP Bravo',  DB.LCVP, 18.2012, -63.1205, 'Veteran', 100, 'RFA Mounts Bay')
placeShip(UK, 'LCU Foxtrot', DB.LCU,  18.2050, -63.1215, 'Veteran', 100, 'RFA Mounts Bay')

placeAircraft(UK, 'Wildcat 1', DB.WILDCAT, 'WILDCAT', { 'HMS Iron Duke' }, 'Veteran')
placeAircraft(UK, 'Wildcat 2', DB.WILDCAT, 'WILDCAT', { 'HMS Dauntless', 'RFA Mounts Bay' }, 'Veteran')
placeAircraft(UK, 'Merlin 1',  DB.MERLIN,  'MERLIN',  { 'RFA Mounts Bay', 'HMS Dauntless' }, 'Veteran')
placeAircraft(UK, 'Merlin 2',  DB.MERLIN,  'MERLIN',  { 'RFA Mounts Bay', 'HMS Dauntless' }, 'Veteran')

-- RAF detachment flown into Antigua at the host nation's request.
placeFacility(UK, 'V.C. Bird Airport (Antigua)', DB.AIRFIELD_LG, 17.1366, -61.7926, 'Regular')
for i = 1, 4 do
  placeAircraft(UK, 'Typhoon ' .. i, DB.TYPHOON, 'TYPHOON', { 'V.C. Bird Airport (Antigua)' }, 'Veteran')
end

-- UK reference points (visible to the player).
rp(UK, 'BEACH Sandy Ground',  18.1996, -63.0905, 'Yellow')
rp(UK, 'LZ Wallblake',        18.2045, -63.0610, 'Yellow')
rp(UK, 'OBJ Wallblake',       18.2055, -63.0570, 'Red')
rp(UK, 'OBJ The Quarter',     18.2085, -63.0400, 'Red')
rp(UK, 'OBJ The Valley',      18.2146, -63.0518, 'Red')
rp(UK, 'GUNLINE North',       18.2150, -63.1050, 'Green')
rp(UK, 'GUNLINE South',       18.1950, -63.1080, 'Green')
local ukCap = box(UK, 'Anguilla CAP', 18.2300, -63.0500, 0.1000, 0.1300)
patrol(UK, 'Anguilla CAP', 'aaw', ukCap, { 'Typhoon 1', 'Typhoon 2' }, true)

-- ---------------------------------------------------------------------------
-- 5. ANGUILLA: Defence Force, volunteer cadre, air arm and navy
-- ---------------------------------------------------------------------------
-- Sandy Ground.
placeFacility(AI, 'Sandy Ground HMG Nest',       DB.HMG_PLT,     18.1985, -63.0855, 'Regular')
placeFacility(AI, 'Sandy Ground Militia',        DB.MILITIA_PLT, 18.2010, -63.0862, 'Novice')
placeFacility(AI, 'Sandy Ground Technical',      DB.DSHK_TECH,   18.2016, -63.0874, 'Novice')
placeFacility(AI, 'FN-6 Team (South Hill)',      DB.FN6,         18.1960, -63.0880, 'Regular')
placeFacility(AI, 'Volunteer Mortar Platoon',    DB.MORTAR_PLT,  18.2008, -63.0800, 'Veteran')
-- Clayton J. Lloyd International (Wallblake).
placeFacility(AI, 'Wallblake Airfield',          DB.AIRFIELD_MD, 18.2055, -63.0561, 'Regular')
placeFacility(AI, 'Wallblake HMG Platoon',       DB.HMG_PLT,     18.2085, -63.0600, 'Regular')
placeFacility(AI, 'Wallblake ZU-23 Technical',   DB.ZU23_TECH,   18.2030, -63.0640, 'Regular')
placeFacility(AI, 'Mistral Platoon (Wallblake)', DB.MISTRAL,     18.2070, -63.0520, 'Regular')
placeFacility(AI, 'Wallblake Militia',           DB.MILITIA_PLT, 18.2072, -63.0545, 'Novice')
-- The Quarter, held by the volunteer cadre.
placeFacility(AI, 'Valley Road Technical',       DB.KPV_TECH,    18.2110, -63.0450, 'Regular')
placeFacility(AI, 'Volunteer Cadre Platoon',     DB.CADRE_PLT,   18.2082, -63.0395, 'Veteran')
placeFacility(AI, 'Quarter Militia',             DB.MILITIA_PLT, 18.2095, -63.0415, 'Novice')
-- Coastal defence: a second-hand Exocet battery cued by a hilltop radar.
placeFacility(AI, 'Crocus Hill Surface Radar',   DB.SEARCH_RADAR, 18.2166, -63.0661, 'Regular')
placeFacility(AI, 'Exocet Battery (Stoney Ground)', DB.EXOCET_BTY, 18.2230, -63.0200, 'Regular')

-- Air arm, all at Wallblake.
placeAircraft(AI, 'Kfir 1',       DB.KFIR,      'KFIR',      { 'Wallblake Airfield' }, 'Regular')
placeAircraft(AI, 'Kfir 2',       DB.KFIR,      'KFIR',      { 'Wallblake Airfield' }, 'Regular')
placeAircraft(AI, 'Pampa 1',      DB.PAMPA,     'PAMPA',     { 'Wallblake Airfield' }, 'Regular')
placeAircraft(AI, 'Pampa 2',      DB.PAMPA,     'PAMPA',     { 'Wallblake Airfield' }, 'Regular')
placeAircraft(AI, 'Wing Loong 1', DB.WINGLOONG, 'WINGLOONG', { 'Wallblake Airfield' }, 'Regular')
placeAircraft(AI, 'Hermes 1',     DB.HERMES,    'HERMES',    { 'Wallblake Airfield' }, 'Regular')

-- Anguillan Naval Service: one missile boat hiding at Island Harbour, two
-- patrol boats in Crocus Bay on the north coast.
placeShip(AI, 'ANS Sombrero',    DB.FAC_148, 18.2615, -62.9990, 'Regular', 270)
placeShip(AI, 'ANS Dog Island',  DB.DABUR,   18.2240, -63.0765, 'Regular', 270)
placeShip(AI, 'ANS Scrub Island', DB.DABUR,  18.2250, -63.0745, 'Regular', 270)

local roadBay = box(AI, 'Road Bay', 18.2050, -63.1150, 0.0400, 0.0500)
local skies   = box(AI, 'Anguilla Skies', 18.2150, -63.0600, 0.0600, 0.0800)
local north   = box(AI, 'North Watch', 18.2700, -63.0800, 0.0300, 0.0500)
patrol(AI, 'Kfir CAP',          'aaw',   skies,   { 'Kfir 1', 'Kfir 2' }, true)
patrol(AI, 'Wing Loong Hunt',   'naval', roadBay, { 'Wing Loong 1' }, false)
patrol(AI, 'Pampa Strike',      'naval', roadBay, { 'Pampa 1', 'Pampa 2' }, false)
patrol(AI, 'Naval Sortie',      'naval', roadBay, { 'ANS Sombrero', 'ANS Dog Island', 'ANS Scrub Island' }, false)
do
  local ok, m = pcall(ScenEdit_AddMission, AI, 'Hermes Watch', 'Support', { zone = north })
  if ok and m then pcall(ScenEdit_AssignUnitToMission, 'Hermes 1', 'Hermes Watch')
  else note('FAILED: mission Hermes Watch ' .. tostring(m)) end
end

-- ---------------------------------------------------------------------------
-- 6. CIVILIANS (destroying any of these costs the UK points)
-- ---------------------------------------------------------------------------
placeFacility(CIV, "St Mary's Church, The Valley", DB.CHURCH,   18.2160, -63.0530, 'Novice')
placeFacility(CIV, 'Albena Lake-Hodge School',     DB.SCHOOL,   18.2135, -63.0560, 'Novice')
placeFacility(CIV, 'Princess Alexandra Hospital',  DB.HOSPITAL, 18.2125, -63.0505, 'Novice')
placeShip(CIV, 'Charter Yacht Seaborne',  DB.YACHT,      18.2030, -63.0990, 'Novice', 300)
placeShip(CIV, 'Fishing Boat Mary Rose',  DB.SMALL_BOAT, 18.2010, -63.0960, 'Novice', 200)
placeShip(CIV, 'Fishing Boat Island Girl', DB.SMALL_BOAT, 18.1990, -63.0975, 'Novice', 20)

-- ---------------------------------------------------------------------------
-- 7. RUNTIME CONFIGURATION (copied into every event script)
-- ---------------------------------------------------------------------------
local RT = {
  prefix = 'OSH_',
  uk = UK, opfor = AI, civ = CIV,
  not_ground = { Ship = true, Aircraft = true, Submarine = true, Weapon = true, Satellite = true },
  roe_fallback_min = 30,
  roe_msg = '<b>ROE CHANGE.</b> Anguillan forces have opened fire. All engagements are released ' ..
            'to WEAPONS TIGHT; naval gunfire and air strikes may now be called.',
  reload_r = 700,
  intro = '<b>OPERATION SHEARLING, 0500 local, 19 March 2026.</b><br/>RFA Mounts Bay is off Road Bay with ' ..
          'two LCVPs and an LCU in her well: 1 and 2 Platoons for Sandy Ground, the company reserve and mortars ' ..
          'in the LCU. Merlin 1 and Merlin 2 carry 3 Platoon and its fire support group to the LZ at Wallblake. ' ..
          'Four Typhoons stand by at V.C. Bird, Antigua.<br/>Troops go ashore when a craft reaches the beach ' ..
          'marker, or when a Merlin reaches the LZ below 350 m. Empty craft that return to Mounts Bay embark the ' ..
          'next wave.<br/><i>Rules of engagement: do not fire first. The task group is on Weapons Hold ' ..
          '(self-defence only) until the Anguillans open fire.</i>',
  intro_ai = '<b>ANGUILLA, 0500 local, 19 March 2026.</b><br/>A British amphibious task group is off Road Bay. ' ..
             'You command the Anguillan Defence Force, its air arm and navy, the Exocet battery and the volunteer ' ..
             'cadre.<br/>Pre-built missions: <b>Kfir CAP</b> and <b>Hermes Watch</b> are active; <b>Wing Loong Hunt</b>, ' ..
             '<b>Pampa Strike</b> and <b>Naval Sortie</b> are waiting for you to activate them. You score for every ' ..
             'British loss, for each objective you still hold at every full hour, and if the British fire first. You ' ..
             'lose points for each objective lost and each unit lost; civilian losses cost both sides.<br/>' ..
             '<i>The British are on Weapons Hold until you open fire.</i>',
  dest = {
    ['Sandy Ground']  = { lat = 18.1996, lon = -63.0905, r = 600, land_lat = 18.2001, land_lon = -63.0893 },
    ['LZ Wallblake']  = { lat = 18.2045, lon = -63.0610, r = 800, land_lat = 18.2045, land_lon = -63.0612,
                          air = true, maxalt = 350 },
  },
  spawn = {
    ['1 Platoon']                = { dbid = DB.PARA_PLT,   prof = 'Veteran' },
    ['2 Platoon']                = { dbid = DB.PARA_PLT,   prof = 'Veteran' },
    ['3 Platoon']                = { dbid = DB.PARA_PLT,   prof = 'Veteran' },
    ['3 Platoon Fire Support']   = { dbid = DB.HMG_PLT,    prof = 'Veteran' },
    ['Company HQ (JTAC)']        = { dbid = DB.JTAC_SEC,   prof = 'Veteran' },
    ['Company Reserve']          = { dbid = DB.PARA_PLT,   prof = 'Veteran' },
    ['Mortar Section']           = { dbid = DB.MORTAR_PLT, prof = 'Veteran' },
    ['Met Police TSG']           = { dbid = DB.POLICE,     prof = 'Regular', pts = 10 },
  },
  craft = {
    ['LCVP Alpha']  = { mother = 'RFA Mounts Bay', dest = 'Sandy Ground',
                        loads = { { '1 Platoon' }, { 'Company HQ (JTAC)' } } },
    ['LCVP Bravo']  = { mother = 'RFA Mounts Bay', dest = 'Sandy Ground',
                        loads = { { '2 Platoon' },
                                  { 'Met Police TSG', requires = 'obj_beach',
                                    wait_msg = 'The Metropolitan Police will not embark until the Sandy Ground beachhead is secure.',
                                    msg = 'The Metropolitan Police come ashore at Sandy Ground, fifty-seven years after ' ..
                                          'their predecessors did the same thing without a shot fired.' } } },
    ['LCU Foxtrot'] = { mother = 'RFA Mounts Bay', dest = 'Sandy Ground',
                        loads = { { 'Company Reserve', 'Mortar Section' } } },
    ['Merlin 1']    = { mother = 'RFA Mounts Bay', dest = 'LZ Wallblake', loads = { { '3 Platoon' } } },
    ['Merlin 2']    = { mother = 'RFA Mounts Bay', dest = 'LZ Wallblake', loads = { { '3 Platoon Fire Support' } } },
  },
  defenders = { 'Sandy Ground HMG Nest', 'Sandy Ground Militia', 'Sandy Ground Technical', 'FN-6 Team (South Hill)',
                'Volunteer Mortar Platoon', 'Wallblake HMG Platoon', 'Wallblake ZU-23 Technical',
                'Mistral Platoon (Wallblake)', 'Wallblake Militia', 'Valley Road Technical',
                'Volunteer Cadre Platoon', 'Quarter Militia' },
  objectives = {
    { key = 'obj_beach', name = 'Sandy Ground beachhead', lat = 18.2000, lon = -63.0880, r = 700, pts = 15,
      msg = 'Sandy Ground is clear. The Paras push off the sand toward the interior.' },
    { key = 'obj_wallblake', name = 'Wallblake airfield', lat = 18.2055, lon = -63.0570, r = 900, pts = 25,
      msg = 'Clayton J. Lloyd International is in British hands; the Anguillan air arm has lost its only runway.' },
    { key = 'obj_quarter', name = 'The Quarter', lat = 18.2085, lon = -63.0400, r = 700, pts = 15,
      msg = 'The crossroads at The Quarter is in British hands.' },
    { key = 'obj_valley', name = 'The Valley', lat = 18.2146, lon = -63.0518, r = 700, pts = 30,
      msg = '2 PARA is in The Valley, the island capital.' },
  },
  withdraw = {
    name = 'The Quarter', needs_dead = { 'Valley Road Technical' }, lat = 18.2085, lon = -63.0400, r = 1500,
    min_uk = 2, units = { 'Volunteer Cadre Platoon', 'Quarter Militia' },
    dest_lat = 18.2500, dest_lon = -63.0060, pts = 15,
    msg = 'With the Valley road technical destroyed and British troops on their flank, the volunteer cadre and ' ..
          'the militia abandon The Quarter and melt away toward Island Harbour rather than die in place.',
  },
  police = { 'Met Police TSG' },
  valley = { lat = 18.2146, lon = -63.0518, r = 900 },
  end_pts = 10,
  end_msg = '<b>2 PARA holds every objective</b> and the Metropolitan Police are in The Valley. The island is back ' ..
            'under the Crown; the inquiry into how it came to this will take rather longer. The scenario ends in ten minutes.',
  stages = {
    { at = 10, mission = 'Wing Loong Hunt' },
    { at = 20, mission = 'Pampa Strike' },
    { at = 30, mission = 'Naval Sortie' },
  },
  kill = {
    ['Kfir 1'] = 15, ['Kfir 2'] = 15, ['Pampa 1'] = 10, ['Pampa 2'] = 10, ['Wing Loong 1'] = 10, ['Hermes 1'] = 5,
    ['ANS Sombrero'] = 25, ['ANS Dog Island'] = 10, ['ANS Scrub Island'] = 10,
    ['Exocet Battery (Stoney Ground)'] = 30, ['Crocus Hill Surface Radar'] = 10,
    ['Mistral Platoon (Wallblake)'] = 10, ['FN-6 Team (South Hill)'] = 10,
    ['Sandy Ground HMG Nest'] = 10, ['Wallblake HMG Platoon'] = 10, ['Volunteer Mortar Platoon'] = 10,
    ['Sandy Ground Technical'] = 5, ['Wallblake ZU-23 Technical'] = 5, ['Valley Road Technical'] = 5,
    ['Volunteer Cadre Platoon'] = 5,
    ['Sandy Ground Militia'] = -5, ['Wallblake Militia'] = -5, ['Quarter Militia'] = -5,
    ['Wallblake Airfield'] = -10,
  },
  kill_type = { Aircraft = 10, Ship = 10, Facility = 3 },
  kill_msg = {
    ['Exocet Battery (Stoney Ground)'] = 'The Exocet battery at Stoney Ground has been destroyed. The ships can close the coast.',
    ['Crocus Hill Surface Radar'] = 'The Crocus Hill radar is off the air; the Exocets are blind without a third-party cue.',
    ['Sandy Ground HMG Nest'] = 'The machine gun on the ridge above Sandy Ground falls silent.',
    ['Volunteer Mortar Platoon'] = 'The mortars on the reverse slope are destroyed; pressure on the beachhead lifts.',
    ['Valley Road Technical'] = 'The technical on the Valley road is burning.',
  },
  loss = {
    ['HMS Iron Duke'] = 150, ['HMS Dauntless'] = 150, ['RFA Mounts Bay'] = 150, ['HMS Medway'] = 60,
    ['LCVP Alpha'] = 10, ['LCVP Bravo'] = 10, ['LCU Foxtrot'] = 15,
    ['Wildcat 1'] = 15, ['Wildcat 2'] = 15, ['Merlin 1'] = 20, ['Merlin 2'] = 20,
    ['Typhoon 1'] = 30, ['Typhoon 2'] = 30, ['Typhoon 3'] = 30, ['Typhoon 4'] = 30,
    ['1 Platoon'] = 25, ['2 Platoon'] = 25, ['3 Platoon'] = 25, ['Company Reserve'] = 25,
    ['3 Platoon Fire Support'] = 10, ['Mortar Section'] = 10, ['Company HQ (JTAC)'] = 20, ['Met Police TSG'] = 30,
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
luaEvent('OSH Heartbeat', { type = 'RegularTime', Interval = 3 }, HEAD .. HEARTBEAT, true)

for code, kind in pairs({ [1] = 'Aircraft', [2] = 'Ship', [4] = 'Facility' }) do
  luaEvent('OSH Anguilla loses ' .. kind,
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = AI, TargetType = code } },
           HEAD .. OPFOR_LOST, true)
  luaEvent('OSH UK loses ' .. kind,
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = UK, TargetType = code } },
           HEAD .. UK_LOST, true)
end
-- Damage events.  Only ship hits score, so only the ship event repeats; the
-- aircraft and ground events exist to release the ROE and fire once.  Under
-- sustained fire this keeps the event engine from re-running scripts on every
-- hit, which matters in multiplayer.
luaEvent('OSH UK ship hit',
         { type = 'UnitDamaged', DamagePercent = 1, TargetFilter = { TargetSide = UK, TargetType = 2 } },
         HEAD .. UK_HIT, true)
for code, kind in pairs({ [1] = 'Aircraft', [4] = 'Facility' }) do
  luaEvent('OSH UK hit ' .. kind,
           { type = 'UnitDamaged', DamagePercent = 1, TargetFilter = { TargetSide = UK, TargetType = code } },
           HEAD .. UK_HIT, false)
end
-- One launch is enough to release the ROE, so this fires once; a repeating
-- version would run on every missile, shell and drone detection.
luaEvent('OSH Hostile weapon detected',
         { type = 'UnitDetected', DetectorSideID = UK, MCL = 0, TargetFilter = { TargetSide = AI, TargetType = 6 } },
         HEAD .. HOSTILE_FIRE, false)
for code, kind in pairs({ [2] = 'Ship', [4] = 'Facility' }) do
  luaEvent('OSH Civilian ' .. kind .. ' lost',
           { type = 'UnitDestroyed', TargetFilter = { TargetSide = CIV, TargetType = code } },
           HEAD .. CIV_LOST, true)
end

-- ---------------------------------------------------------------------------
-- 9. REPORT
-- ---------------------------------------------------------------------------
print('=== Operation Shearling (2026): build complete ===')
if #REPORT == 0 then print('All units, missions and events created.') end
for _, s in ipairs(REPORT) do print(s) end
if #ARM > 0 then
  print('--- Aircraft to re-arm in the editor (Ready/Arm Aircraft) ---')
  for _, s in ipairs(ARM) do print(s) end
end
print('Next: paste the briefing from briefing_2026.md, set the scoring thresholds, and save.')
