-- Load configuration from _G (defaults to false if not set)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBossesInServer = {} -- Track bosses announced in the current server
local sentJobIDs = {} -- Store job IDs to ensure webhook is sent only once per server

wait(20) -- Wait 20 seconds before starting the script 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 5 -- How often to check for NPCs (in seconds)

local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH" 
local roleID = "1348612147592171585"

-- Function to send a message to Discord (only once per server, based on job ID)
local function sendWebhookMessage(bossName)
    local currentJobId = game.JobId
    -- Only send the webhook if we haven't already sent one for the current job ID
    if sentJobIDs[currentJobId] then
        return
    end

    -- Format the content message
    local playerId = LocalPlayer.UserId
    local playerProfileLink = string.format("https://roblox.com/users/%d/profile", playerId)
    local contentMessage = string.format("**Boss '%s' found in server with Job ID: %s**\nPlayer: [Roblox Profile](%s)", bossName, currentJobId, playerProfileLink)

    if bossName == "Elder Treant" then
        contentMessage = string.format("<@&%s> %s", roleID, contentMessage)
    end

    local data = { content = contentMessage }
    local jsonData = HttpService:JSONEncode(data)

    local response = http_request({
        Url = webhookURL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonData
    })

    if response.StatusCode == 200 then
        print("✅ Webhook sent successfully for " .. bossName)
        foundBossesInServer[bossName] = true -- Mark boss as announced in this server
        sentJobIDs[currentJobId] = true -- Store the job ID to prevent sending duplicate webhooks for this server
    else
        print("❌ Error sending webhook. Status Code: " .. response.StatusCode)
    end
end

-- Function to check for selected mobs in the server
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
                    if mob.name == "Elder Treant" then
                        return true -- Stop hopping if Elder Treant is found
                    end
                end
            end
        end
    end
    return false
end

-- Function to hop servers
local function hopServer()
    print("🔍 Searching for a new server with 3-8 players...")

    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
    local suitableServers = {}

    for _, server in pairs(servers) do
        if server.playing >= 3 and server.playing <= 8 and server.id ~= game.JobId then
            table.insert(suitableServers, server)
        end
    end

    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("🌍 Hopping to server: " .. serverToJoin.id)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)

        -- Reset state only after hopping to a new server
        sentJobIDs = {} -- Clear all job ID tracking for the new server
        foundBossesInServer = {} -- Clear all boss announcements for the new server
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10)
        hopServer()
    end
end

-- Main Loop
while true do
    wait(CheckInterval)
    if isTargetMobPresent() then
        if workspace:FindFirstChild("Elder Treant") then
            break
        end
    else
        hopServer()
    end
end
