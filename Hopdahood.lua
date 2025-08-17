-- ✅ Auto Server Hop (เวอร์ชันปรับปรุง) + UI
local maxPlayers = 5
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local PlaceId = game.PlaceId
local JobId = game.JobId

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 🎨 สร้าง UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ServerHopUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔄 Auto Server Hop"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

local playerCountLabel = Instance.new("TextLabel")
playerCountLabel.Size = UDim2.new(1, 0, 0, 25)
playerCountLabel.Position = UDim2.new(0, 0, 0, 35)
playerCountLabel.BackgroundTransparency = 1
playerCountLabel.Text = "👥 Players: 0/" .. maxPlayers
playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
playerCountLabel.TextScaled = true
playerCountLabel.Font = Enum.Font.Gotham
playerCountLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 25)
statusLabel.Position = UDim2.new(0, 0, 0, 65)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "✅ Server OK"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- อัปเดท UI
local function updateUI(currentPlayers, status, statusColor)
    playerCountLabel.Text = "👥 Players: " .. currentPlayers .. "/" .. maxPlayers
    statusLabel.Text = status
    statusLabel.TextColor3 = statusColor
    playerCountLabel.TextColor3 = currentPlayers > maxPlayers and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
end

-- ตรวจเซิร์ฟปัจจุบัน
local function isCurrentServerTooFull()
    local currentPlayerCount = #Players:GetPlayers()
    local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"

    local success, result = pcall(function()
        return HttpService:GetAsync(url)
    end)

    if success then
        local data = HttpService:JSONDecode(result)
        for _, server in ipairs(data.data or {}) do
            if server.id == JobId then
                updateUI(server.playing, "✅ Server OK", Color3.fromRGB(0, 255, 0))
                return server.playing > maxPlayers
            end
        end
    end

    updateUI(currentPlayerCount, "⚠️ Using Local Count", Color3.fromRGB(255, 255, 0))
    return currentPlayerCount > maxPlayers
end

-- หาเซิร์ฟใหม่ที่คนน้อย
local function getRandomLowPopServer()
    updateUI(0, "🔍 Searching for server...", Color3.fromRGB(255, 255, 0))
    local cursor = ""
    local candidateServers = {}
    local baseUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s"

    for _ = 1, 3 do
        local url = string.format(baseUrl, PlaceId, cursor)
        local success, response = pcall(HttpService.GetAsync, HttpService, url)
        if not success or not response then break end

        local data = HttpService:JSONDecode(response)
        for _, server in ipairs(data.data or {}) do
            if server.id ~= JobId and server.playing <= maxPlayers then
                table.insert(candidateServers, server)
            end
        end

        if not data.nextPageCursor then break end
        cursor = data.nextPageCursor
        task.wait(0.5)
    end

    return #candidateServers > 0 and candidateServers[math.random(#candidateServers)] or nil
end

-- ย้ายเซิร์ฟ
local lastTeleport = 0
local function attemptTeleport()
    if tick() - lastTeleport < 10 then return end -- cooldown

    updateUI(0, "⚠️ Server too full! Finding new server...", Color3.fromRGB(255, 100, 100))
    print("⚠️ เซิร์ฟคนเกิน " .. maxPlayers .. " → กำลังหาสุ่มเซิร์ฟใหม่...")

    local newServer = getRandomLowPopServer()
    if newServer then
        updateUI(newServer.playing, "🎯 Teleporting...", Color3.fromRGB(100, 255, 100))
        print("🎯 ย้ายไปเซิร์ฟ:", newServer.id, "| คน:", newServer.playing)
        lastTeleport = tick()
        TeleportService:TeleportToPlaceInstance(PlaceId, newServer.id, player)
    else
        updateUI(0, "❌ No low-pop server found", Color3.fromRGB(255, 0, 0))
        warn("❌ ไม่พบเซิร์ฟเวอร์ที่คน <= " .. maxPlayers)
    end
end

-- ตรวจทุก 5 วินาที
task.spawn(function()
    while true do
        task.wait(5)
        if isCurrentServerTooFull() then
            attemptTeleport()
        end
    end
end)

-- ตรวจเมื่อมีคนเข้า/ออก
Players.PlayerAdded:Connect(function()
    task.spawn(isCurrentServerTooFull)
end)
Players.PlayerRemoving:Connect(function()
    task.spawn(isCurrentServerTooFull)
end)

print("🚀 Auto Server Hop เริ่มทำงานแล้ว (Max Players: " .. maxPlayers .. ")")
