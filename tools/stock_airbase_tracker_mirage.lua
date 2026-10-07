-- Stock airbase 5H7OE1-0HNP4KC9K4H3D for every S-2E Tracker (#1739) and Mirage IIIEA (#1221) loadout (Cold War DB)
local G, PACKS, MAG = '5H7OE1-0HNP4KC9K4H3D', 12, 36
-- Weapon DBIDs: HVAR 1395, SSQ-41A 1278, SSQ-47 1274, Aerial DC 431, Mk44 47, Mk81 1166, Mk82 6, Mk83 409,
-- R.530 92, R.550 37, tanks 500L 522, 625L 521, 1300L 527, 1700L 526.  Format: {loadout id, {dbid, count, ...}}
local L = {
  {4946, {47,2, 1278,24, 1274,8}}, {4947, {1395,6, 47,2, 1278,24, 1274,8}},
  {4948, {1166,6, 431,4, 1278,24, 1274,8}}, {4949, {1395,6, 431,4, 1278,24, 1274,8}},
  {3463, {527,1, 526,2}}, {3464, {92,1, 37,2, 522,2}}, {3465, {37,2, 522,2, 521,1}},
  {3466, {37,2, 6,2, 527,1, 526,2}}, {3467, {37,2, 6,6, 526,2}}, {3468, {37,2, 409,2, 526,2}},
  {3469, {37,2, 409,4}},
}
local function base() return ScenEdit_GetUnit({guid = G}) end
local function mags(u) local n = 0 for _ in pairs(u.magazines or {}) do n = n + 1 end return n end
if mags(base()) == 0 then
  local ok, e = pcall(ScenEdit_UpdateUnit, {guid = G, mode = 'add_magazine', dbid = MAG})
  print(ok and 'Added Munitions magazine' or ('Could not add magazine: ' .. tostring(e)))
end
local extra = {}
for _, lo in ipairs(L) do
  local ok, r = pcall(ScenEdit_FillMagsForLoadout, {guid = G, unitname = G, loadoutid = lo[1], quantity = PACKS})
  if not ok then ok, r = pcall(ScenEdit_FillMagsForLoadout, {guid = G, unitname = G}, lo[1], PACKS) end
  local t = {} if type(r) == 'table' then for _, v in pairs(r) do t[#t + 1] = tostring(v) end end
  local msg = type(r) == 'table' and table.concat(t, '; ') or tostring(r)
  if ok and not msg:lower():find('fail') and not msg:lower():find('error') then
    print('Loadout ' .. lo[1] .. ': stocked x' .. PACKS .. ' ' .. msg)
  else
    print('Loadout ' .. lo[1] .. ': refused (' .. msg .. '), adding weapons directly')
    for i = 1, #lo[2], 2 do extra[lo[2][i]] = (extra[lo[2][i]] or 0) + lo[2][i + 1] * PACKS end
  end
end
for dbid, n in pairs(extra) do
  local ok, r = pcall(ScenEdit_AddWeaponToUnitMagazine, {guid = G, wpn_dbid = dbid, number = n, new = true, maxcap = n * 2})
  print('Weapon ' .. dbid .. ': ' .. (ok and ('added ' .. tostring(r) .. ' of ' .. n) or ('FAILED ' .. tostring(r))))
end
for _, m in pairs(base().magazines or {}) do
  print(tostring(m.mag_name))
  for _, w in pairs(m.mag_weapons or {}) do print('  ' .. tostring(w.wpn_name) .. ': ' .. tostring(w.wpn_current)) end
end
print('Done.')
