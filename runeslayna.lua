wait(20) -- Wait 20 seconds before starting the script 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local CheckInterval = 5 -- How often to check for NPCs (in seconds)

local webhookURL = "https://discord.com/api/webhooks/1348572811077357598/vJZzkEdK0xUTuyRGqpSd1Bj2dq8ppPtGrT52XunQaLEUyDWk8eO6EYYSldKKwUevq8zH" -- Webhook URL
local roleID = "1348612147592171585" -- Role ID to ping (for Elder Treant)

-- Table to track bosses already found in the current session
local foundBosses = {}

-- Default configuration (You can override this outside the script)
local VangarCheck = true
local ElderTreantCheck = true
local DireBearCheck = true
local RuneGolemCheck = true  -- Set to true to check for Rune Golem

-- Get customizable values passed from the outside (query string)
local function getConfigFromQuery()
    local query = game:GetService("HttpService"):UrlDecode(game:GetService("Players").LocalPlayer.Name) -- Get the URL query (example query)
    local config = {}

    -- Check if the query contains specific parameters and set the flags
    if string.find(query, "DireBear=false") then
        config.DireBearCheck = false
    end
    if string.find(query, "Vangar=false") then
        config.VangarCheck = false
    end
    if string.find(query, "elder=false") then
        config.ElderTreantCheck = false
    end
    if string.find(query, "Runegolem=false") then
        config.RuneGolemCheck = false
    end

    -- Apply configuration overrides if any
    VangarCheck = config.VangarCheck or VangarCheck
    ElderTreantCheck = config.ElderTreantCheck or ElderTreantCheck
    DireBearCheck = config.DireBearCheck or DireBearCheck
    RuneGolemCheck = config.RuneGolemCheck or RuneGolemCheck
end

getConfigFromQuery() -- Call function to apply external configuration

-- Function to send a message to the Discord webhook with job ID, boss name, and player info
local function sendWebhookMessage(bossName)
    -- Check if the boss has already been found in this server
    if foundBosses[bossName] then
        return -- If boss was already found, exit the function to prevent duplicates
    end

    -- Getting the player's UserId and creating their profile link
    local playerId = LocalPlayer.UserId
    local playerProfileLink = string.format("https://roblox.com/users/%d/profile", playerId)

    -- Check if the boss is Elder Treant and apply bold formatting
    local bossMessage = bossName
    local contentMessage = string.format("**Boss '%s' found in server with Job ID: %s**\nPlayer who found it: [Roblox Profile](%s)", bossMessage, game.JobId, playerProfileLink)

    -- If the boss is Elder Treant, mention the role
    if bossName == "Elder Treant" then
        contentMessage = string.format("<@&%s> %s", roleID, contentMessage) -- Mention the role for Elder Treant
    end

    -- Create the data payload
    local data = {
        content = contentMessage
    }

    -- Convert the data to JSON format
    local jsonData = HttpService:JSONEncode(data)

    -- Send the POST request using http_request (works in most exploits)
    local response = http_request({
        Url = webhookURL,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = jsonData
    })

    -- Check if the request was successful
    if response.StatusCode == 200 then
        print("Webhook sent successfully for " .. bossName)
        -- Mark this boss as found
        foundBosses[bossName] = true
    else
        print("Error sending webhook. Status Code: " .. response.StatusCode)
    end
end

-- Function to check if any of the target mobs exist in the server
local function isTargetMobPresent()
    local mobs = {}
    -- Add to the list of mobs to check based on the configuration
    if VangarCheck then
        table.insert(mobs, "Vangar")
    end
    if ElderTreantCheck then
        table.insert(mobs, "Elder Treant")
    end
    if DireBearCheck then
        table.insert(mobs, "Dire Bear")
    end
    if RuneGolemCheck then
        table.insert(mobs, "Rune Golem")
    end
    
    -- Loop through workspace and check for target mobs
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("Part") then
            local lowerName = string.lower(obj.Name)
            for _, mob in ipairs(mobs) do
                if string.find(lowerName, string.lower(mob)) then
                    print("✅ " .. mob .. " FOUND!")
                    sendWebhookMessage(mob) -- Send the webhook message with Job ID and boss name
                    if mob == "Elder Treant" then
                        return true -- If Elder Treant is found, stop searching for other mobs
                    end
                end
            end
        end
    end
    return false -- No Elder Treant found, continue hopping
end

-- Function to find and join a new server (3-8 players only)
local function hopServer()
    print("🔍 Searching for a new server with 3-8 players...")

    local servers = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data
    local suitableServers = {}

    -- Find servers with 3-8 players
    for _, server in pairs(servers) do
        if server.playing >= 3 and server.playing <= 8 and server.id ~= game.JobId then
            table.insert(suitableServers, server)
        end
    end

    -- If suitable servers are found, hop to one
    if #suitableServers > 0 then
        local serverToJoin = suitableServers[math.random(1, #suitableServers)]
        print("🌍 Hopping to server: " .. serverToJoin.id)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverToJoin.id, LocalPlayer)
    else
        print("❌ No suitable servers found. Retrying in 10 seconds...")
        wait(10) -- Wait before retrying
        hopServer() -- Retry server hopping
    end
end

-- Main Loop: Keep hopping until Elder Treant is found
while true do
    wait(CheckInterval)

    if isTargetMobPresent() then
        if workspace:FindFirstChild("Elder Treant") then
            break -- Stop hopping if Elder Treant is found
        end
    else
        hopServer() -- Hop to a new server if no mobs are found
    end
end
