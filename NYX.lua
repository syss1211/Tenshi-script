-- Stable Tenshi Finder entry point. Keep sharing this NYX.lua URL.
local url = "https://raw.githubusercontent.com/syss1211/Tenshi-script/c8d58558fc4ebfd4b4b6ccb007afc718e7586f4e/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time())
local ok, source = pcall(function()
    return game:HttpGet(url)
end)
assert(ok and type(source) == "string" and #source > 0, "Tenshi Finder: download failed; check your connection and try again")
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
