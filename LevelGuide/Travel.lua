-- LevelGuide Travel: cross-zone/continent transport hints (tram, boats, zeppelins)
-- and per-character flight path discovery tracking on TAXIMAP_OPENED.

local GL = LevelGuide
local T = {}
GL.Travel = T

local KALIMDOR = {
  ["Durotar"] = true, ["Mulgore"] = true, ["The Barrens"] = true, ["Teldrassil"] = true,
  ["Darkshore"] = true, ["Ashenvale"] = true, ["Stonetalon Mountains"] = true, ["Thousand Needles"] = true,
  ["Desolace"] = true, ["Dustwallow Marsh"] = true, ["Feralas"] = true, ["Tanaris"] = true,
  ["Azshara"] = true, ["Felwood"] = true, ["Un'Goro Crater"] = true, ["Moonglade"] = true,
  ["Winterspring"] = true, ["Silithus"] = true, ["Orgrimmar"] = true, ["Thunder Bluff"] = true,
  ["Darnassus"] = true,
}

local EK = {
  ["Elwynn Forest"] = true, ["Westfall"] = true, ["Redridge Mountains"] = true, ["Duskwood"] = true,
  ["Darkshire"] = true, ["Dun Morogh"] = true, ["Loch Modan"] = true, ["Wetlands"] = true,
  ["Stranglethorn Vale"] = true, ["Swamp of Sorrows"] = true, ["Blasted Lands"] = true,
  ["Badlands"] = true, ["Searing Gorge"] = true, ["Burning Steppes"] = true,
  ["Tirisfal Glades"] = true, ["Silverpine Forest"] = true, ["Hillsbrad Foothills"] = true,
  ["Alterac Mountains"] = true, ["Arathi Highlands"] = true, ["The Hinterlands"] = true,
  ["Western Plaguelands"] = true, ["Eastern Plaguelands"] = true,
  ["Stormwind City"] = true, ["Ironforge"] = true, ["Undercity"] = true,
}

function T.GetContinent(zone)
  if not zone then return nil end
  if KALIMDOR[zone] then return "Kalimdor" end
  if EK[zone] then return "Eastern Kingdoms" end
  return nil
end

function T.GetRouteHint(fromZone, toZone, faction)
  if not fromZone or not toZone or string.lower(fromZone) == string.lower(toZone) then
    return nil
  end
  -- Direct Stormwind <-> Ironforge / Dun Morogh / Loch Modan via Deeprun Tram
  if faction == "Alliance" then
    if (fromZone == "Elwynn Forest" or fromZone == "Stormwind City") and (toZone == "Dun Morogh" or toZone == "Ironforge" or toZone == "Loch Modan") then
      return "Travel: Take the Deeprun Tram (Stormwind Dwarven District -> Ironforge)."
    end
    if (fromZone == "Dun Morogh" or fromZone == "Ironforge") and (toZone == "Elwynn Forest" or toZone == "Stormwind City" or toZone == "Westfall") then
      return "Travel: Take the Deeprun Tram (Ironforge Tinker Town -> Stormwind)."
    end
    if fromZone == "Teldrassil" and toZone == "Darkshore" then
      return "Travel: Pink portal in Darnassus -> Rut'theran Village -> Boat to Auberdine (Darkshore)."
    end
  end

  local cFrom = T.GetContinent(fromZone)
  local cTo = T.GetContinent(toZone)
  if cFrom and cTo and cFrom ~= cTo then
    if faction == "Alliance" then
      if cTo == "Kalimdor" then
        return "Travel (EK -> Kalimdor): Forever ship Stormwind Harbor -> Auberdine, Menethil -> Theramore, or Booty Bay -> Ratchet."
      else
        return "Travel (Kalimdor -> EK): Forever ship Auberdine -> Stormwind Harbor, Theramore -> Menethil, or Tanaris <-> Powderfuse Port (Riverglades)."
      end
    else
      if cTo == "Kalimdor" then
        return "Travel (EK -> Kalimdor): Zeppelin from Undercity (Brill) or Grom'gol (STV) to Orgrimmar, Booty Bay -> Ratchet, or Tanaris <-> Powderfuse Port (Riverglades)."
      else
        return "Travel (Kalimdor -> EK): Zeppelin outside Orgrimmar to Undercity or Grom'gol (STV), Ratchet -> Booty Bay, or Tanaris <-> Powderfuse Port (Riverglades)."
      end
    end
  end
  return nil
end

function T.ScanFlightPaths()
  if not GL.db or not NumTaxiNodes or not TaxiNodeName then return 0 end
  GL.db.flightPaths = type(GL.db.flightPaths) == "table" and GL.db.flightPaths or {}
  local okN, n = pcall(NumTaxiNodes)
  if not okN or not n then return 0 end
  local added = 0
  for i = 1, n do
    local okName, name = pcall(TaxiNodeName, i)
    local okType, ntype = pcall(TaxiNodeGetType, i)
    if okName and name and okType and (ntype == "CURRENT" or ntype == "REACHABLE") then
      if not GL.db.flightPaths[name] then
        GL.db.flightPaths[name] = true
        added = added + 1
      end
    end
  end
  if added > 0 then
    GL.LogEvent("FLIGHTPATHS", "+" .. tostring(added) .. " known")
  end
  return added
end

function T.KnownFlightPathCount()
  if not GL.db or type(GL.db.flightPaths) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(GL.db.flightPaths) do n = n + 1 end
  return n
end
