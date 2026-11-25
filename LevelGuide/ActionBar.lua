-- LevelGuide ActionBar: Zero-taint SecureActionButtonTemplate for 1-click Quest Mob/NPC Targeting
-- and Usable Quest Item activation. Degrades cleanly to a plain clickable button list if secure
-- creation or click CVar fails. All attribute updates defer until PLAYER_REGEN_ENABLED.

local GL = LevelGuide
local AB = {}
GL.ActionBar = AB

AB.targetBtn = nil
AB.itemBtn = nil
AB.mode = "Uninitialized" -- "Secure" | "PlainFallback" | "Uninitialized"
AB.pendingTargetName = nil
AB.pendingItemId = nil
AB.pendingItemName = nil

local function extractTargetName(step)
  if not step then return nil end
  if step.kind == "PICKUP" or step.kind == "TURNIN" then
    if step.target and type(step.target[1]) == "string" and step.target[1] ~= "" then
      return step.target[1]
    end
  elseif step.kind == "OBJECTIVE" then
    if step.target and not step.targetIsTurnIn and type(step.target[1]) == "string" then
      local clean = string.gsub(step.target[1], "%s*%(Drop Candidate%)$", "")
      if clean ~= "" then return clean end
    end
    if GL.state and GL.state.log and step.ids and step.ids[1] then
      for _, e in ipairs(GL.state.log) do
        if e.id == step.ids[1] and e.objectives then
          for _, o in ipairs(e.objectives) do
            if not o.finished and type(o.text) == "string" then
              local mob = string.match(o.text, "^(.-)%s+slain:")
                or string.match(o.text, "^(.-)%s+killed:")
                or string.match(o.text, "^(.-):%s*%d+/%d+")
              if mob and mob ~= "" then return mob end
            end
          end
        end
      end
    end
  end
  return nil
end

local function findUsableQuestItemInBags()
  if not C_Container or not C_Container.GetContainerNumSlots or not C_Container.GetContainerItemQuestInfo then
    return nil
  end
  for bag = 0, 5 do
    local okS, slots = pcall(C_Container.GetContainerNumSlots, bag)
    if okS and type(slots) == "number" then
      for slot = 1, slots do
        local okQ, qInfo = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        qInfo = okQ and GL.Compat and GL.Compat.SafeTable(qInfo) or nil
        if qInfo and (qInfo.isQuestItem or qInfo.questID) then
          local okI, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
          info = okI and GL.Compat and GL.Compat.SafeTable(info) or nil
          local itemId = info and GL.Compat.SafeNumber(info.itemID, nil) or nil
          if itemId and C_Item and C_Item.GetItemSpell then
            local okSp, spellName = pcall(C_Item.GetItemSpell, itemId)
            if okSp and spellName then
              return itemId, info.itemName or ("Item #" .. tostring(itemId))
            end
          end
        end
      end
    end
  end
  return nil
end

local function registerSecureClicks(btn)
  local down = false
  if C_CVar and C_CVar.GetCVarBool then
    local ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    down = ok and v and true or false
  end
  local okReg = pcall(btn.RegisterForClicks, btn, down and "AnyDown" or "AnyUp")
  return okReg
end

local function createPlainFallback(parentFrame)
  local tb = CreateFrame("Button", "LevelGuideTargetButtonPlain", parentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  tb:SetSize(165, 22)
  tb:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, -4)
  if GL.Theme then GL.Theme.StyleFrame(tb, true) end
  local tfs = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tfs:SetPoint("CENTER", 0, 0)
  tfs:SetWidth(155)
  tb.label = tfs
  tb:SetScript("OnClick", function()
    local name = AB.pendingTargetName
    if not name or name == "" then return end
    if GL.Compat and GL.Compat.InCombat() then
      GL.Print("In combat: plain target button cannot fire. Type: /target " .. name)
      return
    end
    if TargetUnit and pcall(TargetUnit, name) then return end
    GL.Print("Could not target. Type: /target " .. name)
  end)
  tb:Hide()
  AB.targetBtn = tb

  local ib = CreateFrame("Button", "LevelGuideQuestItemButtonPlain", parentFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  ib:SetSize(150, 22)
  ib:SetPoint("LEFT", tb, "RIGHT", 6, 0)
  if GL.Theme then GL.Theme.StyleFrame(ib, true) end
  local ifs = ib:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ifs:SetPoint("CENTER", 0, 0)
  ifs:SetWidth(140)
  ib.label = ifs
  ib:SetScript("OnClick", function()
    local itemId, itemName = AB.pendingItemId, AB.pendingItemName
    if not itemId and (not itemName or itemName == "") then return end
    if GL.Compat and GL.Compat.InCombat() then
      GL.Print("In combat: plain item button cannot fire. Use from bags: " .. tostring(itemName or itemId))
      return
    end
    if itemName and UseItemByName and pcall(UseItemByName, itemName) then return end
    if itemName and C_Item and C_Item.UseItemByName and pcall(C_Item.UseItemByName, itemName) then return end
    GL.Print("Could not use item automatically. Use from bags: " .. tostring(itemName or itemId))
  end)
  ib:Hide()
  AB.itemBtn = ib
  AB.mode = "PlainFallback"
end

function AB.Create(parentFrame)
  if AB.targetBtn or not parentFrame or not CreateFrame then return end
  if GL.Compat and GL.Compat.InCombat() then return end

  local tpl = BackdropTemplateMixin and "SecureActionButtonTemplate,BackdropTemplate" or "SecureActionButtonTemplate"
  local okT, tb = pcall(CreateFrame, "Button", "LevelGuideTargetButton", parentFrame, tpl)
  local okI, ib = pcall(CreateFrame, "Button", "LevelGuideQuestItemButton", parentFrame, tpl)
  if not okT or not tb or not okI or not ib or not registerSecureClicks(tb) or not registerSecureClicks(ib) then
    if tb then pcall(tb.Hide, tb) end
    if ib then pcall(ib.Hide, ib) end
    createPlainFallback(parentFrame)
    return
  end

  tb:SetSize(165, 22)
  tb:SetPoint("TOPLEFT", parentFrame, "BOTTOMLEFT", 0, -4)
  tb:SetAttribute("type", "macro")
  tb:SetAttribute("macrotext", "")
  if GL.Theme then GL.Theme.StyleFrame(tb, true) end
  local tfs = tb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  tfs:SetPoint("CENTER", 0, 0)
  tfs:SetWidth(155)
  tfs:SetText("Target: —")
  tb.label = tfs
  tb:Hide()
  AB.targetBtn = tb

  ib:SetSize(150, 22)
  ib:SetPoint("LEFT", tb, "RIGHT", 6, 0)
  ib:SetAttribute("type", "item")
  ib:SetAttribute("item", "")
  if GL.Theme then GL.Theme.StyleFrame(ib, true) end
  local ifs = ib:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ifs:SetPoint("CENTER", 0, 0)
  ifs:SetWidth(140)
  ifs:SetText("Use Item")
  ib.label = ifs
  ib:Hide()
  AB.itemBtn = ib
  AB.mode = "Secure"
end

function AB.ApplyPending()
  if GL.Compat and GL.Compat.InCombat() then return end

  if AB.targetBtn then
    local name = AB.pendingTargetName
    if name and name ~= "" then
      local safeName = string.gsub(name, "[%c/|\\;]", "")
      safeName = string.gsub(safeName, "^%s+", "")
      safeName = string.gsub(safeName, "%s+$", "")
      if safeName == "" then
        if AB.mode == "Secure" then pcall(AB.targetBtn.SetAttribute, AB.targetBtn, "macrotext", "") end
        AB.targetBtn:Hide()
      else
        if AB.mode == "Secure" then
          pcall(AB.targetBtn.SetAttribute, AB.targetBtn, "macrotext", "/cleartarget [dead][noexists]\n/target " .. safeName)
        end
        AB.targetBtn.label:SetText("|cfff0c252Target:|r " .. string.sub(safeName, 1, 18))
        AB.targetBtn:Show()
      end
    else
      if AB.mode == "Secure" then pcall(AB.targetBtn.SetAttribute, AB.targetBtn, "macrotext", "") end
      AB.targetBtn:Hide()
    end
  end

  if AB.itemBtn then
    local itemId = AB.pendingItemId
    if itemId then
      if AB.mode == "Secure" then
        pcall(AB.itemBtn.SetAttribute, AB.itemBtn, "item", "item:" .. tostring(itemId))
      end
      AB.itemBtn.label:SetText("|cff55ff55Use:|r " .. string.sub(tostring(AB.pendingItemName or "Quest Item"), 1, 16))
      AB.itemBtn:Show()
    else
      if AB.mode == "Secure" then pcall(AB.itemBtn.SetAttribute, AB.itemBtn, "item", "") end
      AB.itemBtn:Hide()
    end
  end
end

function AB.UpdateForStep(step)
  if not AB.targetBtn and GL.UI and GL.UI.frame then
    AB.Create(GL.UI.frame)
  end
  AB.pendingTargetName = extractTargetName(step)
  local qItemId, qItemName = findUsableQuestItemInBags()
  AB.pendingItemId = qItemId
  AB.pendingItemName = qItemName
  AB.ApplyPending()
end
