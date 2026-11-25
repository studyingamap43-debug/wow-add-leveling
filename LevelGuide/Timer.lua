-- LevelGuide Timer: session stopwatch, current-level split timer, step timer,
-- and persistent per-character level split history (LevelGuideDB.splits).

local GL = LevelGuide
local Tm = {}
GL.Timer = Tm

Tm.running = true
Tm.sessionSec = 0
Tm.levelSec = 0
Tm.stepSec = 0
Tm.lastStepKey = nil

function Tm.Init()
  Tm.running = true
  Tm.sessionSec = 0
  Tm.levelSec = (GL.db and GL.db.timer and tonumber(GL.db.timer.currentLevelSec)) or 0
  Tm.stepSec = 0
  Tm.lastStepKey = nil
end

function Tm.Tick(elapsed)
  if not Tm.running then return end
  local dt = tonumber(elapsed) or 0
  if dt <= 0 or dt > 10 then return end
  Tm.sessionSec = Tm.sessionSec + dt
  Tm.levelSec = Tm.levelSec + dt
  Tm.stepSec = Tm.stepSec + dt
  Tm._saveAccum = (Tm._saveAccum or 0) + dt
  if GL.db and Tm._saveAccum >= 10 then
    local sd = Tm._saveAccum
    Tm._saveAccum = 0
    GL.db.timer = type(GL.db.timer) == "table" and GL.db.timer or {}
    GL.db.timer.currentLevelSec = math.floor(Tm.levelSec)
    GL.db.timer.totalPlayedGuideSec = math.floor((GL.db.timer.totalPlayedGuideSec or 0) + sd)
  end
end

function Tm.OnStepChanged(stepKey)
  if stepKey and stepKey ~= Tm.lastStepKey then
    Tm.lastStepKey = stepKey
    Tm.stepSec = 0
  end
end

function Tm.OnLevelUp(newLevel)
  if not GL.db then return end
  GL.db.splits = type(GL.db.splits) == "table" and GL.db.splits or {}
  local prevLv = (tonumber(newLevel) or 2) - 1
  if prevLv >= 1 then
    GL.db.splits[prevLv] = math.floor(Tm.levelSec)
    GL.Print(string.format("Level %d -> %d split recorded: %s", prevLv, prevLv + 1, Tm.Format(Tm.levelSec)))
  end
  Tm.levelSec = 0
  if GL.db.timer then GL.db.timer.currentLevelSec = 0 end
end

function Tm.TogglePause()
  Tm.running = not Tm.running
  GL.Print("Timer " .. (Tm.running and "resumed." or "paused."))
end

function Tm.ResetSession()
  Tm.sessionSec = 0
  Tm.stepSec = 0
  GL.Print("Session timer reset.")
end

function Tm.Format(sec)
  sec = math.max(0, math.floor(tonumber(sec) or 0))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  if h > 0 then
    return string.format("%02d:%02d:%02d", h, m, s)
  end
  return string.format("%02d:%02d", m, s)
end

function Tm.GetHeaderText(level)
  local status = Tm.running and "" or " [PAUSED]"
  return string.format("%s  |  Lv%d %s%s", Tm.Format(Tm.sessionSec), tonumber(level) or 1, Tm.Format(Tm.levelSec), status)
end

function Tm.ExportSplits()
  local lines = { "=== LevelGuide Level Splits (" .. tostring(GL.profile and GL.profile.key or "?") .. ") ===" }
  lines[#lines + 1] = "Session: " .. Tm.Format(Tm.sessionSec) .. " | Current Level: " .. Tm.Format(Tm.levelSec)
  local splits = GL.db and GL.db.splits or {}
  local keys = {}
  for k in pairs(splits) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then
    lines[#lines + 1] = "(no completed level splits yet)"
  else
    for _, lv in ipairs(keys) do
      lines[#lines + 1] = string.format("Level %d -> %d : %s", lv, lv + 1, Tm.Format(splits[lv]))
    end
  end
  return table.concat(lines, "\n")
end
