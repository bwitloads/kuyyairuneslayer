wait(15)
-- Load configuration from _G (defaults to false if not set)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBossesInServer = {}
local sentJobIDs = {}

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH" 
local roleID = "1348612147592171585"

-- Function to send a webhook message when a boss is found
local function sendWebhookMessage(bossName)
    local currentJobId = game.JobId

    -- Prevent duplicate messages for the same server
    if sentJobIDs[currentJobId] then
        return
    end

    local playerId = LocalPlayer.UserId
    local playerProfileLink = string.format("https://roblox.com/users/%d/profile", playerId)
    local contentMessage = string.format("**Boss '%s' found in server with Job ID: %s**\nPlayer: [Roblox Profile](%s)", bossName, currentJobId, playerProfileLink)

    if bossName == "Elder Treant" then
        contentMessage = string.format("<@&%s> %s", roleID, contentMessage)
    end

    local data = { content = contentMessage }
    local jsonData = HttpService:JSONEncode(data)

    local success, response = pcall(function()
        return http_request({
            Url = webhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })
    end)

    if success and response and response.StatusCode == 200 then
        print("✅ Webhook sent for " .. bossName)
        foundBossesInServer[bossName] = true
        sentJobIDs[currentJobId] = true
    else
        print("❌ Webhook error. Response:", response and response.StatusCode or "Unknown")
    end
end

-- Function to check for target mobs in the server
local function isTargetMobPresent()
    local mobs = {
        { name = "Vangar", enabled = VangarCheck },
        { name = "Elder Treant", enabled = ElderTreantCheck },
        { name = "Rune Golem", enabled = RuneGolemCheck },
        { name = "Dire Bear", enabled = DireBearCheck }
    }

    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Part") then
            local lowerName = string.lower(obj.Name)
            for _, mob in ipairs(mobs) do
                if mob.enabled and not foundBossesInServer[mob.name] and string.find(lowerName, string.lower(mob.name)) then
                    print("✅ " .. mob.name .. " FOUND!")
                    sendWebhookMessage(mob.name)
                    return true -- Stop after finding the first boss
                end
            end
        end
    end
    return false
end

-- Improved function to fetch all available servers
local function fetchAllServers()
    local servers = {}
    local cursor = nil
    local baseUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local retries = 3

    while retries > 0 do
        local url = baseUrl
        if cursor then
            url = url .. "&cursor=" .. cursor
        end

        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if success and result and result.data then
            for _, server in ipairs(result.data) do
                table.insert(servers, server)
            end
            cursor = result.nextPageCursor
            if not cursor then break end -- No more pages left
        else
            print("❌ Failed to fetch servers. Retrying...")
            retries = retries - 1
            wait(5) -- Wait before retrying
            if retries == 0 then
                print("❌ Could not retrieve servers after multiple attempts.")
                break
            end
        end
    end

    return servers
end

-- Function to hop servers
local function hopServer()
    print("🔍 Searching for a new server with 3-10 players...")

    local servers = fetchAllServers()
    if not servers or #servers == 0 then
        print("❌ No servers found. Joining any available server...")
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
        return
    end

    local suitableServers = {}
    for _, server in ipairs(servers) do
        if server.playing >= 3 and server.playing <= 10 and server.id ~= game.JobId then
            table.insert(suitableServers, server)
        end
    end

    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("🌍 Hopping to suitable server: " .. serverToJoin.id)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)
    else
        print("❌ No suitable servers found. Joining any available server...")
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

-- Main Loop
while true do
    if isTargetMobPresent() then
        print("Boss found. Webhook sent. Stopping for this server.")
        break
    else
        hopServer()
    end
    wait(300) -- Wait 5 minutes before checking again
end
