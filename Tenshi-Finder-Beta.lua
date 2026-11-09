-- Compatibility entry point for existing direct links.
local source = game:HttpGet("https://raw.githubusercontent.com/syss1211/Tenshi-script/85949d8c5d78513bf423f3b5683fd05cae0529f1/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time()))
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
