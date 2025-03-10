-- Load configuration from _G (default to false if not set)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

-- List of mobs to check based on settings
local mobs = {}
if ElderTreantCheck then table.insert(mobs, "Elder Treant") end
if VangarCheck then table.insert(mobs, "Vangar") end
if RuneGolemCheck then table.insert(mobs, "Rune Golem") end
if DireBearCheck then table.insert(mobs, "Dire Bear") end

wait(20) -- Initial wait before running script

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 5 -- Interval to check for NPCs (in seconds)

-- **Webhook (UNCHANGED)**
local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH"
local roleID = "1348612147592171585"

-- Track bosses already found
local foundBosses = {}

-- Function to send message to Discord
local function sendWebhookMessage(bossName)
    if foundBosses[bossName] then return end -- Prevent duplicate messages

    local playerId = LocalPlayer.UserId
    local playerProfileLink = string.format("https://roblox.com/users/%d/profile", playerId)
    local contentMessage = string.format("**Boss '%s' found in server with Job ID: %s**\nPlayer: [Roblox Profile](%s)", bossName, game.JobId, playerProfileLink)

    if bossName == "Elder Treant" then
        contentMessage = string.format("<@&%s> %s", roleID, contentMessage)
    end

    local data = { content = contentMessage }
    local jsonData = HttpService:JSONEncode(data)

    -- Handle different exploits that provide HTTP request functionality
    local requestFunction = request or http_request or syn.request
    if not requestFunction then
        print("❌ No HTTP request function found!")
        return
    end

    local response = requestFunction({
        Url = webhookURL,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonData
    })

    if response.StatusCode == 200 then
        print("✅ Webhook sent for " .. bossName)
        foundBosses[bossName] = true
    else
        print("❌ Failed to send webhook. Status Code: " .. response.StatusCode)
    end
end

-- Function to check for selected mobs in the server
local function isTargetMobPresent()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Part") then
            local lowerName = string.lower(obj.Name)
            for _, mob in ipairs(mobs) do
                if string.find(lowerName, string.lower(mob)) then
                    print("✅ " .. mob .. " FOUND!")
                    sendWebhookMessage(mob)
                    if mob == "Elder Treant" then
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

    local serversData = game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")
    local servers = HttpService:JSONDecode(serversData).data
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
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10)
        hopServer()
    end
end

-- Main loop
while true do
    wait(CheckInterval)
    if isTargetMobPresent() then
        if workspace:FindFirstChild("Elder Treant") then
            break -- Stop if Elder Treant is found
        end
    else
        hopServer()
    end
end
