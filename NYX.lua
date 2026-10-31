-- NYX Egg Finder V5.1 - startup diagnostics and mobile UI repair.
-- Rarity matches are guesses based on client-visible names/attributes.
-- A zero count does not prove that no rare eggs exist.
-- GitHub hosting changes delivery only; it cannot fix runtime errors.

local stage = "startup"
local gui, status

local function traceback(err)
    return debug.traceback(tostring(err), 2)
end

local function report(err)
    local message = "[NYX V5.1][" .. stage .. "] " .. tostring(err)
    warn(message)
    if status and status.Parent then
        status.Text = "ERROR: " .. tostring(err)
    end
end

print("[NYX V5.1] START")
local ok, err = xpcall(function()
    stage = "client"
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local player = Players.LocalPlayer
    assert(player, "LocalPlayer unavailable; run after joining the game")

    stage = "PlayerGui"
    local parent = player:WaitForChild("PlayerGui", 15)
    assert(parent, "PlayerGui was not ready after 15 seconds; rejoin and retry")

    -- Only replace our own UI. CoreGui cleanup is optional and protected.
    local old = parent:FindFirstChild("NYX_V5")
    if old then old:Destroy() end
    pcall(function()
        local core = game:GetService("CoreGui")
        for _, name in ipairs({ "NYX_V4", "NYX_V5" }) do
            local previous = core:FindFirstChild(name)
            if previous then previous:Destroy() end
        end
    end)

    stage = "UI"
    gui = Instance.new("ScreenGui")
    gui.Name = "NYX_V5"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = parent

    local panel = Instance.new("Frame")
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.fromScale(0.5, 0.16)
    panel.Size = UDim2.new(0.86, 0, 0, 150)
    panel.BackgroundColor3 = Color3.fromRGB(28, 20, 40)
    panel.Parent = gui
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(380, 150)
    limit.Parent = panel
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 30)
    title.Position = UDim2.fromOffset(8, 2)
    title.BackgroundTransparency = 1
    title.Text = "NYX V5.1 | EGG FINDER"
    title.TextColor3 = Color3.fromRGB(210, 165, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = panel

    status = Instance.new("TextLabel")
    status.Position = UDim2.fromOffset(8, 34)
    status.Size = UDim2.new(1, -16, 0, 56)
    status.BackgroundTransparency = 1
    status.TextColor3 = Color3.new(1, 1, 1)
    status.TextSize = 14
    status.TextWrapped = true
    status.Text = "UI READY - initializing scanner..."
    status.Parent = panel

    local button = Instance.new("TextButton")
    button.Position = UDim2.fromOffset(8, 98)
    button.Size = UDim2.new(1, -16, 0, 44)
    button.BackgroundColor3 = Color3.fromRGB(90, 35, 150)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.TextSize = 17
    button.Text = "FIND RARE EGGS"
    button.Parent = panel
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)

    local visuals = Instance.new("Folder")
    visuals.Name = "Visuals"
    visuals.Parent = gui
    local tracked = {}
    local busy, enabled = false, false
    local maxMarkers = 30
    local rareWords = {
        "celestial", "legendary", "rainbow", "secret", "mythic",
        "divine", "godly", "epic", "rare",
    }

    local function matchWord(text)
        -- Token boundaries prevent "rare" matching "notrare" or "rarest".
        text = string.lower(text):gsub("[^%a%d]", " ")
        for _, word in ipairs(rareWords) do
            if (" " .. text .. " "):find(" " .. word .. " ", 1, true) then
                return word
            end
        end
    end

    local function getRarity(obj)
        local rarity = matchWord(obj.Name)
        if rarity then return rarity end
        for key, value in pairs(obj:GetAttributes()) do
            local name = string.lower(key)
            -- Do not infer rarity from a key with a false value.
            if value == true then
                local flag = name:gsub("^is", "")
                for _, word in ipairs(rareWords) do
                    if flag == word then return word end
                end
            elseif type(value) == "string" and
                (name == "rarity" or name == "tier" or name == "rarityname") then
                rarity = matchWord(value)
                if rarity then return rarity end
            end
        end
    end

    local function getPart(obj)
        if obj:IsA("BasePart") then return obj end
        if obj:IsA("Model") then
            return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
        end
    end

    local function clear()
        visuals:ClearAllChildren()
        table.clear(tracked)
        enabled = false
    end

    local function addESP(obj, rarity, part)
        local highlight = Instance.new("Highlight")
        highlight.Adornee = obj
        highlight.FillColor = Color3.fromRGB(255, 45, 110)
        highlight.OutlineColor = Color3.new(1, 1, 1)
        highlight.FillTransparency = 0.45
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = visuals

        local billboard = Instance.new("BillboardGui")
        billboard.Adornee = part
        billboard.Size = UDim2.fromOffset(210, 55)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = visuals

        local label = Instance.new("TextLabel")
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 100, 160)
        label.TextStrokeTransparency = 0
        label.TextSize = 14
        label.TextWrapped = true
        label.Font = Enum.Font.GothamBold
        label.Text = obj.Name .. " [" .. string.upper(rarity) .. "]"
        label.Parent = billboard
        tracked[obj] = { part = part, label = label, billboard = billboard,
            highlight = highlight, rarity = rarity }
    end

    button.Activated:Connect(function()
        if busy or not gui.Parent then return end
        if enabled then
            clear()
            button.Text = "FIND RARE EGGS"
            status.Text = "ESP OFF - tap to scan again"
            return
        end
        busy = true
        button.Text = "SCANNING..."
        status.Text = "Getting client-visible objects..."
        task.spawn(function()
            stage = "scan"
            local scanOK, scanError = xpcall(function()
                clear()
                local eggs, rare, markers = 0, 0, 0
                local candidates, candidateSet = {}, {}
                local objects = Workspace:GetDescendants()
                -- First gather matches, then attach visuals; traversal order
                -- must not create duplicate markers for a model and its parts.
                for index, obj in ipairs(objects) do
                    if not gui.Parent then return end
                    if (obj:IsA("Model") or obj:IsA("BasePart")) and
                        string.find(string.lower(obj.Name), "egg", 1, true) then
                        eggs += 1
                        local rarity, part = getRarity(obj), getPart(obj)
                        if rarity and part then
                            candidateSet[obj] = true
                            table.insert(candidates, { obj, rarity, part })
                        end
                    end
                    if index % 200 == 0 then
                        status.Text = "SCANNED: " .. index .. " / " .. #objects
                        task.wait()
                    end
                end
                for index, entry in ipairs(candidates) do
                    if not gui.Parent then return end
                    local obj, rarity, part = entry[1], entry[2], entry[3]
                    local ancestor, duplicate = obj.Parent, false
                    while ancestor and ancestor ~= Workspace do
                        if candidateSet[ancestor] then duplicate = true; break end
                        ancestor = ancestor.Parent
                    end
                    if not duplicate and obj:IsDescendantOf(Workspace) and
                        part:IsDescendantOf(Workspace) then
                        rare += 1
                        if markers < maxMarkers then
                            addESP(obj, rarity, part)
                            markers += 1
                        end
                    end
                    if index % 30 == 0 then task.wait() end
                end
                enabled = true
                status.Text = string.format("EGG OBJECTS: %d | RARE GUESSES: %d\nMARKERS: %d (max %d)",
                    eggs, rare, markers, maxMarkers)
                button.Text = "ESP ON | TAP TO CLEAR"
            end, traceback)
            busy = false
            if not scanOK then
                clear()
                report(scanError)
                if gui.Parent then button.Text = "RETRY SCAN" end
            end
        end)
    end)

    -- One update worker, stopped when this UI is replaced or destroyed.
    task.spawn(function()
        while gui.Parent do
            local updateOK, updateError = xpcall(function()
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                for obj, data in pairs(tracked) do
                    if not obj:IsDescendantOf(Workspace) or
                        not data.part:IsDescendantOf(Workspace) then
                        data.highlight:Destroy()
                        data.billboard:Destroy()
                        tracked[obj] = nil
                    else
                        local suffix = root and ("\n" .. math.floor(
                            (root.Position - data.part.Position).Magnitude) .. " studs") or ""
                        data.label.Text = obj.Name .. " [" .. string.upper(data.rarity) .. "]" .. suffix
                    end
                end
            end, traceback)
            if not updateOK then
                warn("[NYX V5.1][distance update] " .. tostring(updateError))
                break
            end
            task.wait(0.5)
        end
    end)

    stage = "ready"
    status.Text = "READY - tap FIND RARE EGGS\nName/attribute guesses only; scan again for new spawns."
    print("[NYX V5.1] READY - PlayerGui")
end, traceback)

if not ok then report(err) end
