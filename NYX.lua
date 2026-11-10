-- Wait for game/player readiness when executed automatically (including Real).
return task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local Players = game:GetService("Players")
    while not Players.LocalPlayer do task.wait(0.2) end
    Players.LocalPlayer:WaitForChild("PlayerGui")
    task.wait(2)
    local success, failure = pcall(function()
        -- Stable Tenshi Finder entry point. Keep sharing this NYX.lua URL.
        local url = "https://raw.githubusercontent.com/syss1211/Tenshi-script/4cff9133c49b04f7fbb55188756fce16d6359f97/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time())
        local ok, source = pcall(function()
            return game:HttpGet(url)
        end)
        assert(ok and type(source) == "string" and #source > 0, "Tenshi Finder: download failed; check your connection and try again")
        local run, compileError = loadstring(source)
        assert(run, "Tenshi Finder: invalid download: " .. tostring(compileError))
        return run()
        
    end)
    if not success then warn("[Tenshi Auto-Execute] " .. tostring(failure)) end
end)
