-- ✅ Auto Server Hop (Random Server with < 6 Players) + UI
local maxPlayers = 5
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local PlaceId = game.PlaceId
local JobId = game.JobId

-- 🎨 สร้าง UI แสดงจำนวนคน
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- สร้าง ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ServerHopUI"
screenGui.Parent = playerGui

-- สร้าง Frame หลัก
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 250, 0, 100)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- เพิ่ม Corner ให้มุมโค้ง
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title Label
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔄 Auto Server Hop"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = mainFrame

-- Player Count Label
local playerCountLabel = Instance.new("TextLabel")
playerCountLabel.Size = UDim2.new(1, 0, 0, 25)
playerCountLabel.Position = UDim2.new(0, 0, 0, 35)
playerCountLabel.BackgroundTransparency = 1
playerCountLabel.Text = "👥 Players: 0/" .. maxPlayers
playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
playerCountLabel.TextScaled = true
playerCountLabel.Font = Enum.Font.Gotham
playerCountLabel.Parent = mainFrame

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 25)
statusLabel.Position = UDim2.new(0, 0, 0, 65)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "✅ Server OK"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

-- ฟังก์ชันอัพเดท UI
local function updateUI(currentPlayers, status, statusColor)
    playerCountLabel.Text = "👥 Players: " .. currentPlayers .. "/" .. maxPlayers
    statusLabel.Text = status
    statusLabel.TextColor3 = statusColor
    
    -- เปลี่ยนสีของ player count ถ้าคนเยอะ
    if currentPlayers > maxPlayers then
        playerCountLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- สีแดง
    else
        playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- สีขาว
    end
end

-- 🔍 ตรวจว่าเซิร์ฟนี้คนเกินมั้ย
local function isCurrentServerTooFull()
    local currentPlayerCount = #Players:GetPlayers()
    
    local success, info = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    
    if success and info and info.data then
        for _, server in ipairs(info.data) do
            if server.id == JobId then
                updateUI(server.playing, "✅ Server OK", Color3.fromRGB(0, 255, 0))
                return server.playing > maxPlayers
            end
        end
    end
    
    -- ถ้าไม่เจอข้อมูลจาก API ใช้จำนวนคนใน client แทน
    updateUI(currentPlayerCount, "⚠️ Using Local Count", Color3.fromRGB(255, 255, 0))
    return currentPlayerCount > maxPlayers
end

-- 🌀 สุ่มเซิร์ฟจากเซิร์ฟที่คน <= maxPlayers
local function getRandomLowPopServer()
    updateUI(0, "🔍 Searching for server...", Color3.fromRGB(255, 255, 0))
    
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
            if server.id ~= JobId and server.playing <= maxPlayers then
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

-- 🔁 ตรวจทุก 5 วิ → ถ้าคนเกิน 5 ย้ายเซิร์ฟแบบสุ่ม
task.spawn(function()
    while true do
        task.wait(5)
        if isCurrentServerTooFull() then
            updateUI(0, "⚠️ Server too full! Finding new server...", Color3.fromRGB(255, 100, 100))
            print("⚠️ เซิร์ฟคนเกิน " .. maxPlayers .. " → กำลังหาสุ่มเซิร์ฟใหม่...")
            
            local newServer = getRandomLowPopServer()
            if newServer then
                updateUI(0, "🎯 Teleporting to new server...", Color3.fromRGB(100, 255, 100))
                print("🎯 ย้ายไปเซิร์ฟแบบสุ่ม:", newServer.id, "คน:", newServer.playing)
                TeleportService:TeleportToPlaceInstance(PlaceId, newServer.id, Players.LocalPlayer)
            else
                updateUI(0, "❌ No suitable server found", Color3.fromRGB(255, 0, 0))
                warn("❌ ไม่พบเซิร์ฟเวอร์ที่คน <= " .. maxPlayers)
            end
        end
    end
end)

print("🚀 Auto Server Hop เริ่มทำงานแล้ว (Max Players: " .. maxPlayers .. ")")
