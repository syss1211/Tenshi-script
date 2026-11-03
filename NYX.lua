-- Stable Tenshi Finder entry point. Keep sharing this NYX.lua URL.
local url = "https://raw.githubusercontent.com/syss1211/Tenshi-script/d2d5de67a1a624599450c96deefa6ce4001333c2/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time())
local ok, source = pcall(function()
    return game:HttpGet(url)
end)
assert(ok and type(source) == "string" and #source > 0, "Tenshi Finder: download failed; check your connection and try again")
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
