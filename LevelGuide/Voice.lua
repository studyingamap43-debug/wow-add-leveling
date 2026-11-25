-- LevelGuide Voice: native WoW: Forever 16001 Text-to-Speech (C_VoiceChat.SpeakText)
-- + subtle sound cues + long-term external narrated VoicePack hook.

local GL = LevelGuide
local V = {}
GL.Voice = V

V.packs = {}
V.lastSpokenKey = nil
V.lastSpokenAt = 0

-- Long-term hook: external voice pack addons can register custom OGG/MP3 files per questId
function V.RegisterPack(packName, soundMap)
  if type(packName) == "string" and type(soundMap) == "table" then
    V.packs[packName] = soundMap
    GL.LogEvent("VOICEPACK", packName)
  end
end

function V.GetAvailableVoices()
  if C_VoiceChat and C_VoiceChat.GetTtsVoices then
    local ok, list = pcall(C_VoiceChat.GetTtsVoices)
    if ok and type(list) == "table" and #list > 0 then
      return list
    end
  end
  return {}
end

function V.GetActiveVoiceID()
  local saved = GL.db and GL.db.settings and GL.db.settings.voiceID
  local voices = V.GetAvailableVoices()
  if saved then
    for _, v in ipairs(voices) do
      if v.voiceID == saved then return saved, v.name end
    end
  end
  if voices[1] then
    return voices[1].voiceID, voices[1].name
  end
  return 0, "System Default"
end

function V.CycleVoice()
  local voices = V.GetAvailableVoices()
  if #voices == 0 then
    GL.Print("No system TTS voices reported by client; using audio chimes fallback.")
    return
  end
  local curId = V.GetActiveVoiceID()
  local nextIdx = 1
  for i = 1, #voices do
    if voices[i].voiceID == curId then
      nextIdx = (i % #voices) + 1
      break
    end
  end
  local chosen = voices[nextIdx]
  if GL.db and GL.db.settings then
    GL.db.settings.voiceID = chosen.voiceID
  end
  GL.Print("Voice set to: " .. tostring(chosen.name))
  V.Speak("LevelGuide voice ready.", true)
end

function V.PlayCue(cueType)
  if not PlaySound or not SOUNDKIT then return end
  local kit = nil
  if cueType == "TURNIN" then kit = SOUNDKIT.IG_QUEST_LIST_COMPLETE
  elseif cueType == "PICKUP" then kit = SOUNDKIT.IG_QUEST_LOG_OPEN
  elseif cueType == "LEVELUP" then kit = SOUNDKIT.LEVELUP
  else kit = SOUNDKIT.MAP_PING end
  if kit then pcall(PlaySound, kit, "Master") end
end

local function cleanSpeech(text)
  if type(text) ~= "string" then return "" end
  -- Strip WoW color codes |cffXXXXXX and |r
  local s = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  s = string.gsub(s, "|r", "")
  s = string.gsub(s, "\n", ". ")
  return s
end

function V.Speak(text, force)
  local enabled = GL.db and GL.db.settings and GL.db.settings.voiceEnabled
  if not force and not enabled then return false end
  if not force and GL.Compat and GL.Compat.InCombat() then return false end
  local clean = cleanSpeech(text)
  if clean == "" then return false end

  local now = GetTime and GetTime() or 0
  if not force and (now - V.lastSpokenAt) < 1.5 then return false end
  V.lastSpokenAt = now

  -- Try native WoW 12.x / Forever 16001 TTS API first
  if C_VoiceChat and C_VoiceChat.SpeakText then
    local voiceID = V.GetActiveVoiceID()
    local rate = (GL.db and GL.db.settings and tonumber(GL.db.settings.voiceRate)) or 0
    local vol = (GL.db and GL.db.settings and tonumber(GL.db.settings.voiceVolume)) or 80
    local dest = (Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback) or 1
    if C_VoiceChat.StopSpeakingText then pcall(C_VoiceChat.StopSpeakingText) end
    local ok = pcall(C_VoiceChat.SpeakText, voiceID, clean, dest, rate, vol)
    if ok then
      GL.LogEvent("VOICE_TTS", string.sub(clean, 1, 40))
      return true
    end
  end

  -- Graceful fallback: subtle audio cue
  V.PlayCue("PING")
  return false
end

function V.BuildStepAnnouncement(step)
  if not step or step.kind == "NONE" then return nil end
  local firstLine = (step.lines and step.lines[1]) or ""
  firstLine = string.gsub(firstLine, "^%-%s*", "")
  if step.kind == "TURNIN" then
    local npc = (step.target and step.target[1]) or "the quest giver"
    return "Turn in " .. firstLine .. " to " .. tostring(npc) .. "."
  elseif step.kind == "PICKUP" then
    local npc = (step.target and step.target[1]) or "nearby quest giver"
    return "Pick up " .. firstLine .. " from " .. tostring(npc) .. "."
  elseif step.kind == "OBJECTIVE" then
    return "Next objective: " .. firstLine .. "."
  end
  return nil
end

function V.AnnounceStep(step, force)
  if not step then return end
  local key = tostring(step.kind) .. ":" .. tostring(step.header) .. ":" .. tostring(step.ids and step.ids[1] or "")
  if not force and key == V.lastSpokenKey then return end
  V.lastSpokenKey = key

  -- Check custom external VoicePack first (long-term narrated pack support)
  local qid = step.ids and step.ids[1]
  if qid and PlaySoundFile then
    for _, soundMap in pairs(V.packs) do
      if soundMap[qid] then
        local ok = pcall(PlaySoundFile, soundMap[qid], "Master")
        if ok then return end
      end
    end
  end

  local msg = V.BuildStepAnnouncement(step)
  if msg then
    if not V.Speak(msg, force) and (GL.db and GL.db.settings and GL.db.settings.voiceEnabled) then
      V.PlayCue(step.kind)
    end
  end
end
