-- Compatibility entry point for existing direct links.
local source = game:HttpGet("https://raw.githubusercontent.com/syss1211/Tenshi-script/d23820e7bd01e266592aa157e234728808423ccb/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time()))
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
