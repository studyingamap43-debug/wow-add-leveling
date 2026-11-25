-- LevelGuide MinimapTrail: lightweight breadcrumb dot trail on the Minimap pointing to the active waypoint.
-- Zero per-frame allocations (reuses fixed pool of 8 Texture dots), respects rotateMinimap & zoom,
-- hides cleanly inside instances, and never conflicts with GatherLite / HandyNotes / RareScanner.

local GL = LevelGuide
local MT = {}
GL.MinimapTrail = MT

local NUM_DOTS = 8
local UPDATE_HZ = 0.05
local OUTDOOR_ZOOM_YARDS = { [0] = 233.3, [1] = 200.0, [2] = 166.7, [3] = 133.3, [4] = 100.0, [5] = 66.7 }
local INDOOR_ZOOM_YARDS  = { [0] = 150.0, [1] = 120.0, [2] = 90.0,  [3] = 60.0,  [4] = 40.0,  [5] = 25.0 }

MT.holder = nil
MT.dots = {}
MT.target = nil
MT.accum = 0

function MT.Create()
  if MT.holder or not Minimap or not CreateFrame then return end
  local h = CreateFrame("Frame", "LevelGuideMinimapTrailFrame", Minimap)
  h:SetAllPoints(Minimap)
  h:SetFrameLevel(Minimap:GetFrameLevel() + 5)

  for i = 1, NUM_DOTS do
    local dot = h:CreateTexture(nil, "OVERLAY")
    local sz = (i == NUM_DOTS) and 9 or 5
    dot:SetSize(sz, sz)
    dot:SetTexture("Interface\\Buttons\\WHITE8X8")
    dot:Hide()
    MT.dots[i] = dot
  end

  h:SetScript("OnUpdate", function(_, elapsed)
    MT.accum = MT.accum + (elapsed or 0)
    if MT.accum < UPDATE_HZ then return end
    MT.accum = 0
    GL.Safe("MinimapTrail.Update", MT.Update)
  end)

  MT.holder = h
end

function MT.HideAll()
  for i = 1, NUM_DOTS do
    if MT.dots[i] then MT.dots[i]:Hide() end
  end
end

function MT.SetTarget(mapId, zoneName, x, y)
  if not x or not y then
    MT.Clear()
    return
  end
  if not MT.holder then MT.Create() end
  MT.target = { mapId = mapId, zoneName = zoneName or "?", x = x, y = y }
  MT.Update()
end

function MT.Clear()
  MT.target = nil
  MT.HideAll()
end

function MT.Update()
  local tgt = MT.target
  if not MT.holder or not tgt or not Minimap then return end
  if GL.db and GL.db.settings and GL.db.settings.trailEnabled == false then
    MT.HideAll()
    return
  end
  if IsInInstance then
    local okI, inInst = pcall(IsInInstance)
    if okI and inInst then MT.HideAll() return end
  end

  local pMapId, pZone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    pMapId, pZone, px, py = GL.Compat.ReadPosition()
  end
  local sameMap = (tgt.mapId and pMapId and tgt.mapId == pMapId)
    or (tgt.zoneName and pZone and string.lower(tgt.zoneName) == string.lower(pZone))
  if not sameMap or not px or not py then
    MT.HideAll()
    return
  end

  local dx = (tgt.x - px) / 100
  local dy = (tgt.y - py) / 100
  local mapW, mapH = 1500, 1000
  if tgt.mapId and C_Map and C_Map.GetMapWorldSize then
    local okS, w, h = pcall(C_Map.GetMapWorldSize, tgt.mapId)
    if okS and w and h and w > 0 and h > 0 then mapW, mapH = w, h end
  end
  local ydX = dx * mapW
  local ydY = dy * mapH
  local distYd = math.sqrt(ydX * ydX + ydY * ydY)
  if distYd < 8 then
    MT.HideAll()
    return
  end

  -- Minimap screen vector: screen +X is East, screen +Y is North (-ydY)
  local sx = ydX
  local sy = -ydY

  -- Account for rotating minimap CVar if enabled
  local rotMinimap = GL.Compat and GL.Compat.GetCVar("rotateMinimap") == "1"
  if rotMinimap and GetPlayerFacing then
    local okF, rawF = pcall(GetPlayerFacing)
    local facing = (okF and GL.Compat and GL.Compat.SafeNumber(rawF, 0)) or 0
    local cs, sn = math.cos(-facing), math.sin(-facing)
    local rx = sx * cs - sy * sn
    local ry = sx * sn + sy * cs
    sx, sy = rx, ry
  end

  local zoom = (Minimap.GetZoom and Minimap:GetZoom()) or 0
  local indoors = IsIndoors and IsIndoors()
  local tbl = indoors and INDOOR_ZOOM_YARDS or OUTDOOR_ZOOM_YARDS
  local radiusYd = tbl[zoom] or (indoors and 90.0 or 166.7)
  local radiusPx = math.max(40, (Minimap:GetWidth() or 140) * 0.46)

  -- Scale target into minimap pixel space, clamping endpoint to the minimap rim
  local scale = radiusPx / radiusYd
  local endX = sx * scale
  local endY = sy * scale
  local endLen = math.sqrt(endX * endX + endY * endY)
  if endLen > radiusPx then
    local clamp = radiusPx / endLen
    endX = endX * clamp
    endY = endY * clamp
  end

  local close = (distYd <= 35)
  for i = 1, NUM_DOTS do
    local dot = MT.dots[i]
    local frac = i / NUM_DOTS
    dot:ClearAllPoints()
    dot:SetPoint("CENTER", Minimap, "CENTER", endX * frac, endY * frac)
    if i == NUM_DOTS then
      if close then dot:SetColorTexture(0.18, 0.95, 0.50, 0.95)
      else dot:SetColorTexture(0.98, 0.80, 0.25, 0.95) end
    else
      local alpha = 0.30 + 0.55 * frac
      if close then dot:SetColorTexture(0.22, 0.88, 0.52, alpha)
      else dot:SetColorTexture(0.95, 0.76, 0.30, alpha) end
    end
    dot:Show()
  end
end
