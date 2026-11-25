-- LevelGuide AutoQuest: optional Shift-bypassable Auto-Accept & Auto-Turn-In.
-- NEVER auto-picks multi-choice rewards (so you always see Rewards.lua advice).
-- Yields when DialogueUI is loaded. Supports both C_GossipInfo (questID or index fallback)
-- and legacy GetGossipActiveQuests / GetGossipAvailableQuests APIs safely.

local GL = LevelGuide
local AQ = {}
GL.AutoQuest = AQ

local function shouldRun()
  if IsShiftKeyDown and IsShiftKeyDown() then return false end
  if GL.Compat and GL.Compat.InCombat() then return false end
  if not GL.db or not GL.db.settings or not GL.db.settings.autoQuest then return false end
  if GL.Integrations and GL.Integrations.detected and GL.Integrations.detected.DialogueUI then
    return false
  end
  return true
end

function AQ.GetGossipMode()
  if C_GossipInfo and C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
    return "C_GossipInfo"
  elseif GetGossipAvailableQuests and SelectGossipAvailableQuest then
    return "LegacyGossip"
  end
  return "Unavailable"
end

function AQ.OnQuestDetail()
  if not shouldRun() then return end
  if AcceptQuest then pcall(AcceptQuest) end
end

function AQ.OnQuestProgress()
  if not shouldRun() then return end
  if IsQuestCompletable and IsQuestCompletable() and CompleteQuest then
    pcall(CompleteQuest)
  end
end

function AQ.OnQuestComplete()
  if not shouldRun() then return end
  local choices = (GetNumQuestChoices and GetNumQuestChoices()) or 0
  -- NEVER auto-select when there are 2+ reward choices (preserves Rewards.lua advisor!)
  if choices <= 1 and GetQuestReward then
    pcall(GetQuestReward, choices == 1 and 1 or nil)
  end
end

function AQ.OnQuestGreeting()
  if not shouldRun() then return end
  local nActive = (GetNumActiveQuests and GetNumActiveQuests()) or 0
  for i = 1, nActive do
    local complete
    if GetActiveTitle then
      complete = select(2, GetActiveTitle(i))
    end
    if complete and SelectActiveQuest then
      pcall(SelectActiveQuest, i)
      return
    end
  end
  local nAvail = (GetNumAvailableQuests and GetNumAvailableQuests()) or 0
  if nAvail > 0 and SelectAvailableQuest then
    pcall(SelectAvailableQuest, 1)
  end
end

function AQ.OnGossipShow()
  if not shouldRun() then return end

  -- 1. Modern C_GossipInfo (tries questID first, falls back to 1-based index if questID arg fails)
  if C_GossipInfo then
    if C_GossipInfo.GetActiveQuests and C_GossipInfo.SelectActiveQuest then
      local ok, quests = pcall(C_GossipInfo.GetActiveQuests)
      quests = ok and GL.Compat and GL.Compat.SafeTable(quests) or (ok and type(quests) == "table" and quests) or nil
      if quests then
        for idx, q in ipairs(quests) do
          if type(q) == "table" and (q.isComplete or q.complete) then
            local id = q.questID or q.questId
            local okSel = id and pcall(C_GossipInfo.SelectActiveQuest, id)
            if not okSel then pcall(C_GossipInfo.SelectActiveQuest, idx) end
            return
          end
        end
      end
    end
    if C_GossipInfo.GetAvailableQuests and C_GossipInfo.SelectAvailableQuest then
      local ok, quests = pcall(C_GossipInfo.GetAvailableQuests)
      quests = ok and GL.Compat and GL.Compat.SafeTable(quests) or (ok and type(quests) == "table" and quests) or nil
      if quests and type(quests[1]) == "table" then
        local id = quests[1].questID or quests[1].questId
        local okSel = id and pcall(C_GossipInfo.SelectAvailableQuest, id)
        if not okSel then pcall(C_GossipInfo.SelectAvailableQuest, 1) end
        return
      end
    end
  end

  -- 2. Legacy Gossip API fallback (older clients / Classic Era shape)
  if GetGossipActiveQuests and SelectGossipActiveQuest then
    local ok, a1, a2, a3, a4 = pcall(GetGossipActiveQuests)
    if ok and a1 then
      -- Legacy stride: title, level, isTrivial, isComplete
      if a4 then pcall(SelectGossipActiveQuest, 1) return end
    end
  end
  if GetGossipAvailableQuests and SelectGossipAvailableQuest then
    local ok, firstTitle = pcall(GetGossipAvailableQuests)
    if ok and firstTitle then
      pcall(SelectGossipAvailableQuest, 1)
    end
  end
end
