-- LevelGuide Arrow: smooth 60fps directional questing arrow (TomTom / RestedXP / Questie caliber).
-- Features: exact WoW facing math, real yard distance via C_Map.GetMapWorldSize, live ETA from
-- GetUnitSpeed, dynamic alignment color (green/gold/red/cross-zone blue), arrival chime,
-- click-through combat safety, and Shift+Drag positioning saved per character.

local GL = LevelGuide
local A = {}
GL.Arrow = A

A.frame = nil
A.target = nil     -- { mapId, zoneName, x_0_100, y_0_100, title, sub }
A.arrivedKey = nil
A.accum = 0
local TWO_PI = math.pi * 2
local UPDATE_HZ = 0.03 -- ~33fps smooth rotation with negligible CPU

local function normalizeAngle(rad)
  while rad > math.pi do rad = rad - TWO_PI end
  while rad < -math.pi do rad = rad + TWO_PI end
  return rad
end

local function formatETA(yards)
  if not yards or yards <= 0 then return "" end
  local curSpd, runSpd = nil, nil
  if GL.Compat and GL.Compat.PlayerSpeed then
    curSpd, runSpd = GL.Compat.PlayerSpeed()
  end
  local spd = (curSpd and curSpd > 0.5) and curSpd or ((runSpd and runSpd > 0.5) and runSpd or nil)
  if not spd then return "" end -- never fabricate an ETA when speed is unavailable or secret
  local sec = math.floor((yards / spd) + 0.5)
  if sec >= 3600 then return ">1h" end
  local m = math.floor(sec / 60)
  local s = sec % 60
  return string.format("%d:%02d", m, s)
end

function A.Create()
  if A.frame or not CreateFrame then return A.frame end
  local f = CreateFrame("Frame", "LevelGuideArrowFrame", UIParent)
  f:SetSize(160, 96)
  f:SetPoint("TOP", UIParent, "TOP", 0, -110)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)

  -- Subtle dark pill behind text for high readability over bright terrain (snow/sand)
  local pill = f:CreateTexture(nil, "BACKGROUND")
  pill:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 2)
  pill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 2)
  pill:SetHeight(34)
  pill:SetColorTexture(0.05, 0.06, 0.09, 0.72)
  f.pill = pill

  -- Built-in crisp directional arrow texture (points North/UP at 0 rad)
  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetSize(48, 48)
  tex:SetPoint("TOP", f, "TOP", 0, -4)
  tex:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.tex = tex

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  title:SetPoint("TOP", tex, "BOTTOM", 0, -4)
  title:SetWidth(156)
  title:SetJustifyH("CENTER")
  title:SetText("")
  f.title = title

  local distTxt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  distTxt:SetPoint("TOP", title, "BOTTOM", 0, -1)
  distTxt:SetWidth(156)
  distTxt:SetJustifyH("CENTER")
  distTxt:SetText("")
  f.distTxt = distTxt

  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if IsShiftKeyDown and IsShiftKeyDown() and not (GL.Compat and GL.Compat.InCombat()) then
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if GL.db then
      GL.db.ui = type(GL.db.ui) == "table" and GL.db.ui or {}
      local p, _, rp, x, y = self:GetPoint()
      GL.db.ui.arrowPos = { p = p, rp = rp, x = x, y = y }
    end
  end)

  f:SetScript("OnUpdate", function(_, elapsed)
    A.accum = A.accum + (elapsed or 0)
    if A.accum < UPDATE_HZ then return end
    A.accum = 0
    GL.Safe("Arrow.Update", A.UpdateFrame)
  end)

  A.frame = f
  A.RestorePos()
  A.ApplyMouseLock()
  A.ApplyScale()
  f:Hide()
  return f
end

function A.RestorePos()
  if not A.frame or not GL.db or not GL.db.ui or type(GL.db.ui.arrowPos) ~= "table" then return end
  local pos = GL.db.ui.arrowPos
  if pos.p then
    A.frame:ClearAllPoints()
    A.frame:SetPoint(pos.p, UIParent, pos.rp or pos.p, pos.x or 0, pos.y or -110)
  end
end

function A.ResetPos()
  if not A.frame then return end
  if GL.db and GL.db.ui then GL.db.ui.arrowPos = nil end
  A.frame:ClearAllPoints()
  A.frame:SetPoint("TOP", UIParent, "TOP", 0, -110)
end

-- Click-through when locked so right-click attacking / camera turning is never blocked
function A.ApplyScale()
  if not A.frame then return end
  local sc = (GL.db and GL.db.settings and tonumber(GL.db.settings.arrowScale)) or 1.0
  A.frame:SetScale(math.max(0.6, math.min(1.6, sc)))
  if A.frame.pill and GL.Theme then
    local t = GL.Theme.GetActive()
    A.frame.pill:SetColorTexture(t.bg[1], t.bg[2], t.bg[3], 0.80)
  end
end

function A.ApplyMouseLock()
  if not A.frame then return end
  local locked = GL.db and GL.db.settings and GL.db.settings.arrowLocked
  A.frame:EnableMouse(not locked)
end

function A.SetTarget(mapId, zoneName, x, y, title, sub)
  if not x or not y then
    A.Clear()
    return
  end
  if not A.frame then A.Create() end
  A.target = {
    mapId = mapId,
    zoneName = zoneName or "?",
    x = x,
    y = y,
    title = title or "Quest Target",
    sub = sub or "",
  }
  local enabled = not (GL.db and GL.db.settings and GL.db.settings.arrowEnabled == false)
  if A.frame and enabled then
    A.frame:Show()
    GL.Safe("Arrow.Update", A.UpdateFrame)
  end
end

function A.Clear()
  A.target = nil
  if A.frame then A.frame:Hide() end
end

function A.UpdateFrame()
  local f, tgt = A.frame, A.target
  if not f or not tgt then return end
  if GL.db and GL.db.settings and GL.db.settings.arrowEnabled == false then
    f:Hide()
    return
  end

  -- Hide cleanly inside instances so dungeon combat stays uncluttered
  if IsInInstance then
    local okI, inInst = pcall(IsInInstance)
    if okI and inInst then f:Hide() return end
  end

  local pMapId, pZone, px, py
  if GL.Compat and GL.Compat.ReadPosition then
    pMapId, pZone, px, py = GL.Compat.ReadPosition()
  end
  local label = tgt.title
  if tgt.sub and tgt.sub ~= "" then label = tgt.sub end
  f.title:SetText(string.sub(tostring(label), 1, 28))

  local sameMap = false
  if tgt.mapId and pMapId then
    if tgt.mapId == pMapId then
      sameMap = true
    elseif GL.Compat and GL.Compat.ReadPositionOnMap then
      local ox, oy = GL.Compat.ReadPositionOnMap(tgt.mapId)
      if ox and oy then
        px, py = ox, oy
        sameMap = true
      end
    end
  elseif (not tgt.mapId or not pMapId) and tgt.zoneName and pZone and string.lower(tgt.zoneName) == string.lower(pZone) then
    sameMap = true
  end

  if not sameMap or not px or not py then
    -- Cross-zone or indoors: steady sky-blue icon + zone direction
    if f.tex.SetRotation then f.tex:SetRotation(0) end
    f.tex:SetVertexColor(0.38, 0.65, 0.98, 1)
    f.distTxt:SetText(string.format("|cff7ec8ff-> %s (%.1f, %.1f)|r", tostring(tgt.zoneName), tgt.x, tgt.y))
    return
  end

  local dx = (tgt.x - px) / 100
  local dy = (tgt.y - py) / 100

  -- Convert normalized map delta to yards using C_Map.GetMapWorldSize when available
  local mapW, mapH = 1500, 1000
  if tgt.mapId and C_Map and C_Map.GetMapWorldSize then
    local okS, w, h = pcall(C_Map.GetMapWorldSize, tgt.mapId)
    if okS and w and h and w > 0 and h > 0 then
      mapW, mapH = w, h
    end
  end
  local ydX = dx * mapW
  local ydY = dy * mapH
  local yards = math.sqrt(ydX * ydX + ydY * ydY)

  -- Target bearing in WoW counter-clockwise-from-North convention:
  -- North (dx=0, dy<0) = 0, West (dx<0) = +pi/2, South (dy>0) = pi, East (dx>0) = -pi/2
  local bearing = math.atan2(-ydX, -ydY)
  local facing = GL.Compat and GL.Compat.PlayerFacing() or nil
  if not facing then
    f.tex:SetVertexColor(0.38, 0.65, 0.98, 1)
    f.distTxt:SetText(string.format("|cffffffff%.0f yd|r", yards))
    return
  end
  local rel = normalizeAngle(bearing - facing)

  if f.tex.SetRotation then
    f.tex:SetRotation(rel)
  end

  local absRel = math.abs(rel)
  if yards <= 12 then
    f.tex:SetVertexColor(0.15, 0.92, 0.48, 1)
    f.distTxt:SetText("|cff33ee77Arrived!|r (" .. string.format("%.0f yd", yards) .. ")")
    local aKey = tostring(tgt.zoneName) .. ":" .. tostring(tgt.x) .. ":" .. tostring(tgt.y)
    if A.arrivedKey ~= aKey then
      A.arrivedKey = aKey
      if GL.Voice then GL.Voice.PlayCue("PING") end
    end
  else
    -- Smooth color feedback: emerald aligned -> warm gold turning -> coral facing away
    if absRel < 0.32 or yards <= 25 then
      f.tex:SetVertexColor(0.15, 0.90, 0.48, 1)
    elseif absRel < 1.30 then
      f.tex:SetVertexColor(0.96, 0.77, 0.26, 1)
    else
      f.tex:SetVertexColor(0.94, 0.32, 0.32, 1)
    end
    local eta = formatETA(yards)
    f.distTxt:SetText(string.format("|cffffffff%.0f yd|r  |cffaaaaaa%s|r", yards, eta))
  end
end
