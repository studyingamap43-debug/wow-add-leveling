-- LevelGuide WorldMapOverlay: draws active quest pin, guide breadcrumb trail dots,
-- and GatherMate2/recorded Herb & Mining node dots directly on the open WorldMapFrame.
-- Compatible with OpenMap & Leatrix Maps (never overrides map zoom or blocks clicks).

local GL = LevelGuide
local WM = {}
GL.WorldMapOverlay = WM

local NUM_TRAIL = 8
local MAX_NODES = 45

WM.layer = nil
WM.questPin = nil
WM.trailDots = {}
WM.nodeDots = {}
WM.target = nil -- { mapId, zoneName, x_0_100, y_0_100, kind, label }

local function getCanvas()
  if not WorldMapFrame then return nil end
  if WorldMapFrame.GetCanvas then
    local ok, c = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
    if ok and c then return c end
  end
  if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
    return WorldMapFrame.ScrollContainer.Child
  end
  return nil
end

function WM.Create()
  if WM.layer then return end
  local canvas = getCanvas()
  if not canvas or not CreateFrame then return end

  local layer = CreateFrame("Frame", "LevelGuideWorldMapLayer", canvas)
  layer:SetAllPoints(canvas)
  layer:SetFrameLevel((canvas:GetFrameLevel() or 1) + 20)
  WM.layer = layer

  -- Active Quest Target Pin
  local pin = CreateFrame("Button", nil, layer)
  pin:SetSize(16, 16)
  local ptex = pin:CreateTexture(nil, "OVERLAY")
  ptex:SetAllPoints(pin)
  ptex:SetTexture("Interface\\Buttons\\WHITE8X8")
  pin.tex = ptex
  pin:SetScript("OnEnter", function(self)
    if GameTooltip and WM.target then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("|cfff0c252LevelGuide Target|r")
      GameTooltip:AddLine(tostring(WM.target.label or "Quest"), 1, 1, 1)
      GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", tostring(WM.target.zoneName or "?"), WM.target.x or 0, WM.target.y or 0), 0.6, 0.85, 1)
      GameTooltip:Show()
    end
  end)
  pin:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  pin:Hide()
  WM.questPin = pin

  -- Guide breadcrumb trail dots on World Map
  for i = 1, NUM_TRAIL do
    local d = layer:CreateTexture(nil, "OVERLAY")
    d:SetSize(6, 6)
    d:SetTexture("Interface\\Buttons\\WHITE8X8")
    d:Hide()
    WM.trailDots[i] = d
  end

  -- Herb / Mining node dots on World Map
  for i = 1, MAX_NODES do
    local nd = layer:CreateTexture(nil, "ARTWORK")
    nd:SetSize(6, 6)
    nd:SetTexture("Interface\\Buttons\\WHITE8X8")
    nd:Hide()
    WM.nodeDots[i] = nd
  end

  if WorldMapFrame and WorldMapFrame.HookScript then
    pcall(WorldMapFrame.HookScript, WorldMapFrame, "OnShow", function() GL.Safe("WM.Update", WM.Update) end)
  end
  if WorldMapFrame and hooksecurefunc and WorldMapFrame.OnMapChanged then
    pcall(hooksecurefunc, WorldMapFrame, "OnMapChanged", function() GL.Safe("WM.Update", WM.Update) end)
  end
end

function WM.HideAll()
  if WM.questPin then WM.questPin:Hide() end
  for i = 1, NUM_TRAIL do if WM.trailDots[i] then WM.trailDots[i]:Hide() end end
  for i = 1, MAX_NODES do if WM.nodeDots[i] then WM.nodeDots[i]:Hide() end end
end

function WM.SetTarget(mapId, zoneName, x, y, kind, label)
  WM.target = (mapId and x and y) and {
    mapId = mapId, zoneName = zoneName, x = x, y = y, kind = kind, label = label,
  } or nil
  GL.Safe("WM.Update", WM.Update)
end

function WM.OpenToTarget()
  if GL.Compat and GL.Compat.InCombat() then
    GL.Print("Cannot open World Map during combat.")
    return
  end
  local mapId = WM.target and WM.target.mapId or nil
  if mapId and C_Map and C_Map.OpenWorldMap then
    pcall(C_Map.OpenWorldMap, mapId)
  elseif mapId and OpenWorldMap then
    pcall(OpenWorldMap, mapId)
  elseif ToggleWorldMap and WorldMapFrame and not WorldMapFrame:IsShown() then
    pcall(ToggleWorldMap)
  end
  GL.Safe("WM.Update", WM.Update)
end

function WM.Update()
  if not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  -- Clean OpenMap compatibility: hide Blizzard-canvas overlay when OpenMap stitched view is active
  if GL.Integrations and GL.Integrations.detected and GL.Integrations.detected.OpenMap and not (GL.db and GL.db.settings.forceWorldMapOverlay) then
    WM.HideAll()
    return
  end
  if not WM.layer then WM.Create() end
  if not WM.layer then return end

  local canvas = getCanvas()
  if not canvas then return end
  local cw, ch = canvas:GetWidth(), canvas:GetHeight()
  if not cw or not ch or cw <= 0 or ch <= 0 then return end

  local okID, shownMapId = pcall(WorldMapFrame.GetMapID or function() return nil end, WorldMapFrame)
  shownMapId = okID and shownMapId or nil
  WM.HideAll()
  if not shownMapId then return end

  -- 1. Draw Herb & Mining nodes for the currently viewed map
  if GL.GatherNodes and (not GL.db or GL.db.settings.showGatherNodes ~= false) then
    local nodes = GL.GatherNodes.GetNodesForMap(shownMapId, MAX_NODES)
    for i = 1, math.min(#nodes, MAX_NODES) do
      local n = nodes[i]
      local dot = WM.nodeDots[i]
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", WM.layer, "TOPLEFT", (n.x / 100) * cw, -(n.y / 100) * ch)
      if n.kind == "HERB" then
        dot:SetColorTexture(0.20, 0.88, 0.35, 0.85) -- emerald green for herbs
      else
        dot:SetColorTexture(0.95, 0.62, 0.22, 0.85) -- copper/gold for mining veins
      end
      dot:Show()
    end
  end

  -- 2. Draw Active Quest Target Pin + Guide Trail Dots if viewing the target's map
  local tgt = WM.target
  if not tgt or tgt.mapId ~= shownMapId then return end

  local tx = (tgt.x / 100) * cw
  local ty = -(tgt.y / 100) * ch
  if WM.questPin then
    WM.questPin:ClearAllPoints()
    WM.questPin:SetPoint("CENTER", WM.layer, "TOPLEFT", tx, ty)
    if tgt.kind == "TURNIN" then
      WM.questPin.tex:SetColorTexture(0.20, 0.92, 0.48, 0.95)
    elseif tgt.kind == "PICKUP" then
      WM.questPin.tex:SetColorTexture(0.96, 0.78, 0.26, 0.95)
    else
      WM.questPin.tex:SetColorTexture(0.38, 0.72, 1.0, 0.95)
    end
    WM.questPin:Show()
  end

  -- Draw breadcrumb trail from player -> quest target on the World Map
  local pMapId, _, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    pMapId, _, px, py = GL.Compat.ReadPosition()
  end
  if pMapId == shownMapId and px and py then
    local sx = (px / 100) * cw
    local sy = -(py / 100) * ch
    for i = 1, NUM_TRAIL do
      local frac = i / (NUM_TRAIL + 1)
      local d = WM.trailDots[i]
      d:ClearAllPoints()
      d:SetPoint("CENTER", WM.layer, "TOPLEFT", sx + (tx - sx) * frac, sy + (ty - sy) * frac)
      d:SetColorTexture(0.96, 0.80, 0.28, 0.40 + 0.50 * frac)
      d:Show()
    end
  end
end
