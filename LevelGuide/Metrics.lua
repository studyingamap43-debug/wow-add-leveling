-- LevelGuide Metrics: Midnight-safe session XP/hr and Time-to-Level (TTL) tracker.
-- Uses only UnitXP / UnitXPMax / UnitLevel / GetTime (never touches combat log).

local GL = LevelGuide
local M = {}
GL.Metrics = M

M.startTime = nil
M.sessionXP = 0
M.lastXP = nil
M.lastXPMax = nil
M.lastLevel = nil

function M.Init()
  M.startTime = GetTime and GetTime() or 0
  M.sessionXP = 0
  M.lastXP = UnitXP and UnitXP("player") or 0
  M.lastXPMax = UnitXPMax and UnitXPMax("player") or 1
  M.lastLevel = UnitLevel and UnitLevel("player") or 1
end

function M.Update()
  if not M.startTime then M.Init() return end
  local curXP = UnitXP and UnitXP("player") or 0
  local curMax = UnitXPMax and UnitXPMax("player") or 1
  local curLv = UnitLevel and UnitLevel("player") or 1

  if curLv > (M.lastLevel or curLv) then
    local gained = math.max(0, (M.lastXPMax or 0) - (M.lastXP or 0)) + curXP
    M.sessionXP = M.sessionXP + gained
  elseif curXP > (M.lastXP or 0) then
    M.sessionXP = M.sessionXP + (curXP - M.lastXP)
  end

  M.lastXP = curXP
  M.lastXPMax = curMax
  M.lastLevel = curLv
end

function M.GetStats()
  local now = GetTime and GetTime() or 0
  local elapsedSec = math.max(1, now - (M.startTime or now))
  local xpPerHour = math.floor((M.sessionXP / elapsedSec) * 3600 + 0.5)
  local remXP = math.max(0, (M.lastXPMax or 1) - (M.lastXP or 0))
  local ttlMin = (xpPerHour > 0) and math.floor((remXP / xpPerHour) * 60 + 0.5) or nil
  return xpPerHour, ttlMin, M.sessionXP, math.floor(elapsedSec / 60)
end

function M.FormatBarSuffix()
  local xph, ttl = M.GetStats()
  if xph <= 0 then return "" end
  local kStr = (xph >= 1000) and string.format("%.1fk/hr", xph / 1000) or (tostring(xph) .. "/hr")
  if ttl then
    return string.format("  |  %s (~%dm)", kStr, ttl)
  end
  return "  |  " .. kStr
end
