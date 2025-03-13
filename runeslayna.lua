wait(10)
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

-- Function to fetch all servers
local function fetchAllServers()
    local servers = {}
    local cursor = nil
    local baseUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local retries = 3

    while true do
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
            wait(5)
            retries = retries - 1
            if retries == 0 then
                print("❌ Could not retrieve servers. Returning empty list.")
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
    hopServer()
    wait(300) -- Wait 5 minutes before checking again
end
