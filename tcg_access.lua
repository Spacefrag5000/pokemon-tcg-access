-- Pokemon Trading Card Game accessibility mod - loader.
-- Runs tcg_core.lua, and runs it again whenever it asks to be
-- reloaded, so the mod can be updated without restarting the emulator.
-- If the core has an error, the error goes to work\error.txt and the
-- game keeps running until a RELOAD command arrives in work\cmd.txt.

-- the folder this file is in (the mod's files sit together in it)
local ROOT = debug.getinfo(1, "S").source:match("^@(.*[\\/])") or ""
local CORE = ROOT .. "tcg_core.lua"
local WORK = ROOT .. "work\\"

while true do
  os.remove(WORK .. "error.txt")
  local ok, err = pcall(dofile, CORE)
  TCG_RELOADED = true
  if not ok then
    local f = io.open(WORK .. "error.txt", "w")
    if f then f:write(tostring(err)) f:close() end
    pcall(function() speech.output("Mod error. Waiting for a reload.", true) end)
    while true do
      emu.frameadvance()
      local c = io.open(WORK .. "cmd.txt", "r")
      if c then
        local line = c:read("*l") or ""
        c:close()
        os.remove(WORK .. "cmd.txt")
        local a = io.open(WORK .. "ack.txt", "w")
        if a then a:write("OK reload after error") a:close() end
        if line:upper():match("^RELOAD") then break end
      end
    end
  end
end
