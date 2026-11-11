-- Wait for game/player readiness when executed automatically (including Real).
return task.spawn(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
    local Players = game:GetService("Players")
    while not Players.LocalPlayer do task.wait(0.2) end
    Players.LocalPlayer:WaitForChild("PlayerGui")
    task.wait(2)
    local success, failure = pcall(function()
        -- Stable Tenshi Finder entry point. Keep sharing this NYX.lua URL.
        local url = "https://raw.githubusercontent.com/syss1211/Tenshi-script/231da2f7ac4dd4ff8153d993c8bd7753de625d0d/Tenshi-Finder-Beta.lua?nyx=" .. tostring(os.time())
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
