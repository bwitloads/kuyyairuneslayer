wait(20)
-- Configuration variables
local webhookURLBoss = "https://discord.com/api/webhooks/1348655747684106372/MH-yAAzJun-lACrVVUW6yuGbbcGaEc6sy8364L__dcZXn5H9HwwEAFXDehd6ptKv_Gim" -- Replace with your boss hunting webhook URL
local region = game:GetService("TeleportService"):GetRegion() -- Get the server's region
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 20 -- How often to check for NPCs (in seconds)

-- Boss checks (for mob hunting)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBosses = {} -- Track bosses announced in the session

-- Function to send a message to Discord for Bosses with a 60s cooldown
local function sendWebhookMessageBoss(bossName)
    local currentTime = tick()
    
    -- Retrieve stored cooldown from player attributes
    local lastCooldown = LocalPlayer:GetAttribute(bossName .. "_Cooldown") or 0
    if foundBosses[bossName] or (currentTime - lastCooldown) < 60 then
        return 
    end

    -- Create player profile link
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
        LocalPlayer:SetAttribute(bossName .. "_Cooldown", currentTime) -- Set cooldown for this boss
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
