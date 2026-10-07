--[[
===============================================================================
  Stock an airbase for every loadout of the S-2E Tracker and the Mirage IIIEA
  Command: Modern Operations, Lua Script Console (Cold War database)
-------------------------------------------------------------------------------
  Target   : Single-Unit Airfield (2x 1401-2000m Runways)
             GUID 5H7OE1-0HNP4KC9K4H3D
  Aircraft : #1739 S-2E Tracker (Brazil, 1975)
             #1221 Mirage IIIEA (Argentina, 1979)

  What it does
    1. Finds the airbase by GUID.  If it has no magazine, adds a generic
       "Munitions" magazine (DBID 36) to hold the stores.
    2. For every loadout that carries stores, asks the game to stock the
       airbase with PACKS full sets of that loadout
       (ScenEdit_FillMagsForLoadout), so the quantities come straight from
       the database.
    3. If the game refuses a loadout, adds that loadout's weapons one by one
       instead (ScenEdit_AddWeaponToUnitMagazine), using the weapon IDs below.
    4. Prints what is in the airbase magazines when it finishes.

  Notes
    - Weapon IDs come from the CWDB_442 component list and match the IDs the
      game wrote into the Act of War 1968 unit file; they are stable across
      Cold War database versions.
    - (Maintenance) and (Reserve) loadouts carry no stores and are skipped.
      (Ferry) and Maritime Surveillance are included; the Tracker ones carry
      nothing, the Mirage ferry load carries drop tanks.
    - The Mirage's 30mm DEFA cannon ammunition is internal to the aircraft
      and is not drawn from a magazine, so it is not added.
    - Running the script twice adds a second set of stores.
===============================================================================
]]

-- ---------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------
local BASE_GUID = '5H7OE1-0HNP4KC9K4H3D'
local BASE_NAME = 'Single-Unit Airfield (2x 1401-2000m Runways)'

-- Full loadout sets to stock per loadout.  Raise it for long scenarios or
-- many aircraft; e.g. 4 aircraft x 3 sorties = 12.
local PACKS = 12

-- Magazine to add when the airbase has none: "Munitions -- Empty".
local MUNITIONS_MAG_DBID = 36

-- ---------------------------------------------------------------------------
-- Weapon database IDs (Cold War database)
-- ---------------------------------------------------------------------------
local W = {
  HVAR_127      = 1395,  -- 127mm HVAR Rocket
  SSQ41A        = 1278,  -- AN/SSQ-41A Jezebel LOFAR
  SSQ47         = 1274,  -- AN/SSQ-47 Julie Active Range-Only
  DC_AERIAL     = 431,   -- Depth Charge [Aerial]
  MK44_MOD1     = 47,    -- Mk44 Mod 1
  MK81          = 1166,  -- Mk81 250lb LDGP
  MK82          = 6,     -- Mk82 500lb LDGP
  MK83          = 409,   -- Mk83 1000lb LDGP
  R530          = 92,    -- R.530 (SARH)
  R550          = 37,    -- R.550 Magic 1
  TANK_500L     = 522,   -- 500 liter Drop Tank
  TANK_625L     = 521,   -- 625 liter Drop Tank
  TANK_1300L    = 527,   -- 1300 liter Drop Tank
  TANK_1700L    = 526,   -- 1700 liter Drop Tank
}

-- ---------------------------------------------------------------------------
-- Loadouts (from the database sheets).  stores = { {weapon, count}, ... }
-- ---------------------------------------------------------------------------
local AIRCRAFT = {
  {
    name = 'S-2E Tracker (Brazil, 1975) #1739',
    loadouts = {
      { id = 4944, name = '(Ferry)',                                   stores = {} },
      { id = 4945, name = 'Maritime Surveillance',                     stores = {} },
      { id = 4946, name = 'Mk44 LWT, Jezebel, Julie',
        stores = { { W.MK44_MOD1, 2 }, { W.SSQ41A, 24 }, { W.SSQ47, 8 } } },
      { id = 4947, name = 'Mk44 LWT, ZUNI 127mm Rockets, Jezebel, Julie',
        stores = { { W.HVAR_127, 6 }, { W.MK44_MOD1, 2 }, { W.SSQ41A, 24 }, { W.SSQ47, 8 } } },
      { id = 4948, name = 'Mk81 250lb LDGP, Jezebel, Julie',
        stores = { { W.MK81, 6 }, { W.DC_AERIAL, 4 }, { W.SSQ41A, 24 }, { W.SSQ47, 8 } } },
      { id = 4949, name = 'ZUNI 127mm HVAR Rockets, Jezebel, Julie',
        stores = { { W.HVAR_127, 6 }, { W.DC_AERIAL, 4 }, { W.SSQ41A, 24 }, { W.SSQ47, 8 } } },
    },
  },
  {
    name = 'Mirage IIIEA (Argentina, 1979) #1221',
    loadouts = {
      { id = 3463, name = '(Ferry)',
        stores = { { W.TANK_1300L, 1 }, { W.TANK_1700L, 2 } } },
      { id = 3464, name = 'A/A: R.530',
        stores = { { W.R530, 1 }, { W.R550, 2 }, { W.TANK_500L, 2 } } },
      { id = 3465, name = 'A/A: R.550 Magic',
        stores = { { W.R550, 2 }, { W.TANK_500L, 2 }, { W.TANK_625L, 1 } } },
      { id = 3466, name = 'Mk82 LDGP',
        stores = { { W.R550, 2 }, { W.MK82, 2 }, { W.TANK_1300L, 1 }, { W.TANK_1700L, 2 } } },
      { id = 3467, name = 'Mk82 LDGP, Heavy',
        stores = { { W.R550, 2 }, { W.MK82, 6 }, { W.TANK_1700L, 2 } } },
      { id = 3468, name = 'Mk83 LDGP',
        stores = { { W.R550, 2 }, { W.MK83, 2 }, { W.TANK_1700L, 2 } } },
      { id = 3469, name = 'Mk83 LDGP, Short-Range',
        stores = { { W.R550, 2 }, { W.MK83, 4 } } },
    },
  },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function getBase()
  local ok, u = pcall(ScenEdit_GetUnit, { guid = BASE_GUID })
  if ok and u then return u end
  error('Airbase not found: ' .. BASE_NAME .. ' (' .. BASE_GUID .. '). Check the GUID in the unit window.')
end

local function magazineCount(u)
  local n = 0
  pcall(function() for _ in pairs(u.magazines or {}) do n = n + 1 end end)
  return n
end

-- Current load of a weapon across the base's magazines (0 if unknown).
local function currentLoad(u, dbid)
  local total = 0
  pcall(function()
    for _, m in pairs(u.magazines or {}) do
      for _, w in pairs(m.mag_weapons or {}) do
        if tonumber(w.wpn_dbid) == dbid then total = total + (tonumber(w.wpn_current) or 0) end
      end
    end
  end)
  return total
end

-- The documentation shows two call shapes; try the documented example first.
local function fillForLoadout(loadoutId, packs)
  local ok, res = pcall(ScenEdit_FillMagsForLoadout,
                        { guid = BASE_GUID, unitname = BASE_GUID, loadoutid = loadoutId, quantity = packs })
  if not ok then
    ok, res = pcall(ScenEdit_FillMagsForLoadout, { guid = BASE_GUID, unitname = BASE_GUID }, loadoutId, packs)
  end
  if not ok then return false, tostring(res) end
  -- The function returns a table of messages; treat any failure text as a refusal.
  local text, failed = {}, false
  if type(res) == 'table' then
    for _, m in pairs(res) do
      local s = tostring(m)
      text[#text + 1] = s
      if s:lower():find('fail') or s:lower():find('error') or s:lower():find('not ') then failed = true end
    end
  elseif res ~= nil then
    text[1] = tostring(res)
  end
  return not failed, table.concat(text, '; ')
end

-- ---------------------------------------------------------------------------
-- 1. Airbase and magazine
-- ---------------------------------------------------------------------------
local base = getBase()
print('Airbase: ' .. tostring(base.name) .. ' [' .. BASE_GUID .. ']')

if magazineCount(base) == 0 then
  local ok, err = pcall(ScenEdit_UpdateUnit, { guid = BASE_GUID, mode = 'add_magazine', dbid = MUNITIONS_MAG_DBID })
  if ok then
    print('Added a Munitions magazine (DBID ' .. MUNITIONS_MAG_DBID .. ') to hold the stores.')
  else
    print('WARNING: could not add a magazine: ' .. tostring(err))
  end
  base = getBase()
else
  print('Using the airbase\'s existing magazine(s): ' .. magazineCount(base))
end

-- ---------------------------------------------------------------------------
-- 2. Stock every loadout; collect refused loadouts for the fallback
-- ---------------------------------------------------------------------------
local fallback = {}   -- weapon dbid -> number to add
local stocked, refused, skipped = 0, 0, 0

for _, ac in ipairs(AIRCRAFT) do
  print('--- ' .. ac.name)
  for _, lo in ipairs(ac.loadouts) do
    if #lo.stores == 0 then
      skipped = skipped + 1
      print(string.format('  %d %-45s no stores, skipped', lo.id, lo.name))
    else
      local ok, info = fillForLoadout(lo.id, PACKS)
      if ok then
        stocked = stocked + 1
        print(string.format('  %d %-45s stocked x%d  %s', lo.id, lo.name, PACKS, info))
      else
        refused = refused + 1
        print(string.format('  %d %-45s refused (%s); adding weapons directly', lo.id, lo.name, info))
        for _, st in ipairs(lo.stores) do
          fallback[st[1]] = (fallback[st[1]] or 0) + st[2] * PACKS
        end
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- 3. Fallback: add the refused loadouts' weapons directly
-- ---------------------------------------------------------------------------
if next(fallback) then
  print('--- Direct weapon additions')
  base = getBase()
  for dbid, number in pairs(fallback) do
    local cap = currentLoad(base, dbid) + number
    local ok, res = pcall(ScenEdit_AddWeaponToUnitMagazine,
                          { guid = BASE_GUID, wpn_dbid = dbid, number = number, new = true, maxcap = cap })
    if ok then
      print(string.format('  weapon %5d: requested %d, added %s', dbid, number, tostring(res)))
    else
      print(string.format('  weapon %5d: FAILED (%s)', dbid, tostring(res)))
    end
  end
end

-- ---------------------------------------------------------------------------
-- 4. Report
-- ---------------------------------------------------------------------------
print('--- Airbase magazines now hold')
base = getBase()
local okReport = pcall(function()
  for _, m in pairs(base.magazines or {}) do
    print('  ' .. tostring(m.mag_name))
    for _, w in pairs(m.mag_weapons or {}) do
      print(string.format('    %-45s %s', tostring(w.wpn_name), tostring(w.wpn_current)))
    end
  end
end)
if not okReport then print('  (could not read the magazine contents; check the unit\'s Magazines window)') end

print(string.format('Done: %d loadouts stocked by the game, %d added weapon by weapon, %d without stores skipped.',
                    stocked, refused, skipped))
