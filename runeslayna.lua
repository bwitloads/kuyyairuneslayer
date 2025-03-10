wait(20)

-- Configuration variables
local webhookURLPlayer = "https://discord.com/api/webhooks/1348655747684106372/MH-yAAzJun-lACrVVUW6yuGbbcGaEc6sy8364L__dcZXn5H9HwwEAFXDehd6ptKv_Gim" -- Replace with your player faction rank webhook URL
local webhookURLBoss = "https://discord.com/api/webhooks/1348655747684106372/MH-yAAzJun-lACrVVUW6yuGbbcGaEc6sy8364L__dcZXn5H9HwwEAFXDehd6ptKv_Gim" -- Replace with your boss hunting webhook URL
local region = game:GetService("TeleportService"):GetRegion() -- Get the server's region
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 20 -- How often to check for NPCs (in seconds)

-- Faction ranks
local demonRanks = {
    "Acolyte", "Reaver", "Dread Sergeant", "Bloodbound Sergeant", "Blightbringer",
    "Dark Knight", "Hellforged Lieutenant", "Void Captain", "Abyss Champion", 
    "Riftborn Commander", "Doombringer", "Infernal Marshal", "Blight Marshal", "Void Marshal"
}
local knightRanks = {
    "Private", "Corporal", "Sergeant", "Master Sergeant", "Sergeant Major", "Knight", 
    "Knight Lieutenant", "Knight Captain", "Knight Champion", "Lieutenant Commander", 
    "Commander", "Marshal", "Field Marshal", "Holy Marshal"
}

-- Initialize counters for faction ranks
local demonCounts = {lowRanks = 0, lastRanks = {0, 0, 0, 0, 0}} -- Count for the last 5 ranks and others
local knightCounts = {lowRanks = 0, lastRanks = {0, 0, 0, 0, 0}} -- Count for the last 5 ranks and others

-- Boss checks (for mob hunting)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBosses = {} -- Track bosses announced in the session
local lastWebhookTime = 0 -- Track last webhook send time

-- Function to count players by faction and rank
local function countPlayerFactionRanks()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("Faction") and player.Character:FindFirstChild("Rank") then
            local faction = player.Character.Faction.Value
            local rank = player.Character.Rank.Value
            
            -- Count for Demon Sect
            if faction == "Demon Sect" then
                local rankIndex = table.find(demonRanks, rank)
                if rankIndex then
                    if rankIndex > 8 then
                        demonCounts.lastRanks[rankIndex - 8] = demonCounts.lastRanks[rankIndex - 8] + 1
                    else
                        demonCounts.lowRanks = demonCounts.lowRanks + 1
                    end
                end
            -- Count for Knights Templar
            elseif faction == "Knights Templar" then
                local rankIndex = table.find(knightRanks, rank)
                if rankIndex then
                    if rankIndex > 8 then
                        knightCounts.lastRanks[rankIndex - 8] = knightCounts.lastRanks[rankIndex - 8] + 1
                    else
                        knightCounts.lowRanks = knightCounts.lowRanks + 1
                    end
                end
            end
        end
    end
end

-- Function to send a message to the Discord webhook
local function sendWebhookMessagePlayer()
    -- Count players
    countPlayerFactionRanks()

    -- Create the message for the webhook
    local message = string.format("Server Region: %s\n", region)

    -- Demon Sect Message
    message = message .. "\n**Demon Sect Counts**\n"
    message = message .. string.format("Low Ranks (Acolyte to Blightbringer): %d\n", demonCounts.lowRanks)
    for i = 1, 5 do
        message = message .. string.format("Rank %s: %d\n", demonRanks[9 + i], demonCounts.lastRanks[i])
    end

    -- Knights Templar Message
    message = message .. "\n**Knights Templar Counts**\n"
    message = message .. string.format("Low Ranks (Private to Knight): %d\n", knightCounts.lowRanks)
    for i = 1, 5 do
        message = message .. string.format("Rank %s: %d\n", knightRanks[9 + i], knightCounts.lastRanks[i])
    end

    -- Webhook payload
    local data = {
        content = message
    }
    
    local jsonData = HttpService:JSONEncode(data)
    
    -- Send the POST request
    local response = http_request({
        Url = webhookURLPlayer,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonData
    })

    -- Check if webhook was sent successfully
    if response.StatusCode == 200 then
        print("✅ Webhook sent successfully.")
    else
        print("❌ Error sending webhook. Status Code: " .. response.StatusCode)
    end
end

-- Function to send a message to Discord with a 60s cooldown (for boss hunting)
local function sendWebhookMessageBoss(bossName)
    local currentTime = tick()
    if foundBosses[bossName] or (currentTime - lastWebhookTime) < 60 then 
        return 
    end -- Prevent duplicate messages & enforce 60s delay

    local playerId = LocalPlayer.UserId
    local playerProfileLink = string.format("https://roblox.com/users/%d/profile", playerId)
    local contentMessage = string.format("**Boss '%s' found in server with Job ID: %s**\nPlayer: [Roblox Profile](%s)", bossName, game.JobId, playerProfileLink)

    if bossName == "Elder Treant" then
        contentMessage = string.format("<@&%s> %s", roleID, contentMessage)
    end

    local data = { content = contentMessage }
    local jsonData = HttpService:JSONEncode(data)

    local response = http_request({
        Url = webhookURLBoss,
        Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = jsonData
    })

    if response.StatusCode == 200 then
        print("✅ Webhook sent successfully for " .. bossName)
        foundBosses[bossName] = true -- Mark boss as announced
        lastWebhookTime = tick() -- Update last webhook send time
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
                if mob.enabled and not foundBosses[mob.name] and string.find(lowerName, string.lower(mob.name)) then
                    print("✅ " .. mob.name .. " FOUND!")
                    sendWebhookMessageBoss(mob.name)
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
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10)
        hopServer()
    end
end

-- Main Loop for Player Factions
sendWebhookMessagePlayer()

-- Main Loop for Mob Hunting
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
