wait(10)
-- Load configuration from _G (defaults to false if not set)
local VangarCheck = _G.VangarCheck or false
local ElderTreantCheck = _G.ElderTreantCheck or false
local DireBearCheck = _G.DireBearCheck or false
local RuneGolemCheck = _G.RuneGolemCheck or false

local foundBossesInServer = {} -- Track bosses announced in the current server
local sentJobIDs = {} -- Store job IDs to ensure webhook is sent only once per server

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH" 
local roleID = "1348612147592171585"

-- Function to send a message to Discord (only once per server, based on job ID)
local function sendWebhookMessage(bossName)
    local currentJobId = game.JobId

    -- Check if the webhook for this job ID has already been sent
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
        foundBossesInServer[bossName] = true -- Mark boss as announced in this server
        sentJobIDs[currentJobId] = true -- Store the job ID to prevent sending duplicate webhooks for this server
    else
        print("❌ Error sending webhook. Response:", response and response.StatusCode or "Unknown")
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
                    return true -- Only send once per server and stop after the first boss is found
                end
            end
        end
    end
    return false
end

-- Function to get a list of available servers
local function getServerList()
    local servers = {}
    local nextCursor = nil
    local retryLimit = 3
    local retries = 0

    repeat
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" .. (nextCursor and "&cursor=" .. nextCursor or ""), true))
        end)

        if success and result and result.data then
            -- Filter servers with valid player counts and different Job IDs
            for _, server in pairs(result.data) do
                if server.id ~= game.JobId and server.playing >= 3 and server.playing <= 8 then
                    table.insert(servers, server)
                end
            end
            if #servers > 0 then
                return servers
            else
                print("❌ No suitable servers found in this batch.")
            end
        else
            retries = retries + 1
            print("❌ Failed to fetch server list. Retrying... (" .. retries .. "/" .. retryLimit .. ")")
            wait(10)
        end
    until retries >= retryLimit

    -- Return empty if no servers were found after retries
    return servers
end

-- Function to hop servers
local function hopServer()
    print("🔍 Searching for a new server with 3-10 players...")

    local suitableServers = getServerList()

    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("🌍 Hopping to server: " .. serverToJoin.id)
        -- Attempt to teleport to the selected server
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)
        end)

        if not success then
            print("❌ Error while teleporting: " .. err)
        end
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10)
        hopServer()
    end
end

-- Main Loop
while true do
    if isTargetMobPresent() then
        print("Boss found and webhook sent. Stopping for this server.")
        break -- Stop after finding and sending the webhook for the first boss
    else
        hopServer() -- Hop to a new server if no boss found
    end
    wait(300) -- Wait 5 minutes before checking again after a hop
end
