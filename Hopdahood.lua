-- ✅ Auto Server Hop (เวอร์ชันปรับปรุง) + UI + Error Handling
local CONFIG = {
    maxPlayers = 5,
    checkInterval = 5, -- วินาที
    teleportCooldown = 15, -- วินาที (เพิ่มขึ้นเพื่อป้องกัน rate limit)
    maxRetries = 3,
    searchPages = 5 -- เพิ่มจำนวนหน้าที่ค้นหา
}

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PlaceId = game.PlaceId
local JobId = game.JobId

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ตัวแปรสำหรับควบคุม
local isSearching = false
local lastTeleport = 0
local lastCheck = 0

-- 🎨 สร้าง UI ที่ดีขึ้น
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
    mainFrame.Size = UDim2.new(0, 280, 0, 120)
    mainFrame.Position = UDim2.new(0, 10, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    -- เพิ่ม shadow effect
    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 4, 1, 4)
    shadow.Position = UDim2.new(0, -2, 0, -2)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.5
    shadow.ZIndex = mainFrame.ZIndex - 1
    shadow.Parent = screenGui
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 10)
    shadowCorner.Parent = shadow

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    -- Gradient background
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 45)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 25, 35))
    })
    gradient.Rotation = 45
    gradient.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 30)
    titleLabel.Position = UDim2.new(0, 0, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔄 Auto Server Hop v2.0"
    titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame

    local playerCountLabel = Instance.new("TextLabel")
    playerCountLabel.Size = UDim2.new(1, 0, 0, 25)
    playerCountLabel.Position = UDim2.new(0, 0, 0, 35)
    playerCountLabel.BackgroundTransparency = 1
    playerCountLabel.Text = "👥 Players: 0/" .. CONFIG.maxPlayers
    playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerCountLabel.TextScaled = true
    playerCountLabel.Font = Enum.Font.Gotham
    playerCountLabel.Parent = mainFrame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 25)
    statusLabel.Position = UDim2.new(0, 0, 0, 65)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "🔵 กำลังเริ่มระบบ..."
    statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mainFrame

    return {
        frame = mainFrame,
        playerCount = playerCountLabel,
        status = statusLabel
    }
end

local ui = createUI()

-- อัปเดท UI พร้อม animation
local function updateUI(currentPlayers, status, statusColor)
    if not ui.playerCount or not ui.status then return end
    
    ui.playerCount.Text = "👥 Players: " .. currentPlayers .. "/" .. CONFIG.maxPlayers
    ui.status.Text = status
    
    -- Smooth color transition
    local tween = game:GetService("TweenService"):Create(
        ui.status,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {TextColor3 = statusColor}
    )
    tween:Play()
    
    -- เปลี่ยนสี player count ถ้าคนเยอะ
    local playerCountColor = currentPlayers > CONFIG.maxPlayers and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(255, 255, 255)
    local playerTween = game:GetService("TweenService"):Create(
        ui.playerCount,
        TweenInfo.new(0.3, Enum.EasingStyle.Quad),
        {TextColor3 = playerCountColor}
    )
    playerTween:Play()
end

-- ฟังก์ชัน retry mechanism
local function withRetry(func, maxRetries)
    for attempt = 1, maxRetries do
        local success, result = pcall(func)
        if success then
            return result
        elseif attempt == maxRetries then
            warn("❌ Failed after " .. maxRetries .. " attempts")
            return nil
        else
            task.wait(1) -- รอก่อน retry
        end
    end
end

-- ตรวจเซิร์ฟปัจจุบัน (ปรับปรุงแล้ว)
local function getCurrentServerInfo()
    if tick() - lastCheck < 2 then return nil end -- throttle requests
    lastCheck = tick()
    
    local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    
    return withRetry(function()
        local response = HttpService:GetAsync(url)
        local data = HttpService:JSONDecode(response)
        
        for _, server in ipairs(data.data or {}) do
            if server.id == JobId then
                return server
            end
        end
        return nil
    end, CONFIG.maxRetries)
end

local function isCurrentServerTooFull()
    local serverInfo = getCurrentServerInfo()
    local currentPlayerCount = #Players:GetPlayers()
    
    if serverInfo then
        local isFull = serverInfo.playing > CONFIG.maxPlayers
        local statusText = isFull and "⚠️ Server เต็ม!" or "✅ Server ปกติ"
        local statusColor = isFull and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
        
        updateUI(serverInfo.playing, statusText, statusColor)
        return isFull
    else
        -- ใช้ local count เป็น fallback
        local isFull = currentPlayerCount > CONFIG.maxPlayers
        local statusText = "⚠️ ใช้ข้อมูลในเครื่อง"
        updateUI(currentPlayerCount, statusText, Color3.fromRGB(255, 200, 100))
        return isFull
    end
end

-- หาเซิร์ฟที่คนน้อยที่สุด (เรียงลำดับ)
local function findBestServer()
    if isSearching then return nil end
    isSearching = true
    
    updateUI(0, "🔍 กำลังค้นหา server ที่ดีที่สุด...", Color3.fromRGB(100, 200, 255))
    
    local allServers = {}
    local cursor = ""
    local baseUrl = "https://games.roblox.com/v1/games/%s/servers/Public?sortOrder=Asc&limit=100&cursor=%s"
    
    -- ค้นหาทุกหน้าที่เป็นไปได้
    for page = 1, CONFIG.searchPages do
        local success, response = pcall(function()
            local url = string.format(baseUrl, PlaceId, cursor)
            return HttpService:GetAsync(url)
        end)
        
        if not success then 
            print("⚠️ ไม่สามารถดึงข้อมูลหน้า " .. page .. " ได้")
            break 
        end
        
        local data = HttpService:JSONDecode(response)
        
        for _, server in ipairs(data.data or {}) do
            if server.id ~= JobId then -- ไม่รวมเซิร์ฟปัจจุบัน
                table.insert(allServers, {
                    id = server.id,
                    playing = server.playing,
                    maxPlayers = server.maxPlayers,
                    ping = server.ping or 999
                })
            end
        end
        
        if not data.nextPageCursor then break end
        cursor = data.nextPageCursor
        task.wait(0.3) -- ลด rate limit
    end
    
    isSearching = false
    
    if #allServers == 0 then
        print("❌ ไม่พบเซิร์ฟเวอร์ใดๆ")
        return nil
    end
    
    -- เรียงตามจำนวนผู้เล่นน้อยที่สุด แต่ไม่ใช่เซิร์ฟว่าง และ ping ที่ดี
    table.sort(allServers, function(a, b)
        -- ให้น้ำหนักกับเซิร์ฟที่มีคนแต่ไม่เยอะ
        local aScore = a.playing + (a.ping / 100)  
        local bScore = b.playing + (b.ping / 100)
        return aScore < bScore
    end)
    
    -- เลือกเซิร์ฟที่ดีที่สุด 5 อันดับแรก แล้วสุ่ม
    local bestServers = {}
    for i = 1, math.min(5, #allServers) do
        if allServers[i].playing <= CONFIG.maxPlayers then
            table.insert(bestServers, allServers[i])
        end
    end
    
    if #bestServers == 0 then
        print("❌ ไม่พบเซิร์ฟเวอร์ที่มีผู้เล่น <= " .. CONFIG.maxPlayers)
        return nil
    end
    
    local selectedServer = bestServers[math.random(#bestServers)]
    print("🎯 เลือกเซิร์ฟ ID: " .. selectedServer.id .. " | ผู้เล่น: " .. selectedServer.playing .. "/" .. selectedServer.maxPlayers .. " | Ping: " .. selectedServer.ping)
    
    return selectedServer
end

-- ย้ายเซิร์ฟ (ปรับปรุงแล้ว)
local function attemptTeleport()
    if tick() - lastTeleport < CONFIG.teleportCooldown then 
        return 
    end

    updateUI(0, "⚠️ Server เต็ม! กำลังหา server ที่ดีที่สุด...", Color3.fromRGB(255, 100, 100))
    print("⚠️ เซิร์ฟคนเกิน " .. CONFIG.maxPlayers .. " → กำลังค้นหาเซิร์ฟที่ดีที่สุด...")

    local newServer = findBestServer()
    if newServer then
        updateUI(newServer.playing, "🎯 กำลังย้ายไป server ที่ดีที่สุด...", Color3.fromRGB(100, 255, 100))
        print("🎯 ย้ายไปเซิร์ฟ ID: " .. newServer.id .. " | ผู้เล่น: " .. newServer.playing .. " | Ping: " .. (newServer.ping or "N/A"))
        lastTeleport = tick()
        
        -- เพิ่ม safety check
        task.spawn(function()
            task.wait(2) -- รอให้ UI อัปเดต
            TeleportService:TeleportToPlaceInstance(PlaceId, newServer.id, player)
        end)
    else
        updateUI(0, "❌ ไม่พบ server ที่เหมาะสม", Color3.fromRGB(255, 100, 100))
        warn("❌ ไม่พบเซิร์ฟเวอร์ที่เหมาะสม (คน <= " .. CONFIG.maxPlayers .. ")")
    end
end

-- ลูปหลัก (ปรับปรุงแล้ว)
task.spawn(function()
    task.wait(3) -- รอให้ทุกอย่างโหลดเสร็จ
    
    while true do
        if not isSearching then
            if isCurrentServerTooFull() then
                attemptTeleport()
            end
        end
        task.wait(CONFIG.checkInterval)
    end
end)

-- Event handlers
Players.PlayerAdded:Connect(function()
    task.wait(1) -- รอให้ระบบอัปเดต
    task.spawn(isCurrentServerTooFull)
end)

Players.PlayerRemoving:Connect(function()
    task.wait(1)
    task.spawn(isCurrentServerTooFull)
end)

-- Cleanup เมื่อปิดเกม
game:GetService("GuiService").ErrorMessageChanged:Connect(function()
    if ui.frame then
        ui.frame:Destroy()
    end
end)

print("🚀 Auto Server Hop v2.0 เริ่มทำงานแล้ว!")
print("📊 การตั้งค่า: Max Players = " .. CONFIG.maxPlayers .. ", Check Interval = " .. CONFIG.checkInterval .. "s")
print("🎯 ระบบจะค้นหา server ที่มีผู้เล่นน้อยที่สุดและ ping ที่ดีที่สุดโดยอัตโนมัติ")
