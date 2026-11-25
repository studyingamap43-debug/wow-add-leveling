-- LevelGuide Reminders: bag space, durability/repair, Hearthstone bind & cooldown,
-- and What's Training? / trainer / instance awareness.

local GL = LevelGuide
local Rem = {}
GL.Reminders = Rem

local HEARTHSTONE_ID = 6948

function Rem.GetFreeBagSlots()
  if not C_Container or not C_Container.GetContainerNumFreeSlots then return nil end
  local free = 0
  for bag = 0, 4 do
    local ok, slots = pcall(C_Container.GetContainerNumFreeSlots, bag)
    if ok and type(slots) == "number" then
      free = free + slots
    end
  end
  return free
end

function Rem.GetLowestDurabilityPct()
  if not GetInventoryItemDurability then return nil end
  local lowest = 100
  local found = false
  for slot = 1, 18 do
    local ok, cur, mx = pcall(GetInventoryItemDurability, slot)
    if ok and cur and mx and mx > 0 then
      found = true
      local pct = math.floor((cur / mx) * 100 + 0.5)
      if pct < lowest then lowest = pct end
    end
  end
  return found and lowest or nil
end

function Rem.IsHearthstoneReady()
  if not C_Container or not C_Container.GetItemCooldown then return false end
  local ok, start, duration = pcall(C_Container.GetItemCooldown, HEARTHSTONE_ID)
  if ok and start and duration then
    return (start == 0 or duration == 0)
  end
  return false
end

function Rem.BuildAdvisories(step, ctx)
  local out = {}
  local free = Rem.GetFreeBagSlots()
  if free and free <= 2 then
    out[#out + 1] = string.format("Low bag space (%d free) — vendor junk at next hub.", free)
  end
  local dur = Rem.GetLowestDurabilityPct()
  if dur and dur <= 30 then
    out[#out + 1] = string.format("Low gear durability (%d%%) — repair soon.", dur)
  end
  if step and step.kind == "TURNIN" and step.targetZone and ctx.zone and step.targetZone ~= ctx.zone then
    local okB, bind = pcall(GetBindLocation or function() return nil end)
    bind = okB and bind or nil
    if bind and Rem.IsHearthstoneReady() then
      out[#out + 1] = "Hearthstone READY (bound to " .. tostring(bind) .. ") — check if hearth saves travel."
    end
  end
  if GL.Travel and step and step.targetZone and ctx.zone and step.targetZone ~= ctx.zone then
    local hint = GL.Travel.GetRouteHint(ctx.zone, step.targetZone, GL.profile and GL.profile.faction)
    if hint then out[#out + 1] = hint end
  end
  if GL.Rewards and GL.Rewards.lastAdvice then
    out[#out + 1] = GL.Rewards.lastAdvice
  end
  return out
end
