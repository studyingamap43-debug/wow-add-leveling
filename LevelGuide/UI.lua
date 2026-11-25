-- LevelGuide UI v0.5.0: Modern Dark-Gold / Midnight / Warm Obsidian HUD.
-- Features: faction accent bar, live split timer header, flat hover buttons, underline tab bar,
-- scrollable step card, Mini-Mode HUD, draggable Minimap button, Voice & Theme controls.

local GL = LevelGuide
local UI = {}
GL.UI = UI

local function inCombat()
  return GL.Compat and GL.Compat.InCombat()
end

local function mkbtn(parent, text, w, h)
  if GL.Theme and GL.Theme.CreateFlatButton then
    return GL.Theme.CreateFlatButton(parent, text, w, h)
  end
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, h)
  b:SetText(text)
  return b
end

function UI.CreateMinimapButton()
  if UI.minimapBtn or not Minimap or not CreateFrame then return end
  local b = CreateFrame("Button", "LevelGuideMinimapButton", Minimap)
  b:SetSize(30, 30)
  b:SetFrameStrata("MEDIUM")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetSize(20, 20)
  bg:SetPoint("CENTER")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
  icon:SetSize(18, 18)
  icon:SetPoint("CENTER")

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(52, 52)
  border:SetPoint("TOPLEFT")

  local function updatePos(angle)
    local rad = math.rad(angle or 220)
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
  end

  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then GL.CmdPin() else UI.Toggle() end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      if not mx or not my or not cx or not cy or not scale or scale <= 0 then return end
      local ang = math.deg(math.atan2((cy / scale) - my, (cx / scale) - mx))
      if GL.db and GL.db.ui then GL.db.ui.minimapAngle = ang end
      updatePos(ang)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_LEFT")
      GameTooltip:AddLine("|cfff0c252LevelGuide v" .. tostring(GL.version) .. "|r")
      GameTooltip:AddLine("Left-Click: Toggle HUD", 1, 1, 1)
      GameTooltip:AddLine("Right-Click: Pin Waypoint", 0.5, 0.9, 1)
      GameTooltip:AddLine("Drag: Move around minimap", 0.7, 0.7, 0.7)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  updatePos(GL.db and GL.db.ui and GL.db.ui.minimapAngle or 220)
  if GL.db and GL.db.settings and GL.db.settings.showMinimap == false then b:Hide() end
  UI.minimapBtn = b
end

function UI.ShowBugReport(text, heading)
  if inCombat() then
    GL.Print("Cannot open dialog during combat.")
    return
  end
  if not UI.bugFrame then
    local bf = CreateFrame("Frame", "LevelGuideBugFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    bf:SetSize(540, 350)
    bf:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bf:SetFrameStrata("DIALOG")
    bf:SetMovable(true) bf:EnableMouse(true)
    bf:RegisterForDrag("LeftButton")
    bf:SetScript("OnDragStart", function(s) if not inCombat() then s:StartMoving() end end)
    bf:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    GL.Theme.StyleFrame(bf, false)

    local t = bf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 14, -12)
    bf.titleText = t

    local close = mkbtn(bf, "X", 24, 20)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function() bf:Hide() end)

    local scroll = CreateFrame("ScrollFrame", "LevelGuideBugScroll", bf, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -40)
    scroll:SetPoint("BOTTOMRIGHT", -34, 42)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetFontObject("ChatFontNormal")
    eb:SetWidth(475)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function() bf:Hide() end)
    scroll:SetScrollChild(eb)
    bf.eb = eb

    local sel = mkbtn(bf, "Select All", 100, 22)
    sel:SetPoint("BOTTOMRIGHT", -14, 12)
    sel:SetScript("OnClick", function() eb:SetFocus() eb:HighlightText() end)

    local clr = mkbtn(bf, "Clear Errors", 100, 22)
    clr:SetPoint("BOTTOMLEFT", 14, 12)
    clr:SetScript("OnClick", function()
      GL.errors = {}
      eb:SetText(GL.BuildDiagnosticString())
    end)

    UI.bugFrame = bf
  end
  GL.Theme.StyleFrame(UI.bugFrame, false)
  UI.bugFrame.titleText:SetText(heading or "LevelGuide — Copyable Report (Ctrl+C)")
  UI.bugFrame.eb:SetText(text or GL.BuildDiagnosticString())
  UI.bugFrame:Show()
  UI.bugFrame.eb:SetFocus()
  UI.bugFrame.eb:HighlightText()
end

function UI.ShowWizard()
  if inCombat() or not GL.db or GL.db.setupDone then return end
  if UI.wizFrame then UI.wizFrame:Show() return end

  local wf = CreateFrame("Frame", "LevelGuideWizard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  wf:SetSize(360, 220)
  wf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  wf:SetFrameStrata("DIALOG")
  wf:SetMovable(true) wf:EnableMouse(true)
  wf:RegisterForDrag("LeftButton")
  wf:SetScript("OnDragStart", function(s) if not inCombat() then s:StartMoving() end end)
  wf:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
  GL.Theme.StyleFrame(wf, false)

  local title = wf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -14)
  title:SetText("|cfff0c252LevelGuide — Character Setup|r")

  local info = wf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", 16, -42)
  info:SetWidth(328)
  info:SetJustifyH("LEFT")
  info:SetText("Detected: |cff33ff99" .. tostring(GL.profile and GL.profile.key or "?") .. "|r\nIsolated per character — other factions/races/classes never load.")

  local b1 = mkbtn(wf, "Thorough (Default)", 150, 24)
  b1:SetPoint("TOPLEFT", 16, -92)
  b1:SetScript("OnClick", function() GL.CmdMode("thorough") end)

  local b2 = mkbtn(wf, "Speed Mode", 150, 24)
  b2:SetPoint("TOPRIGHT", -16, -92)
  b2:SetScript("OnClick", function() GL.CmdMode("speed") end)

  local vBtn = mkbtn(wf, "Voice Guidance: ON", 328, 24)
  vBtn:SetPoint("TOPLEFT", 16, -124)
  vBtn:SetScript("OnClick", function(self)
    if not GL.db then return end
    GL.db.settings.voiceEnabled = not GL.db.settings.voiceEnabled
    self:SetText("Voice Guidance: " .. (GL.db.settings.voiceEnabled and "ON (TTS)" or "OFF"))
    if GL.db.settings.voiceEnabled and GL.Voice then GL.Voice.Speak("Voice guidance enabled.", true) end
  end)

  local go = mkbtn(wf, "Start LevelGuide", 180, 26)
  go:SetPoint("BOTTOM", 0, 14)
  go:SetScript("OnClick", function()
    if GL.db then GL.db.setupDone = true end
    wf:Hide()
    UI.Create():Show()
    GL.Refresh()
  end)

  UI.wizFrame = wf
end

function UI.ApplyTheme()
  local f = UI.frame
  if not f or not GL.Theme then return end
  local t = GL.Theme.GetActive()
  GL.Theme.StyleFrame(f, false)
  if f.headerBg then f.headerBg:SetColorTexture(t.headerBg[1], t.headerBg[2], t.headerBg[3], t.headerBg[4]) end
  if f.card then GL.Theme.StyleFrame(f.card, true) end
  if f.bar then f.bar:SetStatusBarColor(t.barFill[1], t.barFill[2], t.barFill[3], t.barFill[4]) end
  if f.barTrack then f.barTrack:SetColorTexture(t.barTrack[1], t.barTrack[2], t.barTrack[3], t.barTrack[4]) end
  if f.factionStripe then
    local fac = GL.profile and GL.profile.faction
    if fac == "Alliance" then f.factionStripe:SetColorTexture(0.23, 0.51, 0.96, 1)
    elseif fac == "Horde" then f.factionStripe:SetColorTexture(0.86, 0.15, 0.15, 1)
    else f.factionStripe:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 1) end
  end
end

function UI.UpdateTimerText()
  if not UI.frame or not UI.frame.timerText or not GL.Timer then return end
  local lv = (UnitLevel and UnitLevel("player")) or 1
  UI.frame.timerText:SetText("|cfff0c252" .. GL.Timer.GetHeaderText(lv) .. "|r")
end

function UI.ApplyFontSize()
  local f = UI.frame
  if not f then return end
  local sz = (GL.db and GL.db.settings and tonumber(GL.db.settings.fontSize)) or 12
  local function setFS(fs, size)
    if fs and fs.GetFont and fs.SetFont then
      local ok, fontPath, _, flags = pcall(fs.GetFont, fs)
      if ok and fontPath then pcall(fs.SetFont, fs, fontPath, size, flags or "") end
    end
  end
  setFS(f.header, sz + 1)
  setFS(f.body, sz)
  setFS(f.prevText, math.max(10, sz - 1))
  setFS(f.nextText, math.max(10, sz - 1))
  setFS(f.miniLine, sz)
end

function UI.ApplyVisualSettings()
  local f = UI.frame
  if not f or not GL.db then return end
  local s = GL.db.settings
  f:SetAlpha(tonumber(s.opacity) or 1.0)
  UI.ApplyTheme()
  UI.ApplyFontSize()
  if UI.minimapBtn then
    if s.showMinimap == false then UI.minimapBtn:Hide() else UI.minimapBtn:Show() end
  end
  if f.miniBtn then f.miniBtn:SetText(s.miniMode and "[+]" or "[-]") end
  if s.miniMode then
    if not inCombat() then f:SetHeight(108) end
    for _, b in pairs(f.tabs) do b:Hide() end
    if f.card then f.card:Hide() end
    if f.prevText then f.prevText:Hide() end
    if f.nextText then f.nextText:Hide() end
    if f.skip then f.skip:Hide() end
    if f.ignoreBtn then f.ignoreBtn:Hide() end
    if f.pin then f.pin:Hide() end
    if f.resyncBtn then f.resyncBtn:Hide() end
    if f.speakBtn then f.speakBtn:Hide() end
    if f.chainBtn then f.chainBtn:Hide() end
    if f.mapBtn then f.mapBtn:Hide() end
    if f.prevBtn then f.prevBtn:Hide() end
    if f.splitsBtn then f.splitsBtn:Hide() end
    if f.bugBtn then f.bugBtn:Hide() end
    if f.miniLine then f.miniLine:Show() end
  else
    if not inCombat() and GL.db.ui and GL.db.ui.h and GL.db.ui.h > 180 then
      f:SetHeight(GL.db.ui.h)
    elseif not inCombat() and f:GetHeight() < 200 then
      f:SetHeight(345)
    end
    for _, b in pairs(f.tabs) do b:Show() end
    if f.miniLine then f.miniLine:Hide() end
    UI.ShowTab(UI.tab or "Guide")
  end
end

function UI.Create()
  if UI.frame then return UI.frame end
  local f = CreateFrame("Frame", "LevelGuideFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  UI.frame = f
  f:SetWidth(480) f:SetHeight(345)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true) f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(470, 108, 760, 660) end
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(s)
    if not inCombat() and not (GL.db and GL.db.settings.locked) then s:StartMoving() end
  end)
  f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() UI.SavePos() end)

  -- Top faction accent stripe (2px)
  local stripe = f:CreateTexture(nil, "OVERLAY")
  stripe:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  stripe:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
  stripe:SetHeight(2)
  f.factionStripe = stripe

  -- Header bar background
  local hbg = f:CreateTexture(nil, "ARTWORK")
  hbg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
  hbg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
  hbg:SetHeight(26)
  f.headerBg = hbg

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -9)
  f.title:SetText("|cfff0c252LevelGuide|r |cff888888v" .. tostring(GL.version) .. "|r")

  -- Live Timer pill in header (click to pause/resume)
  local tBtn = CreateFrame("Button", nil, f)
  tBtn:SetSize(155, 18)
  tBtn:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
  local tTxt = tBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tTxt:SetPoint("LEFT", 0, 0)
  tTxt:SetText("|cfff0c25200:00  |  Lv1 00:00|r")
  tBtn:SetScript("OnClick", function() GL.CmdTimer("toggle") end)
  f.timerText = tTxt

  -- Compact header controls: Mini | Voice | Close
  f.close = mkbtn(f, "X", 22, 18)
  f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
  f.close:SetScript("OnClick", function() if not inCombat() then UI.frame:Hide() UI.SavePos() end end)

  f.voiceToggle = mkbtn(f, "TTS", 34, 18)
  f.voiceToggle:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
  f.voiceToggle:SetScript("OnClick", function() GL.CmdVoice("toggle") end)

  f.miniBtn = mkbtn(f, "[-]", 26, 18)
  f.miniBtn:SetPoint("RIGHT", f.voiceToggle, "LEFT", -4, 0)
  f.miniBtn:SetScript("OnClick", function() GL.CmdMini() end)

  f.scanBtn = mkbtn(f, "Scan", 38, 18)
  f.scanBtn:SetPoint("RIGHT", f.miniBtn, "LEFT", -4, 0)
  f.scanBtn:SetScript("OnClick", function() GL.CmdScan() end)

  f.paceBtn = mkbtn(f, "Pace", 38, 18)
  f.paceBtn:SetPoint("RIGHT", f.scanBtn, "LEFT", -4, 0)
  f.paceBtn:SetScript("OnClick", function() GL.CmdPace() end)

  -- Mini-mode single-line display
  f.miniLine = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.miniLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
  f.miniLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)
  f.miniLine:SetJustifyH("LEFT")
  f.miniLine:Hide()

  -- Modern underline tab bar
  f.tabs = {}
  local names = { "Guide", "Dungeons", "Grinding", "Profs", "Twink", "Settings", "Log" }
  for i, nm in ipairs(names) do
    local b = mkbtn(f, nm, 62, 20)
    b:SetPoint("TOPLEFT", f, "TOPLEFT", 10 + (i - 1) * 65, -34)
    b.tabname = nm
    local line = b:CreateTexture(nil, "OVERLAY")
    line:SetPoint("BOTTOMLEFT", 2, 1)
    line:SetPoint("BOTTOMRIGHT", -2, 1)
    line:SetHeight(2)
    line:SetColorTexture(0.94, 0.76, 0.32, 1)
    line:Hide()
    b.underline = line
    b:SetScript("OnClick", function(s) UI.ShowTab(s.tabname) end)
    f.tabs[nm] = b
  end

  -- Structured Step / Content Card
  local card = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  card:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
  card:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 96)
  f.card = card

  f.header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.header:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
  f.header:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, -8)
  f.header:SetJustifyH("LEFT")

  -- Professions cycle button inside card top
  f.profCycle = mkbtn(card, "Profession: First Aid", 190, 20)
  f.profCycle:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -6)
  f.profCycle:SetScript("OnClick", function()
    if not GL.db or not GL.Fallback then return end
    local ord = GL.Fallback.PROF_ORDER
    local cur = GL.db.settings.prof1 or ord[1]
    local nxt = ord[1]
    for i = 1, #ord do
      if ord[i] == cur then nxt = ord[(i % #ord) + 1] break end
    end
    GL.db.settings.prof1 = nxt
    UI.Update()
  end)

  local scroll = CreateFrame("ScrollFrame", "LevelGuideContentScroll", card, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -30)
  scroll:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -28, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(375, 520)
  scroll:SetScrollChild(content)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local cur = self:GetVerticalScroll() or 0
    local maxS = self:GetVerticalScrollRange() or 0
    local nxt = math.max(0, math.min(maxS, cur - (delta * 28)))
    self:SetVerticalScroll(nxt)
  end)
  f.scroll = scroll
  f.scrollContent = content

  -- Interactive step checkboxes (up to 6 clickable walkthrough rows with real visual boxes)
  f.stepChecks = {}
  for i = 1, 6 do
    local cb = CreateFrame("Button", nil, content)
    cb:SetHeight(20)
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((i - 1) * 21))
    cb:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -((i - 1) * 21))
    local hl = cb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(cb)
    hl:SetColorTexture(1, 0.85, 0.35, 0.08)

    local box = CreateFrame("Frame", nil, cb)
    box:SetSize(14, 14)
    box:SetPoint("LEFT", cb, "LEFT", 1, 0)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints(box)
    boxBg:SetColorTexture(0.08, 0.08, 0.10, 0.95)
    local bTop = box:CreateTexture(nil, "BORDER")
    bTop:SetPoint("TOPLEFT", 0, 0) bTop:SetPoint("TOPRIGHT", 0, 0) bTop:SetHeight(1)
    local bBot = box:CreateTexture(nil, "BORDER")
    bBot:SetPoint("BOTTOMLEFT", 0, 0) bBot:SetPoint("BOTTOMRIGHT", 0, 0) bBot:SetHeight(1)
    local bLeft = box:CreateTexture(nil, "BORDER")
    bLeft:SetPoint("TOPLEFT", 0, 0) bLeft:SetPoint("BOTTOMLEFT", 0, 0) bLeft:SetWidth(1)
    local bRight = box:CreateTexture(nil, "BORDER")
    bRight:SetPoint("TOPRIGHT", 0, 0) bRight:SetPoint("BOTTOMRIGHT", 0, 0) bRight:SetWidth(1)
    local checkTex = box:CreateTexture(nil, "OVERLAY")
    checkTex:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
    checkTex:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
    checkTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checkTex:Hide()
    cb.boxBorders = { bTop, bBot, bLeft, bRight }
    cb.checkTex = checkTex

    local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", box, "RIGHT", 6, 0)
    fs:SetPoint("RIGHT", cb, "RIGHT", 0, 0)
    fs:SetJustifyH("LEFT")
    cb.text = fs
    cb.rowIdx = i
    cb:SetScript("OnClick", function(self)
      if not GL.db or not UI.currentStepKey then return end
      GL.db.stepChecks = type(GL.db.stepChecks) == "table" and GL.db.stepChecks or {}
      GL.db.stepChecks[UI.currentStepKey] = type(GL.db.stepChecks[UI.currentStepKey]) == "table" and GL.db.stepChecks[UI.currentStepKey] or {}
      local stbl = GL.db.stepChecks[UI.currentStepKey]
      stbl[self.rowIdx] = not stbl[self.rowIdx]
      -- Stamp last-used time so pruning drops the oldest steps, not arbitrary pairs() order.
      stbl._ts = (tonumber(GL.db.stepCheckClock) or 0) + 1
      GL.db.stepCheckClock = stbl._ts
      local keys, nKeys = {}, 0
      for k, v in pairs(GL.db.stepChecks) do
        nKeys = nKeys + 1
        keys[nKeys] = { k = k, ts = (type(v) == "table" and tonumber(v._ts)) or 0 }
      end
      if nKeys > 50 then
        table.sort(keys, function(a, b) return a.ts < b.ts end)
        local left = nKeys
        for ki = 1, #keys do
          if left <= 40 then break end
          if keys[ki].k ~= UI.currentStepKey then
            GL.db.stepChecks[keys[ki].k] = nil
            left = left - 1
          end
        end
      end
      UI.Update()
    end)
    cb:SetScript("OnEnter", function(self)
      if GameTooltip then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("LevelGuide Step", 0.94, 0.76, 0.32)
        GameTooltip:AddLine("Click to check/uncheck this step.", 1, 1, 1)
        if UI.step and UI.step.unverified then
          GameTooltip:AddLine("Status: UNVERIFIED (Forever 1.60.1 class quest/NPC not live-confirmed)", 1, 0.55, 0.25)
        else
          local srcTag = (GL.data and GL.data.tag) or "UNVERIFIED"
          GameTooltip:AddLine("Status: " .. tostring(srcTag) .. " (verify in live 1.60.1 client)", 1, 0.68, 0.25)
        end
        GameTooltip:Show()
      end
    end)
    cb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    cb:Hide()
    f.stepChecks[i] = cb
  end

  f.body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  f.body:SetJustifyH("LEFT") f.body:SetJustifyV("TOP")
  f.body:SetSpacing(3)
  f.body:SetWidth(370)

  -- Previous step strip
  f.prevText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.prevText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 78)
  f.prevText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 78)
  f.prevText:SetJustifyH("LEFT")

  -- Next step preview strip
  f.nextText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.nextText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 60)
  f.nextText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 60)
  f.nextText:SetJustifyH("LEFT")

  -- Sleek Progress Bar with background track
  local barTrack = f:CreateTexture(nil, "BACKGROUND")
  barTrack:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 38)
  barTrack:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 38)
  barTrack:SetHeight(14)
  f.barTrack = barTrack

  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetPoint("TOPLEFT", barTrack, "TOPLEFT", 1, -1)
  f.bar:SetPoint("BOTTOMRIGHT", barTrack, "BOTTOMRIGHT", -1, 1)
  f.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
  f.bar:SetMinMaxValues(0, 1) f.bar:SetValue(0)

  f.barText = f.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.barText:SetPoint("CENTER", 0, 0)

  -- Bottom Guide action bar
  f.skip = mkbtn(f, "Skip", 38, 22)
  f.skip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.skip:SetScript("OnClick", function() GL.CmdSkip() end)

  f.ignoreBtn = mkbtn(f, "Ignore", 46, 22)
  f.ignoreBtn:SetPoint("LEFT", f.skip, "RIGHT", 3, 0)
  f.ignoreBtn:SetScript("OnClick", function() GL.CmdIgnore() end)

  f.pin = mkbtn(f, "Pin", 34, 22)
  f.pin:SetPoint("LEFT", f.ignoreBtn, "RIGHT", 3, 0)
  f.pin:SetScript("OnClick", function() GL.CmdPin() end)

  f.resyncBtn = mkbtn(f, "Sync", 38, 22)
  f.resyncBtn:SetPoint("LEFT", f.pin, "RIGHT", 3, 0)
  f.resyncBtn:SetScript("OnClick", function() GL.CmdRecalibrate() end)

  f.speakBtn = mkbtn(f, "TTS", 34, 22)
  f.speakBtn:SetPoint("LEFT", f.resyncBtn, "RIGHT", 3, 0)
  f.speakBtn:SetScript("OnClick", function() GL.CmdSpeak() end)

  f.chainBtn = mkbtn(f, "Chain", 42, 22)
  f.chainBtn:SetPoint("LEFT", f.speakBtn, "RIGHT", 3, 0)
  f.chainBtn:SetScript("OnClick", function() GL.CmdChain() end)

  f.mapBtn = mkbtn(f, "Map", 34, 22)
  f.mapBtn:SetPoint("LEFT", f.chainBtn, "RIGHT", 3, 0)
  f.mapBtn:SetScript("OnClick", function() GL.CmdMap() end)

  f.prevBtn = mkbtn(f, "Prev", 36, 22)
  f.prevBtn:SetPoint("LEFT", f.mapBtn, "RIGHT", 3, 0)
  f.prevBtn:SetScript("OnClick", function() GL.CmdBack() end)

  f.splitsBtn = mkbtn(f, "Splits", 42, 22)
  f.splitsBtn:SetPoint("LEFT", f.prevBtn, "RIGHT", 3, 0)
  f.splitsBtn:SetScript("OnClick", function() GL.CmdSplits() end)

  f.bugBtn = mkbtn(f, "Bug", 36, 22)
  f.bugBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 10)
  f.bugBtn:SetScript("OnClick", function() UI.ShowBugReport(GL.BuildDiagnosticString()) end)

  -- Settings panel (2 clean columns)
  f.modeBtn = mkbtn(f, "Mode", 195, 22)
  f.modeBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -62)
  f.modeBtn:SetScript("OnClick", function() GL.CmdMode() end)

  f.pinBtn = mkbtn(f, "Auto-Pin", 195, 22)
  f.pinBtn:SetPoint("TOPLEFT", f.modeBtn, "BOTTOMLEFT", 0, -6)
  f.pinBtn:SetScript("OnClick", function() GL.CmdArrow() end)

  f.voiceBtn = mkbtn(f, "Voice TTS", 195, 22)
  f.voiceBtn:SetPoint("TOPLEFT", f.pinBtn, "BOTTOMLEFT", 0, -6)
  f.voiceBtn:SetScript("OnClick", function() GL.CmdVoice("toggle") end)

  f.voiceCycleBtn = mkbtn(f, "Cycle OS Voice", 195, 22)
  f.voiceCycleBtn:SetPoint("TOPLEFT", f.voiceBtn, "BOTTOMLEFT", 0, -6)
  f.voiceCycleBtn:SetScript("OnClick", function() if GL.Voice then GL.Voice.CycleVoice() UI.Update() end end)

  f.discBtn = mkbtn(f, "Forever Discoveries", 195, 22)
  f.discBtn:SetPoint("TOPLEFT", f.voiceCycleBtn, "BOTTOMLEFT", 0, -6)
  f.discBtn:SetScript("OnClick", function() GL.CmdDiscoveries() end)

  f.themeBtn = mkbtn(f, "Theme", 195, 22)
  f.themeBtn:SetPoint("LEFT", f.modeBtn, "RIGHT", 10, 0)
  f.themeBtn:SetScript("OnClick", function() GL.CmdTheme() end)

  f.lockBtn = mkbtn(f, "Lock Window", 195, 22)
  f.lockBtn:SetPoint("TOPLEFT", f.themeBtn, "BOTTOMLEFT", 0, -6)
  f.lockBtn:SetScript("OnClick", function() GL.CmdLock() end)

  f.opacityBtn = mkbtn(f, "Opacity", 195, 22)
  f.opacityBtn:SetPoint("TOPLEFT", f.lockBtn, "BOTTOMLEFT", 0, -6)
  f.opacityBtn:SetScript("OnClick", function()
    if not GL.db then return end
    local vals = { 1.0, 0.85, 0.7, 0.5 }
    local cur = GL.db.settings.opacity or 1.0
    local nxt = vals[1]
    for i = 1, #vals do
      if math.abs(vals[i] - cur) < 0.05 then nxt = vals[(i % #vals) + 1] break end
    end
    GL.db.settings.opacity = nxt
    UI.ApplyVisualSettings()
    UI.Update()
  end)

  f.syncBtn = mkbtn(f, "Sync Quests from Server", 195, 22)
  f.syncBtn:SetPoint("TOPLEFT", f.opacityBtn, "BOTTOMLEFT", 0, -6)
  f.syncBtn:SetScript("OnClick", function() GL.CmdSync() end)

  f.resetBtn = mkbtn(f, "Reset Character Progress", 195, 22)
  f.resetBtn:SetPoint("TOPLEFT", f.syncBtn, "BOTTOMLEFT", 0, -6)
  f.resetBtn:SetScript("OnClick", function() GL.CmdReset() end)

  f.profileText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.fontBtn = mkbtn(f, "Font Size", 195, 22)
  f.fontBtn:SetPoint("TOPLEFT", f.discBtn, "BOTTOMLEFT", 0, -6)
  f.fontBtn:SetScript("OnClick", function() GL.CmdFont() end)

  f.clusterBtn = mkbtn(f, "Cluster Route", 195, 22)
  f.clusterBtn:SetPoint("TOPLEFT", f.resetBtn, "BOTTOMLEFT", 0, -6)
  f.clusterBtn:SetScript("OnClick", function() GL.CmdCluster() end)

  f.profileText:SetPoint("TOPLEFT", f.fontBtn, "BOTTOMLEFT", 0, -10)
  f.profileText:SetWidth(405)
  f.profileText:SetJustifyH("LEFT")

  -- Log tab
  f.log = CreateFrame("ScrollingMessageFrame", nil, f)
  f.log:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -62)
  f.log:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 42)
  GL.Try(f.log, "SetFontObject", GameFontNormalSmall)
  GL.Try(f.log, "SetJustifyH", "LEFT")
  GL.Try(f.log, "SetMaxLines", 120)
  GL.Try(f.log, "SetFading", false)

  f.copyLogBtn = mkbtn(f, "Copy Diagnostic String", 170, 22)
  f.copyLogBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 10)
  f.copyLogBtn:SetScript("OnClick", function() UI.ShowBugReport(GL.BuildDiagnosticString()) end)

  -- Resize grip
  f.grip = CreateFrame("Button", nil, f)
  f.grip:SetWidth(16) f.grip:SetHeight(16)
  f.grip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
  f.grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  f.grip:SetScript("OnMouseDown", function(s)
    if not inCombat() and not (GL.db and GL.db.settings.locked) then s:GetParent():StartSizing("BOTTOMRIGHT") end
  end)
  f.grip:SetScript("OnMouseUp", function(s) s:GetParent():StopMovingOrSizing() UI.SavePos() end)
  f:SetScript("OnSizeChanged", function()
    if UI.frame and UI.frame.body then
      local w = math.max(160, UI.frame:GetWidth() - 62)
      UI.frame.body:SetWidth(w)
      if UI.frame.scrollContent then UI.frame.scrollContent:SetWidth(w) end
    end
  end)

  UI.tab = "Guide"
  UI.ShowTab("Guide")
  UI.RestorePos()
  UI.CreateMinimapButton()
  UI.ApplyVisualSettings()
  return f
end

function UI.SavePos()
  local f = UI.frame
  if not f or not LevelGuideDB then return end
  local p, _, rp, x, y = f:GetPoint()
  local prevAngle = LevelGuideDB.ui and LevelGuideDB.ui.minimapAngle or 220
  local h = (GL.db and GL.db.settings.miniMode and LevelGuideDB.ui and LevelGuideDB.ui.h) or f:GetHeight()
  LevelGuideDB.ui = { p = p, rp = rp, x = x, y = y, w = f:GetWidth(), h = h, hidden = not f:IsVisible(), minimapAngle = prevAngle }
end

function UI.RestorePos()
  local f, u = UI.frame, LevelGuideDB and LevelGuideDB.ui
  if not f or type(u) ~= "table" or not u.p then return end
  f:ClearAllPoints()
  f:SetPoint(u.p, UIParent, u.rp or u.p, u.x or 0, u.y or 0)
  if u.w and u.h then f:SetWidth(u.w) f:SetHeight(u.h) end
  if u.hidden then f:Hide() end
end

function UI.ShowTab(name)
  local f = UI.frame
  if not f then return end
  UI.tab = name
  for nm, btn in pairs(f.tabs) do
    if btn.underline then
      if nm == name then btn.underline:Show() else btn.underline:Hide() end
    end
  end
  local g = (name == "Guide")
  local d = (name == "Dungeons")
  local gr = (name == "Grinding")
  local pr = (name == "Profs")
  local tw = (name == "Twink")
  local s = (name == "Settings")
  local l = (name == "Log")
  local function sh(w, on) if w then if on then w:Show() else w:Hide() end end end

  sh(f.card, g or d or gr or pr or tw)
  sh(f.header, g)
  sh(f.profCycle, pr)
  sh(f.prevText, g) sh(f.nextText, g)
  sh(f.bar, g) sh(f.barTrack, g) sh(f.barText, g)
  sh(f.skip, g) sh(f.ignoreBtn, g) sh(f.pin, g) sh(f.resyncBtn, g) sh(f.speakBtn, g) sh(f.chainBtn, g) sh(f.mapBtn, g) sh(f.prevBtn, g) sh(f.splitsBtn, g) sh(f.bugBtn, g)
  sh(f.modeBtn, s) sh(f.pinBtn, s) sh(f.voiceBtn, s) sh(f.voiceCycleBtn, s) sh(f.discBtn, s)
  sh(f.themeBtn, s) sh(f.lockBtn, s) sh(f.opacityBtn, s) sh(f.syncBtn, s) sh(f.resetBtn, s) sh(f.fontBtn, s) sh(f.clusterBtn, s) sh(f.profileText, s)
  sh(f.log, l) sh(f.copyLogBtn, l)
  UI.Update()
end

function UI.Update(step, prog, info)
  local f = UI.frame
  if not f then return end
  if step then UI.step, UI.prog, UI.info = step, prog, info end
  step, prog, info = UI.step, UI.prog, UI.info
  local level = (step and step.level) or (UnitLevel and UnitLevel("player")) or 1
  local faction = (GL.profile and GL.profile.faction) or "Both"
  local xpSuffix = (GL.Metrics and GL.Metrics.FormatBarSuffix()) or ""
  UI.UpdateTimerText()

  if f.voiceToggle and GL.db then
    f.voiceToggle:SetText(GL.db.settings.voiceEnabled and "|cff55ff55TTS|r" or "|cff888888TTS|r")
  end

  if (GL.db and GL.db.settings.miniMode) and step then
    local badge = (step.kind == "TURNIN") and "|cff55ff55[TURN IN]|r" or ((step.kind == "PICKUP") and "|cffffd100[PICK UP]|r" or ((step.kind == "CLASS") and "|cffc77dff[CLASS]|r" or "|cff55ccff[DO]|r"))
    f.miniLine:SetText(badge .. " " .. tostring(step.where or (step.lines and step.lines[1]) or ""))
    f.bar:SetValue(prog or 0)
    f.barText:SetText("Lv " .. tostring(step.level) .. " (" .. string.format("%.0f", (prog or 0) * 100) .. "%)" .. xpSuffix)
    return
  end

  if f.stepChecks then
    for i = 1, #f.stepChecks do f.stepChecks[i]:Hide() end
  end
  if f.body and f.scrollContent then
    f.body:ClearAllPoints()
    f.body:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, 0)
  end

  if UI.tab == "Guide" and step then
    local badge = (step.kind == "TURNIN") and "|cff33e07a[TURN IN]|r " or ((step.kind == "PICKUP") and "|cfff0c252[PICK UP]|r " or ((step.kind == "CLASS") and "|cffc77dff[CLASS]|r " or "|cff55bbff[OBJECTIVES]|r "))
    f.header:SetText(badge .. tostring(step.header or "") .. (step.hubSummary and ("  |cff888888(" .. step.hubSummary .. ")|r") or ""))
    local stepKey = tostring(step.kind) .. ":" .. tostring(step.ids and step.ids[1] or step.header)
    UI.currentStepKey = stepKey
    local checked = (GL.db and GL.db.stepChecks and GL.db.stepChecks[stepKey]) or {}
    local shownRows = 0
    if step.walkthrough and #step.walkthrough > 0 and f.stepChecks then
      for i = 1, #f.stepChecks do
        local cb = f.stepChecks[i]
        local line = step.walkthrough[i]
        if line then
          shownRows = i
          local isDone = checked[i] and true or false
          if cb.checkTex then
            if isDone then cb.checkTex:Show() else cb.checkTex:Hide() end
          end
          if cb.boxBorders then
            local br, bg, bb = isDone and 0.20 or 0.94, isDone and 0.88 or 0.76, isDone and 0.48 or 0.32
            for _, edge in ipairs(cb.boxBorders) do edge:SetColorTexture(br, bg, bb, 0.95) end
          end
          local col = isDone and "|cff777777" or "|cffffffff"
          cb.text:SetText(col .. line .. "|r")
          cb:Show()
        end
      end
    end
    if shownRows > 0 then
      f.body:ClearAllPoints()
      f.body:SetPoint("TOPLEFT", f.scrollContent, "TOPLEFT", 0, -(shownRows * 21 + 6))
    end
    local out = {}
    if shownRows == 0 then
      if step.where then table.insert(out, "|cff7ec8ff" .. step.where .. "|r") end
      for _, l in ipairs(step.lines or {}) do table.insert(out, l) end
    end
    for _, a in ipairs(step.advisories or {}) do table.insert(out, "|cffffaa33! " .. a .. "|r") end
    f.body:SetText(table.concat(out, "\n"))
    f.prevText:SetText("|cff888888Prev:|r " .. tostring(GL.GetLastStepText and GL.GetLastStepText() or "—"))
    f.nextText:SetText("|cff999999Next:|r " .. tostring(step.nextPreview or "—"))
    f.bar:SetValue(prog or 0)
    f.barText:SetText("Lv " .. tostring(step.level) .. "  |  1-60: " .. string.format("%.0f", (prog or 0) * 100) .. "%" .. xpSuffix)
  elseif UI.tab == "Dungeons" and GL.Fallback then
    f.body:SetText(table.concat(GL.Fallback.GetDungeonLines(level, faction), "\n\n"))
  elseif UI.tab == "Grinding" and GL.Fallback then
    f.body:SetText(table.concat(GL.Fallback.GetGrindingLines(level, faction), "\n\n"))
  elseif UI.tab == "Profs" and GL.Fallback then
    local prof = (GL.db and GL.db.settings.prof1) or "First Aid"
    f.profCycle:SetText("Profession: " .. prof)
    f.body:SetText(table.concat(GL.Fallback.GetProfessionLines(prof, GL.db and GL.db.settings.cheapestRoute), "\n\n"))
  elseif UI.tab == "Twink" and GL.Twink then
    local cls = (GL.profile and GL.profile.classToken) or "WARRIOR"
    f.body:SetText(table.concat(GL.Twink.GetLines(level, cls), "\n"))
  elseif UI.tab == "Settings" then
    local thObj = GL.Theme and GL.Theme.GetActive()
    local _, vName = GL.Voice and GL.Voice.GetActiveVoiceID() or 0, "Default"
    f.modeBtn:SetText("Mode: " .. tostring(LevelGuideDB and LevelGuideDB.settings.mode))
    f.pinBtn:SetText("Arrow/Trail: " .. ((LevelGuideDB and LevelGuideDB.settings.arrowEnabled ~= false) and "ON" or "OFF"))
    f.voiceBtn:SetText("Voice TTS: " .. ((LevelGuideDB and LevelGuideDB.settings.voiceEnabled) and "ON" or "OFF"))
    f.voiceCycleBtn:SetText("Voice: " .. string.sub(tostring(vName or "Default"), 1, 18))
    f.themeBtn:SetText("Theme: " .. tostring(thObj and thObj.label or "DarkGold"))
    f.lockBtn:SetText("Lock Window: " .. ((LevelGuideDB and LevelGuideDB.settings.locked) and "ON" or "OFF"))
    f.opacityBtn:SetText(string.format("Opacity: %d%%", math.floor((tonumber(LevelGuideDB and LevelGuideDB.settings.opacity) or 1.0) * 100 + 0.5)))
    f.fontBtn:SetText("Font Size: " .. tostring(LevelGuideDB and LevelGuideDB.settings.fontSize or 12) .. "pt")
    f.clusterBtn:SetText("Cluster Route: " .. ((LevelGuideDB and LevelGuideDB.settings.clusterRoute ~= false) and "ON" or "OFF"))
    f.profileText:SetText(info or "")
  elseif UI.tab == "Log" then
    f.log:Clear()
    f.log:AddMessage("|cfff0c252Last events (" .. tostring(#GL.events) .. ")|r")
    for _, e in ipairs(GL.events) do f.log:AddMessage(e) end
    f.log:AddMessage("|cffff4444Errors (" .. tostring(#GL.errors) .. ")|r")
    for _, e in ipairs(GL.errors) do f.log:AddMessage(e) end
  end
  if f.body and f.scrollContent and f.body.GetStringHeight then
    local okH, h = pcall(f.body.GetStringHeight, f.body)
    if okH and h then f.scrollContent:SetHeight(math.max(180, h + 28)) end
  end
end

function UI.Toggle()
  if inCombat() then
    GL.Print("Cannot toggle window during combat.")
    return
  end
  local f = UI.Create()
  if f:IsVisible() then f:Hide() else f:Show() end
  UI.SavePos()
end

function UI.RegisterBlizzardSettings()
  if UI.blizzRegistered or not Settings or not Settings.RegisterCanvasLayoutCategory or not CreateFrame then return end
  local ok = pcall(function()
    local panel = CreateFrame("Frame", "LevelGuideBlizzSettingsPanel")
    panel.name = "LevelGuide"
    local t = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("LevelGuide v" .. tostring(GL.version) .. " (WoW: Forever 16001)")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    sub:SetText("Type /guide to toggle the HUD, /guide resync to recalibrate, or /guide debug for diagnostics.")
    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(180, 24)
    openBtn:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -14)
    openBtn:SetText("Open LevelGuide Window")
    openBtn:SetScript("OnClick", function() UI.Create():Show() end)
    local cat = Settings.RegisterCanvasLayoutCategory(panel, "LevelGuide")
    Settings.RegisterAddOnCategory(cat)
    UI.blizzRegistered = true
  end)
  return ok
end
