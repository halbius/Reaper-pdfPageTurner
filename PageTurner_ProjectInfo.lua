-- PageTurner ProjectInfo
-- 1) startet (optional) den Helfer-Server pageturner_helper.py im Hintergrund
-- 2) schreibt den Ordner des aktiven Projekts in den ExtState (pagesWebRC / projectDir)
-- Am besten als Startup-Action (SWS) eintragen. Der Helfer beendet sich selbst, wenn Reaper endet.

-- === Einstellungen ===
local START_HELPER = true
local PYTHON = "/Library/Frameworks/Python.framework/Versions/3.15/bin/python3"   -- Windows: "pythonw" (ohne Konsolenfenster); Mac: am besten voller Pfad (Terminal: which python3)
local HELPER = "/Users/Christian/Library/Application Support/REAPER/Scripts/CA/pageturner_helper.py"
local ROOT   = "/Users/Christian/Documents"   -- z.B. "E:/Audio" oder "/Volumes/Audio"
-- =====================

if START_HELPER and not HELPER:find("/Pfad/zu", 1, true) then
  -- -1 = nicht auf das Ende warten; läuft schon eine Instanz, beendet sich die neue sofort
  reaper.ExecProcess(('"%s" "%s" "%s"'):format(PYTHON, HELPER, ROOT), -1)
end

local last, t0 = nil, 0
function tick()
  local now = reaper.time_precise()
  if now - t0 > 1 then
    t0 = now
    local _, fn = reaper.EnumProjects(-1)
    local dir = (fn and fn:match("^(.*)[/\\][^/\\]*$")) or ""
    dir = dir:gsub("\\", "/")
    if dir ~= last then
      last = dir
      reaper.SetExtState("pagesWebRC", "projectDir", dir, false)
    end
  end
  reaper.defer(tick)
end
tick()
