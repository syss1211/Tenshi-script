task.spawn(function()
    local phase = "starting"
    local env = (getgenv and getgenv()) or _G
    local slot = "__TenshiFilmingLoadingJob"
    local ownsSlot = false
    local ok, err = pcall(function()
        if not game:IsLoaded() then game.Loaded:Wait() end
        assert(game.PlaceId == 107778070777162 or game.GameId == 10563114921, "Open Steal an Egg first")
        local players = game:GetService("Players")
        while not players.LocalPlayer do task.wait(0.2) end
        local playerGui = players.LocalPlayer:WaitForChild("PlayerGui")
        local job = tostring(game.JobId)
        if env[slot] == job then return end
        local previous = playerGui:FindFirstChild("TENSHI_FINDER_FILMING")
        if previous then previous:Destroy() end
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

        phase = "starting filming"
        local run, why = loadstring(response.Body, "Tenshi Private Filming")
        assert(run, why)
        env.__TenshiFilmingRequested=true
        local started,problem=pcall(run)
        assert(started,problem)
        assert(playerGui:WaitForChild("TENSHI_FINDER_FILMING", 5), "Filming window did not start")
        env.__TenshiFilmingRequested=nil
        print("[Tenshi Filming] Filming opened.")
    end)
    if ownsSlot then env[slot] = nil; env.__TenshiFilmingRequested=nil end
    if not ok then warn("[Tenshi Filming] " .. phase .. " — " .. tostring(err)) end
end)
