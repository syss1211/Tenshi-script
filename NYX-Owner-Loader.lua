task.spawn(function()
    local phase = "starting"
    local env = (getgenv and getgenv()) or _G
    local slot = "__TenshiOwnerLoadingJob"
    local ownsSlot = false
    local ok, err = pcall(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        assert(game.PlaceId == 107778070777162 or game.GameId == 10563114921, "Open Steal an Egg first")
        local players = game:GetService("Players")
        while not players.LocalPlayer do task.wait(0.2) end
        local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
        local job = tostring(game.JobId)
        if env[slot] == job or playerGui:FindFirstChild("TENSHI_FINDER_PREMIUM_PRIVATE") then return end
        env[slot] = job
        ownsSlot = true

        phase = "reading local owner access"
        local httpService = game:GetService("HttpService")
        local access = httpService:JSONDecode(readfile("Tenshi-Owner-Access.json"))
        local endpoint = access.endpoint
        local resolved, configuration = pcall(function()
            local url = "https://raw.githubusercontent.com/syss1211/Tenshi-script/main/NYX-Contabo-Config.json"
            return httpService:JSONDecode(game:HttpGet(url .. "?nyx=" .. tostring(os.time())))
        end)
        if resolved and type(configuration) == "table" then
            endpoint = configuration.endpoint
        end
        assert(type(endpoint) == "string" and endpoint:match("^https://[%w%.%-]+$"), "Invalid owner endpoint")
        assert(type(access.authorization) == "string", "Missing owner credential")

        phase = "downloading"
        local send = request or http_request or (syn and syn.request) or (http and http.request)
        assert(type(send) == "function", "Real HTTP request unavailable")
        local response = send({
            Url = endpoint .. "/v1/owner/client",
            Method = "GET",
            Timeout = 10,
            Headers = {Authorization = access.authorization},
        })
        local status = tonumber(response and (response.StatusCode or response.Status))
        assert(status == 200, "HTTP " .. tostring(status))

        phase = "starting Premium"
        local run, why = loadstring(response.Body, "Tenshi Owner Premium")
        assert(run, why)
        run()
        assert(playerGui:WaitForChild("TENSHI_FINDER_PREMIUM_PRIVATE", 5), "Premium window did not start")
        print("[Tenshi Owner] Premium opened.")
    end)
    if ownsSlot then env[slot] = nil end
    if not ok then warn("[Tenshi Owner] " .. phase .. " — " .. tostring(err)) end
end)
