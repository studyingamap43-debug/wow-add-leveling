-- LevelGuide Theme: modern flat dark-gold, midnight slate, and classic parchment skins.
-- Pure Texture/Backdrop styling (zero external art dependencies, crisp 1px borders).

local GL = LevelGuide
local Th = {}
GL.Theme = Th

Th.FLAT_BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8X8",
  edgeFile = "Interface\\Buttons\\WHITE8X8",
  tile = false, edgeSize = 1,
  insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

Th.THEMES = {
  ["DarkGold"] = {
    label = "Forever Dark-Gold",
    bg = { 0.06, 0.07, 0.09, 0.94 },
    headerBg = { 0.09, 0.11, 0.14, 0.98 },
    cardBg = { 0.10, 0.12, 0.16, 0.85 },
    border = { 0.78, 0.62, 0.25, 0.85 },
    btnBg = { 0.14, 0.17, 0.22, 0.95 },
    btnHover = { 0.22, 0.26, 0.34, 1.0 },
    accent = { 0.94, 0.76, 0.32, 1.0 },
    barFill = { 0.22, 0.74, 0.48, 1.0 },
    barTrack = { 0.12, 0.14, 0.18, 0.9 },
  },
  ["Midnight"] = {
    label = "Midnight Slate",
    bg = { 0.05, 0.06, 0.10, 0.94 },
    headerBg = { 0.08, 0.10, 0.17, 0.98 },
    cardBg = { 0.09, 0.11, 0.18, 0.85 },
    border = { 0.30, 0.55, 0.90, 0.80 },
    btnBg = { 0.12, 0.15, 0.24, 0.95 },
    btnHover = { 0.20, 0.26, 0.40, 1.0 },
    accent = { 0.45, 0.75, 1.0, 1.0 },
    barFill = { 0.32, 0.62, 0.96, 1.0 },
    barTrack = { 0.10, 0.12, 0.19, 0.9 },
  },
  ["Parchment"] = {
    label = "Warm Obsidian",
    bg = { 0.10, 0.08, 0.07, 0.94 },
    headerBg = { 0.15, 0.12, 0.09, 0.98 },
    cardBg = { 0.14, 0.11, 0.09, 0.85 },
    border = { 0.72, 0.52, 0.30, 0.85 },
    btnBg = { 0.20, 0.16, 0.12, 0.95 },
    btnHover = { 0.30, 0.23, 0.17, 1.0 },
    accent = { 0.95, 0.78, 0.46, 1.0 },
    barFill = { 0.82, 0.58, 0.22, 1.0 },
    barTrack = { 0.14, 0.11, 0.09, 0.9 },
  },
}

Th.ORDER = { "DarkGold", "Midnight", "Parchment" }

function Th.GetActive()
  local key = (GL.db and GL.db.settings and GL.db.settings.theme) or "DarkGold"
  return Th.THEMES[key] or Th.THEMES["DarkGold"], key
end

function Th.StyleFrame(f, isCard)
  local t = Th.GetActive()
  GL.Try(f, "SetBackdrop", Th.FLAT_BACKDROP)
  local bg = isCard and t.cardBg or t.bg
  GL.Try(f, "SetBackdropColor", bg[1], bg[2], bg[3], bg[4])
  GL.Try(f, "SetBackdropBorderColor", t.border[1], t.border[2], t.border[3], t.border[4])
end

function Th.CreateFlatButton(parent, text, w, h)
  local t = Th.GetActive()
  local b = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  b:SetSize(w, h)
  GL.Try(b, "SetBackdrop", Th.FLAT_BACKDROP)
  GL.Try(b, "SetBackdropColor", t.btnBg[1], t.btnBg[2], t.btnBg[3], t.btnBg[4])
  GL.Try(b, "SetBackdropBorderColor", t.border[1], t.border[2], t.border[3], 0.45)

  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("CENTER", 0, 0)
  fs:SetText(text)
  b.label = fs

  function b:SetText(txt) fs:SetText(txt) end
  function b:GetText() return fs:GetText() end

  b:SetScript("OnEnter", function(self)
    local cur = Th.GetActive()
    GL.Try(self, "SetBackdropColor", cur.btnHover[1], cur.btnHover[2], cur.btnHover[3], cur.btnHover[4])
    GL.Try(self, "SetBackdropBorderColor", cur.accent[1], cur.accent[2], cur.accent[3], 0.9)
  end)
  b:SetScript("OnLeave", function(self)
    local cur = Th.GetActive()
    GL.Try(self, "SetBackdropColor", cur.btnBg[1], cur.btnBg[2], cur.btnBg[3], cur.btnBg[4])
    GL.Try(self, "SetBackdropBorderColor", cur.border[1], cur.border[2], cur.border[3], 0.45)
  end)

  return b
end
