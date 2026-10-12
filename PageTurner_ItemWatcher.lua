-- PageTurner ItemWatcher v5
-- Neu: schreibt activeItemStart (Startzeit des aktiven Items)
--      und itemLookup enthält ALLE Items inkl. Duplikate als JSON-Array

local EXT_SECTION  = "pagesWebRC"
local EXT_KEY      = "activeItem"
local START_KEY    = "activeItemStart"   -- NEU: Startzeit des aktiven Items
local LOOKUP_KEY   = "itemLookup"
local FLAG_KEY     = "itemWatcherRun"
local INTERVAL     = 0.1
local lastTime     = 0
local lastName     = ""
local lastStart    = -1
local lastLookup   = ""
local lookupTimer  = 0

reaper.SetExtState(EXT_SECTION, FLAG_KEY, "1", false)

function shouldRun()
  return reaper.GetExtState(EXT_SECTION, FLAG_KEY) ~= "0"
end

function findActiveItem()
  local playState = reaper.GetPlayState()
  if playState ~= 1 and playState ~= 5 then return "", -1 end

  local playPos    = reaper.GetPlayPosition()
  local trackCount = reaper.CountTracks(0)

  for t = 0, trackCount - 1 do
    local track     = reaper.GetTrack(0, t)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
      local item  = reaper.GetTrackMediaItem(track, i)
      local start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local len   = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      if playPos >= start and playPos < (start + len) then
        local take = reaper.GetActiveTake(item)
        if take ~= nil then
          local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
          if ok and name ~= nil and name ~= "" then
            return name, start  -- Name UND Startzeit zurückgeben
          end
        end
      end
    end
  end
  return "", -1
end

-- Baut JSON-Array ALLER Items (inkl. Duplikate): [{"name":"...","start":1.23}, ...]
-- So können gleichnamige Items anhand ihrer Startzeit unterschieden werden
function buildItemLookup()
  local entries = {}
  local trackCount = reaper.CountTracks(0)

  for t = 0, trackCount - 1 do
    local track     = reaper.GetTrack(0, t)
    local itemCount = reaper.CountTrackMediaItems(track)
    for i = 0, itemCount - 1 do
      local item  = reaper.GetTrackMediaItem(track, i)
      local start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      local take  = reaper.GetActiveTake(item)
      if take ~= nil then
        local ok, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
        if ok and name ~= nil and name ~= "" then
          local safeName = name:gsub('\\', '\\\\'):gsub('"', '\\"')
          table.insert(entries, string.format('{"name":"%s","start":%.6f}', safeName, start))
        end
      end
    end
  end

  return "[" .. table.concat(entries, ",") .. "]"
end

function tick()
  if not shouldRun() then
    reaper.SetExtState(EXT_SECTION, EXT_KEY,   "", false)
    reaper.SetExtState(EXT_SECTION, START_KEY, "-1", false)
    return
  end

  local now = reaper.time_precise()
  if now - lastTime >= INTERVAL then
    lastTime = now
    local name, start = findActiveItem()

    if name ~= lastName then
      lastName = name
      reaper.SetExtState(EXT_SECTION, EXT_KEY, name, false)
    end
    if start ~= lastStart then
      lastStart = start
      reaper.SetExtState(EXT_SECTION, START_KEY, tostring(start), false)
    end
  end

  reaper.defer(tick)
end

function tickLookup()
  if not shouldRun() then return end
  local now = reaper.time_precise()
  if now - lookupTimer >= 2.0 then
    lookupTimer = now
    local lookup = buildItemLookup()
    if lookup ~= lastLookup then
      lastLookup = lookup
      reaper.SetExtState(EXT_SECTION, LOOKUP_KEY, lookup, false)
    end
  end
  reaper.defer(tickLookup)
end

reaper.defer(tick)
reaper.defer(tickLookup)
