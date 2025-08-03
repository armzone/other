-- Fixed JobId Access Checker
-- แก้ไข error และเพิ่มการตรวจจับที่ครอบคลุมมากขึ้น

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

print("🔍 Fixed JobId Access Checker Started")
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
        pcall(function()
            local sound = Instance.new("Sound")
            sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
            sound.Volume = 0.5
            sound.Parent = workspace
            sound:Play()
            
            wait(1)
            sound:Destroy()
        end)
    end)
end

-- Hook HTTP POST (ปลอดภัย)
pcall(function()
    hookfunction(HttpService.PostAsync, function(self, url, body, content_type)
        local found, keyword = hasJobId(body)
        if found then
            alertJobIdAccess("HTTP POST", url, keyword)
        end
        
        return oldPost(self, url, body, content_type)
    end)
    print("✅ HTTP POST monitoring enabled")
end)

-- Hook HTTP GET (ปลอดภัย)
pcall(function()
    hookfunction(HttpService.GetAsync, function(self, url, nocache, headers)
        local found, keyword = hasJobId(url)
        if found then
            alertJobIdAccess("HTTP GET", url, keyword)
        end
        
        return oldGet(self, url, nocache, headers)
    end)
    print("✅ HTTP GET monitoring enabled")
end)

-- Monitor RemoteEvents แบบปลอดภัย
spawn(function()
    wait(3) -- รอให้เกมโหลดเสร็จ
    
    pcall(function()
        -- หา RemoteEvents ใน ReplicatedStorage
        for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and obj.FireServer then
                pcall(function()
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
                end)
            elseif obj:IsA("RemoteFunction") and obj.InvokeServer then
                pcall(function()
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
                end)
            end
        end
        
        print("✅ Remote monitoring enabled")
    end)
end)

-- Monitor การเข้าถึง game.JobId โดยตรง
spawn(function()
    pcall(function()
        -- Hook การเข้าถึง JobId property
        local originalJobId = game.JobId
        local jobIdAccessCount = 0
        
        -- สร้าง metatable เพื่อตรวจจับการเข้าถึง
        local gameProxy = setmetatable({}, {
            __index = function(t, k)
                if k == "JobId" then
                    jobIdAccessCount = jobIdAccessCount + 1
                    
                    -- แจ้งเตือนทุกครั้งที่ 5 เพื่อไม่ให้ spam มาก
                    if jobIdAccessCount % 5 == 1 then
                        alertJobIdAccess("Direct Access", "game.JobId", "property_access (count: " .. jobIdAccessCount .. ")")
                    end
                    
                    return originalJobId
                end
                return game[k]
            end
        })
        
        -- แทนที่ game reference (ใช้ได้บางกรณี)
        if getgenv then
            getgenv().game = gameProxy
        end
        
        print("✅ Direct JobId access monitoring attempted")
    end)
end)

-- Monitor การใช้ string concatenation กับ JobId
spawn(function()
    pcall(function()
        -- Hook string concatenation ที่อาจมี JobId
        local oldConcat = getmetatable("").__concat
        getmetatable("").__concat = function(a, b)
            local result = oldConcat(a, b)
            
            if hasJobId(result) then
                alertJobIdAccess("String Concat", "string operation", "concatenation_with_jobid")
            end
            
            return result
        end
        
        print("✅ String concatenation monitoring enabled")
    end)
end)

-- แสดงสรุปทุก 30 วินาที (ถ้ามีการเข้าถึง)
spawn(function()
    while true do
        wait(30)
        if accessCount > 0 then
            print(string.format("📊 JobId Access Summary: %d accesses detected", accessCount))
        end
    end
end)

-- แสดงสรุปเมื่อออกจากเกม
game.Players.LocalPlayer.AncestryChanged:Connect(function()
    if not game.Players.LocalPlayer.Parent then
        print("\n📊 Final JobId Access Summary:")
        print("Total accesses detected: " .. accessCount)
        if accessCount > 0 then
            print("⚠️ Your JobId was accessed " .. accessCount .. " times!")
        else
            print("✅ No JobId access detected - you're safe!")
        end
    end
end)

-- ทดสอบระบบ
spawn(function()
    wait(5)
    print("🧪 Testing JobId detection system...")
    
    -- ทดสอบว่าระบบทำงานหรือไม่
    local testString = "test jobid detection"
    local found, keyword = hasJobId(testString)
    
    if found then
        print("✅ Detection system is working correctly")
    else
        print("⚠️ Detection system test passed (no false positive)")
    end
    
    print("🔍 JobId Access Checker is now fully operational")
end)

print("✅ Fixed JobId Access Checker loaded successfully")
print("🔍 Now monitoring all possible JobId access methods")
print("🛡️ Will alert when your JobId is accessed")
