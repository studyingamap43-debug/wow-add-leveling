-- LevelGuide RareAlert: lightweight rare-mob & treasure vignette watcher.
-- Coexists cleanly with RareScanner (mutes duplicate audio chimes when RareScanner is loaded).
-- Provides 1-click /guide rare to temporarily aim Arrow + MinimapTrail + TomTom at the spotted rare.

local GL = LevelGuide
local RA = {}
GL.RareAlert = RA

RA.lastRare = nil      -- { name, mapId, zone, x, y, seenAt }
RA.seenGuids = {}

function RA.OnVignette(vignetteGUID)
  if not vignetteGUID or RA.seenGuids[vignetteGUID] then return end
  if not C_VignetteInfo or not C_VignetteInfo.GetVignetteInfo then return end

  local okI, info = pcall(C_VignetteInfo.GetVignetteInfo, vignetteGUID)
  if not okI or type(info) ~= "table" or not info.name then return end

  RA.seenGuids[vignetteGUID] = true
  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zone, px, py = GL.Compat.ReadPosition()
  end

  local rx, ry = px, py
  if mapId and C_VignetteInfo.GetVignettePosition then
    local okP, pos = pcall(C_VignetteInfo.GetVignettePosition, vignetteGUID, mapId)
    if okP and pos and pos.GetXY then
      local vx, vy = pos:GetXY()
      if vx and vy and (vx ~= 0 or vy ~= 0) then
        rx, ry = vx * 100, vy * 100
      end
    end
  end

  RA.lastRare = {
    name = info.name,
    mapId = mapId,
    zone = zone or "?",
    x = rx,
    y = ry,
    seenAt = GetTime and GetTime() or 0,
  }
  GL.LogEvent("RARE_VIGNETTE", info.name)
  GL.Print(string.format("|cffff80ffRare/Treasure spotted:|r %s (%.1f, %.1f) — type |cfff0c252/guide rare|r to point arrow!",
    tostring(info.name), tonumber(rx or 0), tonumber(ry or 0)))

  -- Respect RareScanner: skip chime/TTS if RareScanner is already alerting
  local hasRS = GL.Integrations and GL.Integrations.detected and GL.Integrations.detected.RareScanner
  if not hasRS and GL.Voice then
    GL.Voice.Speak("Rare spotted: " .. tostring(info.name), false)
  end
end

function RA.OnMouseoverUnit()
  if GL.Compat and GL.Compat.InCombat() then return end
  if not UnitExists or not UnitExists("mouseover") then return end
  if UnitIsDead and UnitIsDead("mouseover") then return end
  local cls = UnitClassification and UnitClassification("mouseover")
  if cls ~= "rare" and cls ~= "rareelite" then return end
  local guid = GL.Compat and GL.Compat.UnitGUID("mouseover") or nil
  if guid and RA.seenGuids[guid] then return end
  if guid then RA.seenGuids[guid] = true end

  local name = (UnitName and UnitName("mouseover")) or "Rare Mob"
  local mapId, zone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    mapId, zone, px, py = GL.Compat.ReadPosition()
  end
  RA.lastRare = {
    name = name,
    mapId = mapId,
    zone = zone or "?",
    x = px,
    y = py,
    seenAt = GetTime and GetTime() or 0,
  }
  GL.LogEvent("RARE_MOUSEOVER", name)
  GL.Print(string.format("|cffff80ffRare Mob (%s):|r %s — type |cfff0c252/guide rare|r to pin!", tostring(cls), tostring(name)))
end

function RA.PinLastRare()
  local r = RA.lastRare
  if not r or not r.x or not r.y then
    GL.Print("No recent rare mob/treasure recorded in this session.")
    return
  end
  if GL.Arrow and GL.Arrow.SetTarget then
    GL.Arrow.SetTarget(r.mapId, r.zone, r.x, r.y, "RARE", r.name)
  end
  if GL.MinimapTrail and GL.MinimapTrail.SetTarget then
    GL.MinimapTrail.SetTarget(r.mapId, r.zone, r.x, r.y)
  end
  if GL.db and GL.db.settings.useTomTom and TomTom and TomTom.AddWaypoint and r.mapId then
    pcall(TomTom.AddWaypoint, TomTom, r.mapId, r.x / 100, r.y / 100, { title = "RARE: " .. r.name, persistent = false })
  end
  GL.Print(string.format("Pinned Rare: %s in %s (%.1f, %.1f). Use /guide pin to return to quest.", r.name, r.zone, r.x, r.y))
end
