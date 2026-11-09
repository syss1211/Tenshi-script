-- Compatibility entry point for existing direct links.
local source = game:HttpGet("https://raw.githubusercontent.com/syss1211/Tenshi-script/7205a9363c8225ea5ed8b8ace1224f1e814d8046/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time()))
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
