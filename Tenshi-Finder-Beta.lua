-- Compatibility entry point for existing direct links.
local source = game:HttpGet("https://raw.githubusercontent.com/syss1211/Tenshi-script/30afb7dc7e966c18e83b1b02ec56f070f2af22ba/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time()))
local run, compileError = loadstring(source)
assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
return run()
