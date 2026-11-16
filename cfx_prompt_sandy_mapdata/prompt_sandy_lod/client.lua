-- prompt_sandy_lod: draw distance zone for Sandy Shores (port of prompt_island_farlod v3.3, zones instead of the cell map).
--
-- The game multiplies every map draw distance by the player's Extended Distance Scaling (1.0 at 0, up to 1.75 at maximum).
-- The Sandy maps and their LODs are built for the default distance; at maximum the town draws ~45 % more and gets heavy.
-- Inside the zones below each player gets min(zone step, their own scale) per level:
--   * global lod_mult = 1 / own scale normalises the player's scale (lights and everything else at the default distance),
--   * per-level multipliers (HD, ORPHANHD, LOD/SLOD1/SLOD2) give distance back up to the zone's step,
--   * SLOD3/SLOD4 (the far horizon: Chiliad, the Alamo Sea shores, Los Santos) are given back in full, so the horizon is native,
--   * players at the default scale never change; players in between get at most their own scale per level.
-- Outside every zone nothing is touched. Cost: one check every 0.5 s (camera position, clock, a few distance tests).
-- Smoothing as in farlod v3.3: drops quickly when entering, rises slowly (about 4 s per step) when leaving.
--   /sandylod off | on        everything off / on
--   /sandylod step <0-9>      force a ladder step everywhere inside the zones (testing); /sandylod auto = zones again
--   /sandylodinfo             print zone, target, applied values once
local MOD = 'prompt_sandy_lod'
local TICK = 500
local UP_S, DOWN_S = 4.0, 2.0
local Z = SANDY_LOD_ZONES                 -- zones.lua
local L = Z.ladder                        -- {HD, ORPHANHD, LOD} per step; last entry = native
local NATIVE = #L - 1
local FULL = Z.full or 7
local DOWN, UP = NATIVE / (DOWN_S / (TICK / 1000.0)), (TICK / 1000.0) / UP_S
local enabled, forced, applied = true, nil, false
local scale
local cur, target = NATIVE + 0.0, NATIVE
local last, info = {}, {}
local mls, mlsLast

-- Rockstar's maxlodscaler ({lod_mult_orphanhd 1.143}) is applied last with the slider as strength and overwrites our orphan level,
-- so the orphan value goes into maxlodscaler too; its original pair is saved on entering and put back on leaving.
local function saveMls()
  if not mls then
    local ok, a, b = GetTimecycleModifierVar('maxlodscaler', 'lod_mult_orphanhd')
    if ok and a then mls = { a, b or a } end
  end
end
local function orphan(v)
  saveMls()
  if mls and (mlsLast == nil or math.abs(mlsLast - v) > 0.01) then
    SetTimecycleModifierVar('maxlodscaler', 'lod_mult_orphanhd', v + 0.0, v + 0.0); mlsLast = v
  end
end
local function restoreMls()
  if mls then SetTimecycleModifierVar('maxlodscaler', 'lod_mult_orphanhd', mls[1] + 0.0, mls[2] + 0.0) end
  mls, mlsLast = nil, nil
end
local function set(var, v)
  if last[var] == nil or math.abs(last[var] - v) > 0.01 then SetTimecycleModifierVar(MOD, var, v + 0.0, v + 0.0); last[var] = v end
end
local VARS = { 'lod_mult', 'lod_mult_hd', 'lod_mult_orphanhd', 'lod_mult_lod', 'lod_mult_slod1', 'lod_mult_slod2', 'lod_mult_slod3', 'lod_mult_slod4' }
local function clear()
  ClearExtraTimecycleModifier(); restoreMls()
  last = {}
  for _, v in ipairs(VARS) do RemoveTimecycleModifierVar(MOD, v) end
  applied = false; cur = NATIVE + 0.0
end

-- own scale: GetLodscale() = own scale x the global lod_mult of active modifiers, so take ours out while applied
local function ownScale()
  local s = GetLodscale()
  if applied and last['lod_mult'] and last['lod_mult'] > 0 then s = s / last['lod_mult'] end
  if s < 1.0 then s = 1.0 elseif s > 1.75 then s = 1.75 end
  return s
end

-- lowest step of the zones containing the camera (day / night values); nil = outside every zone.
-- A zone with 'high' uses that step while the camera is >= HIGH_M above the ground right under it (roofs, aircraft): from up
-- there the default distance shows nearby buildings swapping to LOD, so a gentler step can be chosen for elevated views.
local HIGH_M = Z.highAbove or 15.0
local function zoneStep(x, y, zc)
  local h = GetClockHours(); local night = (h >= 20 or h < 6)
  local best, up
  for i, z in ipairs(Z.zones) do
    local dx, dy = x - z.x, y - z.y
    if dx * dx + dy * dy < z.r * z.r then
      local s = night and z.night or z.day
      if z.high then
        if up == nil then
          local found, gz = GetGroundZFor_3dCoord(x, y, zc + 0.5, false)
          up = (found and gz and gz > -100.0) and (zc - gz) or 0.0
        end
        if up >= HIGH_M then s = z.high end
      end
      if not best or s < best then best = s; info.zone = i end
    end
  end
  info.up = up
  return best
end

local function stepValues(s)
  local i = math.floor(s)
  if i >= NATIVE then return L[NATIVE + 1][1], L[NATIVE + 1][2], L[NATIVE + 1][3] end
  local f = s - i; local p, q = L[i + 1], L[i + 2]
  return p[1] + (q[1] - p[1]) * f, p[2] + (q[2] - p[2]) * f, p[3] + (q[3] - p[3]) * f
end

local function apply()
  if cur > FULL then
    -- between step FULL (every level at the full scale, lights at default) and native: the global distance rises while the
    -- per-level values shrink to match; the orphan level moves to Rockstar's native value (farlod v3.3)
    local f = (cur - FULL) / (NATIVE - FULL); if f > 1.0 then f = 1.0 end
    saveMls()
    local light = 1.0 + (scale - 1.0) * f
    local alpha = (scale - 1.0) / 0.75
    local nat = 1.0 + ((mls and mls[1] or 1.143) - 1.0) * alpha
    local lvl = scale / light
    local orph = scale * (1.0 + (nat - 1.0) * f) / light
    if f >= 0.999 then lvl = 1.0; orph = 1.0; if mls then orphan(mls[1]) end else orphan(orph) end
    set('lod_mult', light / scale)
    set('lod_mult_hd', lvl); set('lod_mult_orphanhd', orph)
    set('lod_mult_lod', lvl); set('lod_mult_slod1', lvl); set('lod_mult_slod2', lvl)
    set('lod_mult_slod3', lvl); set('lod_mult_slod4', lvl)
    info.hd, info.orph, info.lod, info.native = lvl, orph, lvl, f
  else
    set('lod_mult', 1.0 / scale)
    local hd, orph, lod = stepValues(cur)
    hd, orph, lod = math.min(hd, scale), math.min(orph, scale), math.min(lod, scale)
    set('lod_mult_hd', hd); set('lod_mult_orphanhd', orph); orphan(orph)
    set('lod_mult_lod', lod); set('lod_mult_slod1', lod); set('lod_mult_slod2', lod)
    set('lod_mult_slod3', scale); set('lod_mult_slod4', scale)      -- far horizon native
    info.hd, info.orph, info.lod, info.native = hd, orph, lod, 0
  end
  if not applied then SetExtraTimecycleModifier(MOD); applied = true end   -- once on entering (re-adapts exposure)
end

-- One copy only: when this file runs inside another resource (the generated cfx_prompt_sandy_mapdata) while a standalone
-- 'prompt_sandy_lod' resource is started, this copy stays idle and the standalone one does the work.
local STANDALONE = 'prompt_sandy_lod'
local function deferToStandalone()
  return GetCurrentResourceName() ~= STANDALONE and GetResourceState(STANDALONE) == 'started'
end
local idleAtStart = deferToStandalone()

CreateThread(function()
  CreateTimecycleModifier(MOD)
  local own = GetTimecycleModifierIndexByName(MOD)
  while true do
    if deferToStandalone() then
      if applied then clear() end
    else
    local cam = GetFinalRenderedCamCoord()
    local zs = enabled and zoneStep(cam.x, cam.y, cam.z) or nil
    if zs and forced then zs = forced end
    local s = ownScale()
    if zs and s > 1.01 then
      if applied and GetExtraTimecycleModifierIndex() == -1 then applied = false; last = {} end   -- slot cleared by someone: take it back
      if not applied or not scale or math.abs(s - scale) > 0.02 then scale = s; last['lod_mult'] = nil end
      target = zs
      if target < cur then cur = math.max(target + 0.0, cur - DOWN) elseif target > cur then cur = math.min(target + 0.0, cur + UP) end
      local slot = GetExtraTimecycleModifierIndex()
      if slot == -1 or slot == own then apply() end            -- another script holds the slot: do not fight it
    elseif applied then
      -- leaving: rise smoothly to native, then let go
      target = NATIVE
      cur = math.min(NATIVE + 0.0, cur + UP * 2)
      if cur >= NATIVE or not enabled or s <= 1.01 then clear()
      else local slot = GetExtraTimecycleModifierIndex(); if slot == -1 or slot == own then apply() end end
    end
    end   -- not deferring to a standalone copy
    Wait(TICK)
  end
end)

local function say(msg) TriggerEvent('chat:addMessage', { args = { 'sandylod', msg } }) end
if not idleAtStart then   -- the standalone copy owns the commands when it runs
RegisterCommand('sandylod', function(_, args)
  local a = args[1] or 'on'
  if a == 'step' and tonumber(args[2] or '') then forced = math.max(0, math.min(NATIVE, math.floor(tonumber(args[2])))); cur = forced + 0.0; say('forced step ' .. forced)
  elseif a == 'auto' then forced = nil; say('zones')
  else enabled = a ~= 'off'; if applied and not enabled then clear() end; say(enabled and 'on' or 'off') end
end, false)
RegisterCommand('sandylodinfo', function()
  say(string.format('applied %s, your scale %.2f, zone %s, target %s, current %.2f -> HD %.2f ORPHANHD %.2f LOD %.2f native %.0f%%',
    tostring(applied), scale or 0, tostring(info.zone), tostring(target), cur, info.hd or 0, info.orph or 0, info.lod or 0, (info.native or 0) * 100))
end, false)
end
-- read-only state for tests
exports('GetState', function() return { applied = applied, scale = scale, target = target, cur = cur, hd = info.hd, orph = info.orph, lod = info.lod } end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() and applied then clear() end end)
