-- ✅ Auto Server Hop (เวอร์ชันง่าย + UI)
local CONFIG = {
    maxPlayers = 5,
    checkInterval = 5, -- วินาที
    teleportCooldown = 10, -- วินาที
    findBy = "playing" -- "playing" = คนน้อย, "ping" = ping ต่ำ
}

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local PlaceId = game.PlaceId
local JobId = game.JobId

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ตัวแปรสำหรับควบคุม
local lastTeleport = 0

-- 🎨 สร้าง UI แบบง่าย
local function createUI()
    -- ลบ UI เก่าถ้ามี
    if playerGui:FindFirstChild("ServerHopUI") then
        playerGui.ServerHopUI:Destroy()
    end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ServerHopUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 250, 0, 80)
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
    titleLabel.Text = "🔄 Auto Server Hop (Simple)"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 25)
    statusLabel.Position = UDim2.new(0, 0, 0, 35)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🔵 กำลังเริ่มระบบ..."
    statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mainFrame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0, 20)
    infoLabel.Position = UDim2.new(0, 0, 0, 60)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Max: " .. CONFIG.maxPlayers .. " | หา: " .. (CONFIG.findBy == "playing" and "คนน้อย" or "Ping ต่ำ")
    infoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    infoLabel.TextScaled = true
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Parent = mainFrame

    return statusLabel
end

local statusUI = createUI()

-- อัปเดท UI
local function updateStatus(text, color)
    if statusUI then
        statusUI.Text = text
        statusUI.TextColor3 = color
    end
    print(text)
end

-- หาเซิร์ฟที่ดีที่สุด (แบบง่าย)
local function findBestServer()
    updateStatus("🔍 กำลังค้นหา server...", Color3.fromRGB(255, 255, 0))
    
    local success, response = pcall(function()
        return HttpService:GetAsync("https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?limit=100")
    end)
    
    if not success then
        updateStatus("❌ ไม่สามารถเชื่อมต่อ API", Color3.fromRGB(255, 100, 100))
        return nil
    end
    
    local success2, data = pcall(function()
        return HttpService:JSONDecode(response)
    end)
    
    if not success2 or not data.data then
        updateStatus("❌ ข้อมูล API ผิดพลาด", Color3.fromRGB(255, 100, 100))
        return nil
    end
    
    local servers = data.data
    local bestServer = nil
    
    print("📊 พบ " .. #servers .. " servers ทั้งหมด")
    
    -- หา server ที่ดีที่สุด
    for i, server in pairs(servers) do
        -- ข้าม server ปัจจุบันและ server ที่คนเยอะเกิน
        if server.id ~= JobId and server.playing <= CONFIG.maxPlayers and server.playing >= 1 then
            if not bestServer then
                bestServer = server
                print("🎯 server แรกที่เจอ: " .. server.id .. " | คน: " .. server.playing .. " | ping: " .. (server.ping or "N/A"))
            elseif server[CONFIG.findBy] < bestServer[CONFIG.findBy] then
                bestServer = server
                print("✅ เจอ server ดีกว่า: " .. server.id .. " | คน: " .. server.playing .. " | ping: " .. (server.ping or "N/A"))
            end
        end
    end
    
    if bestServer then
        print("🏆 server ที่ดีที่สุด: " .. bestServer.id)
        print("👥 ผู้เล่น: " .. bestServer.playing .. "/" .. bestServer.maxPlayers)
        print("📡 Ping: " .. (bestServer.ping or "N/A") .. "ms")
        return bestServer
    else
        updateStatus("❌ ไม่พบ server เหมาะสม", Color3.fromRGB(255, 100, 100))
        return nil
    end
end

-- ตรวจเซิร์ฟปัจจุบัน
local function isCurrentServerTooFull()
    local currentPlayerCount = #Players:GetPlayers()
    local isFull = currentPlayerCount > CONFIG.maxPlayers
    
    if isFull then
        updateStatus("⚠️ Server เต็ม! (" .. currentPlayerCount .. "/" .. CONFIG.maxPlayers .. ")", Color3.fromRGB(255, 100, 100))
    else
        updateStatus("✅ Server ปกติ (" .. currentPlayerCount .. "/" .. CONFIG.maxPlayers .. ")", Color3.fromRGB(100, 255, 100))
    end
    
    return isFull
end

-- ย้ายเซิร์ฟ
local function attemptTeleport()
    if tick() - lastTeleport < CONFIG.teleportCooldown then 
        print("⏰ รอ cooldown อีก " .. math.ceil(CONFIG.teleportCooldown - (tick() - lastTeleport)) .. " วินาที")
        return 
    end

    local newServer = findBestServer()
    if newServer then
        updateStatus("🎯 กำลังย้าย server...", Color3.fromRGB(100, 255, 100))
        lastTeleport = tick()
        
        -- Teleport
        task.spawn(function()
            task.wait(1)
            TeleportService:TeleportToPlaceInstance(PlaceId, newServer.id, player)
        end)
    end
end

-- ลูปหลัก
task.spawn(function()
    task.wait(3) -- รอให้โหลดเสร็จ
    updateStatus("🔵 ระบบทำงานแล้ว", Color3.fromRGB(100, 200, 255))
    
    while true do
        if isCurrentServerTooFull() then
            attemptTeleport()
        end
        task.wait(CONFIG.checkInterval)
    end
end)

-- Event handlers
Players.PlayerAdded:Connect(function()
    task.wait(1)
    task.spawn(isCurrentServerTooFull)
end)

Players.PlayerRemoving:Connect(function()
    task.wait(1)
    task.spawn(isCurrentServerTooFull)
end)

print("🚀 Auto Server Hop (Simple) เริ่มทำงานแล้ว!")
print("📊 หา server ตาม: " .. CONFIG.findBy .. " (เปลี่ยนได้ใน CONFIG)")
print("👥 Max players: " .. CONFIG.maxPlayers)
