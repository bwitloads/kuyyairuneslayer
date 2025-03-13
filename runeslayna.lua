wait(10)

-- ✅ Load configurations
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBossesInServer = {} -- Track bosses announced in the current server
local sentJobIDs = {} -- Store job IDs to prevent duplicate webhooks

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH" 
local roleID = "1348612147592171585"

-- ✅ Function to send webhook message to Discord
local function sendWebhookMessage(bossName)
    local currentJobId = game.JobId

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
        print("✅ Webhook sent successfully for " .. bossName)
        foundBossesInServer[bossName] = true
        sentJobIDs[currentJobId] = true
    else
        print("❌ Error sending webhook. Response:", response and response.StatusCode or "Unknown")
    end
end

-- ✅ Function to check for selected mobs in the server
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
                    return true
                end
            end
        end
    end
    return false
end

-- ✅ Function to fetch server list with pagination
local function getServerList()
    local servers = {}
    local nextCursor = nil

    repeat
        wait(5) -- Small delay to avoid rate limits
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (nextCursor and "&cursor=" .. nextCursor or "")
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url, true))
        end)

        if success and result and result.data then
            for _, server in pairs(result.data) do
                if server.id ~= game.JobId and server.playing >= 3 and server.playing <= 10 then
                    table.insert(servers, server)
                end
            end
            nextCursor = result.nextPageCursor
        else
            print("❌ Failed to fetch server list. Retrying in 30 seconds...")
            wait(30)
        end
    until not nextCursor

    return servers
end

-- ✅ Function to hop to a new server
local function hopServer()
    print("🔍 Searching for a new server with 3-10 players...")

    local servers = getServerList()

    if #servers > 0 then
        local serverToJoin = servers[math.random(1, #servers)]
        print("🌍 Hopping to server: " .. serverToJoin.id)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)

        -- Reset tracking for the new server
        sentJobIDs = {}
        foundBossesInServer = {}
    else
        print("❌ No suitable servers found. Retrying in 30 seconds...")
        wait(30)
        return hopServer()
    end
end

-- ✅ Main Loop
while true do
    if isTargetMobPresent() then
        print("Boss found and webhook sent. Stopping for this server.")
        break
    else
        hopServer()
    end
    wait(300) -- Wait 5 minutes before checking again
end
