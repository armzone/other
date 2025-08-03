-- Simple JobId Access Checker
-- แค่เช็คและแจ้งเตือนเมื่อมีการขอ JobId

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

print("🔍 JobId Access Checker Started")
print("Will detect when someone tries to access your JobId")

-- นับจำนวนการเข้าถึง
local accessCount = 0

-- เก็บ original functions
local oldPost = HttpService.PostAsync
local oldGet = HttpService.GetAsync

-- ฟังก์ชันเช็คว่ามี JobId หรือไม่
local function hasJobId(content)
    if not content then return false end
    
    local contentStr = tostring(content):lower()
    local realJobId = game.JobId:lower()
    
    -- เช็ค JobId จริง
    if string.find(contentStr, realJobId) then
        return true, "actual_jobid"
    end
    
    -- เช็คคำที่เกี่ยวข้อง
    local keywords = {"jobid", "job_id", "serverid", "server_id", "sessionid"}
    for _, keyword in pairs(keywords) do
        if string.find(contentStr, keyword) then
            return true, keyword
        end
    end
    
    return false, nil
end

-- ฟังก์ชันแจ้งเตือนเมื่อมีการเข้าถึง
local function alertJobIdAccess(method, target, keyword)
    accessCount = accessCount + 1
    
    print("\n🚨 JOBID ACCESS DETECTED #" .. accessCount)
    print("Time: " .. os.date("%H:%M:%S"))
    print("Method: " .. method)
    print("Target: " .. target)
    print("Type: " .. keyword)
    print("=" .. string.rep("=", 40))
    
    -- เล่นเสียงแจ้งเตือน
    spawn(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxasset://sounds/button-09.mp3"
        sound.Volume = 0.5
        sound.Parent = workspace
        sound:Play()
        
        wait(1)
        sound:Destroy()
    end)
end

-- Hook HTTP POST
hookfunction(HttpService.PostAsync, function(self, url, body, content_type)
    local found, keyword = hasJobId(body)
    if found then
        alertJobIdAccess("HTTP POST", url, keyword)
    end
    
    return oldPost(self, url, body, content_type)
end)

-- Hook HTTP GET
hookfunction(HttpService.GetAsync, function(self, url, nocache, headers)
    local found, keyword = hasJobId(url)
    if found then
        alertJobIdAccess("HTTP GET", url, keyword)
    end
    
    return oldGet(self, url, nocache, headers)
end)

-- Monitor RemoteEvents
spawn(function()
    wait(2)
    
    for _, obj in pairs(game.ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") then
            local originalFire = obj.FireServer
            obj.FireServer = function(self, ...)
                local args = {...}
                
                for i, arg in pairs(args) do
                    local found, keyword = hasJobId(arg)
                    if found then
                        alertJobIdAccess("RemoteEvent", obj.Name, keyword .. " in arg #" .. i)
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
                    local found, keyword = hasJobId(arg)
                    if found then
                        alertJobIdAccess("RemoteFunction", obj.Name, keyword .. " in arg #" .. i)
                        break
                    end
                end
                
                return originalInvoke(self, ...)
            end
        end
    end
end)

-- แสดงสรุปเมื่อออกจากเกม
game.Players.LocalPlayer.AncestryChanged:Connect(function()
    if not game.Players.LocalPlayer.Parent then
        print("\n📊 JobId Access Summary:")
        print("Total accesses detected: " .. accessCount)
        if accessCount > 0 then
            print("⚠️ Your JobId was accessed " .. accessCount .. " times!")
        else
            print("✅ No JobId access detected - you're safe!")
        end
    end
end)

print("✅ JobId Access Checker is now monitoring")
print("🔍 Will alert when anyone tries to access your JobId")
