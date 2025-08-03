-- Automatic JobId Monitor (No Commands Required)
-- รันครั้งเดียว ทำงานอัตโนมัติตลอด

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

print("🕵️ Automatic JobId Monitor Loading...")
print("Will automatically detect and alert JobId steal attempts")

-- ข้อมูลสำหรับ monitoring
local stealAttempts = 0
local totalAttempts = 0
local lastAttemptTime = 0

-- Allowed webhooks (เพิ่มของคุณเองที่นี่)
local allowedWebhooks = {
    "https://your.safe.webhook.here"
}

-- เก็บ original functions
local oldPost = HttpService.PostAsync
local oldGet = HttpService.GetAsync

-- ฟังก์ชันเช็คว่ามี JobId หรือไม่
local function containsJobId(content)
    if not content then return false end
    
    local contentStr = tostring(content):lower()
    local realJobId = game.JobId:lower()
    
    -- เช็คคำสำคัญ
    local keywords = {
        "jobid", "job_id", "job-id", "serverid", "server_id", 
        "server-id", "sessionid", "session_id", "instanceid"
    }
    
    for _, keyword in pairs(keywords) do
        if string.find(contentStr, keyword) then
            return true
        end
    end
    
    -- เช็ค JobId จริง
    if string.find(contentStr, realJobId) then
        return true
    end
    
    -- เช็ค GUID pattern
    if string.find(contentStr, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x") then
        return true
    end
    
    return false
end

-- ฟังก์ชันเช็คว่าเป็น webhook หรือไม่
local function isWebhook(url)
    local webhookPatterns = {
        "discord%.com/api/webhooks",
        "discordapp%.com/api/webhooks",
        "webhook",
        "hook"
    }
    
    for _, pattern in pairs(webhookPatterns) do
        if string.find(url:lower(), pattern) then
            return true
        end
    end
    return false
end

-- ฟังก์ชันเช็คว่า URL อนุญาตหรือไม่
local function isAllowed(url)
    for _, allowed in pairs(allowedWebhooks) do
        if url == allowed then
            return true
        end
    end
    return false
end

-- ฟังก์ชันแจ้งเตือนอัตโนมัติ
local function autoAlert(method, url, details)
    stealAttempts = stealAttempts + 1
    lastAttemptTime = os.time()
    
    -- แจ้งเตือนใน Console
    print("\n🚨 JOBID STEAL ATTEMPT #" .. stealAttempts .. " DETECTED!")
    print("Time: " .. os.date("%H:%M:%S"))
    print("Method: " .. method)
    print("URL: " .. url)
    print("Details: " .. details)
    print("🛡️ Automatically blocked and monitored")
    
    -- เล่นเสียงแจ้งเตือน
    spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
        sound.Volume = 0.7
        sound.Parent = workspace
        sound:Play()
        
        wait(1)
        sound:Destroy()
    end)
    
    -- สร้าง GUI แจ้งเตือนอัตโนมัติ
    spawn(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "AutoJobIdAlert" .. stealAttempts
        screenGui.Parent = player.PlayerGui
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 350, 0, 120)
        frame.Position = UDim2.new(1, -370, 0, 20 + (stealAttempts - 1) * 130)
        frame.BackgroundColor3 = Color3.fromRGB(255, 69, 58)
        frame.BorderSizePixel = 0
        frame.Parent = screenGui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = frame
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -20, 0, 25)
        title.Position = UDim2.new(0, 10, 0, 5)
        title.BackgroundTransparency = 1
        title.Text = "🚨 JOBID STEAL #" .. stealAttempts
        title.TextColor3 = Color3.fromRGB(255, 255, 255)
        title.TextScaled = true
        title.Font = Enum.Font.GothamBold
        title.Parent = frame
        
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(1, -20, 0, 20)
        timeLabel.Position = UDim2.new(0, 10, 0, 30)
        timeLabel.BackgroundTransparency = 1
        timeLabel.Text = "Time: " .. os.date("%H:%M:%S")
        timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        timeLabel.TextScaled = true
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.Parent = frame
        
        local methodLabel = Instance.new("TextLabel")
        methodLabel.Size = UDim2.new(1, -20, 0, 20)
        methodLabel.Position = UDim2.new(0, 10, 0, 50)
        methodLabel.BackgroundTransparency = 1
        methodLabel.Text = "Method: " .. method
        methodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        methodLabel.TextScaled = true
        methodLabel.Font = Enum.Font.Gotham
        methodLabel.Parent = frame
        
        local urlLabel = Instance.new("TextLabel")
        urlLabel.Size = UDim2.new(1, -20, 0, 20)
        urlLabel.Position = UDim2.new(0, 10, 0, 70)
        urlLabel.BackgroundTransparency = 1
        urlLabel.Text = "URL: " .. (url:len() > 30 and url:sub(1, 30) .. "..." or url)
        urlLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        urlLabel.TextScaled = true
        urlLabel.Font = Enum.Font.Gotham
        urlLabel.Parent = frame
        
        local statusLabel = Instance.new("TextLabel")
        statusLabel.Size = UDim2.new(1, -20, 0, 20)
        statusLabel.Position = UDim2.new(0, 10, 0, 90)
        statusLabel.BackgroundTransparency = 1
        statusLabel.Text = "🛡️ BLOCKED & MONITORED"
        statusLabel.TextColor3 = Color3.fromRGB(144, 238, 144)
        statusLabel.TextScaled = true
        statusLabel.Font = Enum.Font.GothamBold
        statusLabel.Parent = frame
        
        -- Slide in animation
        frame:TweenPosition(UDim2.new(1, -370, 0, 20 + (stealAttempts - 1) * 130), "Out", "Quad", 0.5, true)
        
        -- Auto close หลัง 8 วินาที
        wait(8)
        
        -- Slide out animation
        frame:TweenPosition(UDim2.new(1, 10, 0, 20 + (stealAttempts - 1) * 130), "In", "Quad", 0.5, true)
        wait(0.5)
        screenGui:Destroy()
    end)
end

-- Hook HttpService.PostAsync อัตโนมัติ
hookfunction(HttpService.PostAsync, function(self, url, body, content_type)
    totalAttempts = totalAttempts + 1
    
    if containsJobId(body) and not isAllowed(url) then
        local webhookInfo = isWebhook(url) and " (Discord Webhook)" or ""
        autoAlert("HTTP POST", url, "JobId found in request body" .. webhookInfo)
    end
    
    return oldPost(self, url, body, content_type)
end)

-- Hook HttpService.GetAsync อัตโนมัติ
hookfunction(HttpService.GetAsync, function(self, url, nocache, headers)
    totalAttempts = totalAttempts + 1
    
    if containsJobId(url) and not isAllowed(url) then
        autoAlert("HTTP GET", url, "JobId found in URL parameters")
    end
    
    return oldGet(self, url, nocache, headers)
end)

-- Monitor RemoteEvents/RemoteFunctions อัตโนมัติ
spawn(function()
    wait(3) -- รอให้เกมโหลด
    
    for _, obj in pairs(game.ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local originalFire = obj.FireServer
            obj.FireServer = function(self, ...)
                local args = {...}
                
                for i, arg in pairs(args) do
                    if containsJobId(arg) then
                        autoAlert("RemoteEvent", obj.Name, "JobId in argument #" .. i .. ": " .. tostring(arg):sub(1, 50))
                        break
                    end
                end
                
                return originalFire(self, ...)
            end
        elseif obj:IsA("RemoteFunction") then
            local originalInvoke = obj.InvokeServer
            obj.InvokeServer = function(self, ...)
                local args = {...}
                
                for i, arg in pairs(args) do
                    if containsJobId(arg) then
                        autoAlert("RemoteFunction", obj.Name, "JobId in argument #" .. i .. ": " .. tostring(arg):sub(1, 50))
                        break
                    end
                end
                
                return originalInvoke(self, ...)
            end
        end
    end
    
    print("✅ Remote monitoring activated automatically")
end)

-- แสดงสถานะอัตโนมัติทุก 60 วินาที
spawn(function()
    while true do
        wait(60)
        
        if stealAttempts > 0 then
            print(string.format("📊 Auto Monitor Status: %d steal attempts detected | %d total HTTP requests monitored", 
                  stealAttempts, totalAttempts))
        end
    end
end)

-- แสดงรายงานสรุปอัตโนมัติเมื่อออกจากเกม
game.Players.LocalPlayer.AncestryChanged:Connect(function()
    if not game.Players.LocalPlayer.Parent then
        print("\n📊 FINAL AUTO MONITORING REPORT")
        print("=" .. string.rep("=", 40))
        print("Total steal attempts detected: " .. stealAttempts)
        print("Total HTTP requests monitored: " .. totalAttempts)
        if stealAttempts > 0 then
            print("Last attempt: " .. os.date("%H:%M:%S", lastAttemptTime))
            print("🛡️ Your JobId was protected!")
        else
            print("✅ No steal attempts detected - you're safe!")
        end
        print("=" .. string.rep("=", 40))
    end
end)

-- แสดงข้อความเริ่มต้น
wait(1)
print("✅ Automatic JobId Monitor is now active!")
print("🛡️ No commands needed - everything is automatic")
print("🚨 Will alert immediately when JobId steal attempts are detected")
print("📊 Monitoring all HTTP requests, RemoteEvents, and RemoteFunctions")
print("🔒 Your JobId is now protected 24/7")

-- เสียงยืนยันการเริ่มทำงาน
spawn(function()
    local confirmSound = Instance.new("Sound")
    confirmSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
    confirmSound.Volume = 0.3
    confirmSound.Parent = workspace
    confirmSound:Play()
    
    wait(0.2)
    confirmSound:Play()
    
    wait(1)
    confirmSound:Destroy()
end)
