-- ✅ Auto Server Hop (Random Server with < 10 Players)
local hopInterval = 300
local maxPlayers = 10

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local PlaceId = game.PlaceId
local JobId = game.JobId

-- 🔍 ตรวจว่าเซิร์ฟนี้คนเกินมั้ย
local function isCurrentServerTooFull()
    local success, info = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)

    if success and info and info.data then
        for _, server in ipairs(info.data) do
            if server.id == JobId then
                return server.playing > maxPlayers
            end
        end
    end
    return false
end

-- 🌀 สุ่มเซิร์ฟจากเซิร์ฟที่คน < maxPlayers
local function getRandomLowPopServer()
    local cursor = ""
    local candidateServers = {}
    local baseUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s"

    for _ = 1, 5 do
        local url = string.format(baseUrl, PlaceId, cursor)
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if not success or not result or not result.data then break end

        for _, server in ipairs(result.data) do
            if server.id ~= JobId and server.playing < maxPlayers then
                table.insert(candidateServers, server)
            end
        end

        if not result.nextPageCursor then break end
        cursor = result.nextPageCursor
        task.wait(0.5)
    end

    if #candidateServers > 0 then
        return candidateServers[math.random(1, #candidateServers)]
    end

    return nil
end

-- 🔁 ตรวจทุก 5 วิ → ถ้าคนเยอะ ย้ายเซิร์ฟแบบสุ่ม
task.spawn(function()
    while true do
        task.wait(5)
        if isCurrentServerTooFull() then
            print("⚠️ เซิร์ฟคนเยอะเกิน " .. maxPlayers .. " → กำลังหาสุ่มเซิร์ฟใหม่...")
            local newServer = getRandomLowPopServer()
            if newServer then
                print("🎯 ย้ายไปเซิร์ฟแบบสุ่ม:", newServer.id, "คน:", newServer.playing)
                TeleportService:TeleportToPlaceInstance(PlaceId, newServer.id, Players.LocalPlayer)
            else
                warn("❌ ไม่พบเซิร์ฟเวอร์ที่คน < " .. maxPlayers)
            end
        else
            print("✅ เซิร์ฟนี้โอเค → รออีก " .. hopInterval .. " วินาที")
            task.wait(hopInterval)
        end
    end
end)
