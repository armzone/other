-- Enhanced Friend Request Script with Async Handling (No Game Freezing)
-- Made By Masterp (Fixed by Assistant) 
wait(30)
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer.Character

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local PlayersQueue = {}
local isProcessing = false
local RequeueCount = {}
local lastRequestTime = 0

-- ตั้งค่า
local REQUEUE_LIMIT = 3
local MIN_WAIT = 90 -- เพิ่มเป็น 90 วินาที เพื่อหลีกเลี่ยง rate limit
local MAX_WAIT = 150 -- เพิ่มเป็น 150 วินาที
local RATE_LIMIT_PAUSE = 300 -- พัก 5 นาที (300 วินาที) เมื่อเจอ rate limit
local REQUEST_COOLDOWN = 10 -- คูลดาวน์ขั้นต่ำระหว่างการส่งแต่ละครั้ง (10 วินาที)

-- ฟังก์ชันสุ่มเวลารอ
local function getRandomWait()
    return math.random(MIN_WAIT, MAX_WAIT)
end

-- เพิ่มผู้เล่นลงคิว (ไม่รวมตัวเอง) - ปรับปรุงประสิทธิภาพ
local function addPlayer(player)
    -- เช็คเงื่อนไขพื้นฐานก่อน
    if not player or player == LocalPlayer then return end
    
    -- ใช้ loop แทน table.find เพื่อประหยัด memory
    for i = 1, #PlayersQueue do
        if PlayersQueue[i] == player then return end
    end
    
    PlayersQueue[#PlayersQueue + 1] = player -- ใช้ # แทน table.insert
    -- ลด print เหลือแค่สำคัญ
    if #PlayersQueue % 5 == 0 then -- print ทุก 5 คน
        print("➕ คิวปัจจุบัน: " .. #PlayersQueue .. " คน")
    end
end

-- ลบผู้เล่นออกจากคิว - ปรับปรุงประสิทธิภาพ
local function removePlayer(player)
    if not player then return end
    
    -- หาและลบแบบ optimized
    for i = 1, #PlayersQueue do
        if PlayersQueue[i] == player then
            table.remove(PlayersQueue, i)
            -- ลด print
            break
        end
    end
    
    -- ทำความสะอาด requeue count
    if player.UserId then
        RequeueCount[player.UserId] = nil
    end
end

-- เชื่อม event
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

-- ใส่ผู้เล่นที่อยู่ในเซิร์ฟเวอร์ตอนเริ่ม
print("============== << กำลังเตรียมคิว >> ==============")
for _, player in ipairs(Players:GetPlayers()) do
    addPlayer(player)
end

-- ฟังก์ชันส่งคำขอเป็นเพื่อนแบบ async
local function sendFriendRequestAsync(player)
    return task.spawn(function()
        local success, result = pcall(function()
            return LocalPlayer:RequestFriendship(player)
        end)
        return success, result
    end)
end

-- ฟังก์ชันตรวจสอบประเภทของ error และ success
local function handleResult(player, success, result)
    -- ถ้า success = true แสดงว่าส่งสำเร็จแน่นอน
    if success == true then
        return "success"
    end
    
    -- ถ้า success = false หรือ result มี error message
    local errorMsg = tostring(result):lower()
    
    -- เช็คว่าเป็น rate limiting หรือไม่
    if errorMsg:find("too many requests") or errorMsg:find("rate limit") or errorMsg:find("flood") then
        return "rate_limit"
    end
    
    -- เช็คว่าเป็นเพื่อนอยู่แล้วหรือ pending
    if errorMsg:find("already friends") or errorMsg:find("pending") or errorMsg:find("friend request sent") then
        return "already_friends"
    end
    
    -- เช็คว่า friend limit เต็ม
    if errorMsg:find("friend limit") or errorMsg:find("too many friends") then
        return "friend_limit_full"
    end
    
    -- ถ้าไม่มี error message ชัดเจน แต่ success = false
    -- อาจเป็นการส่งสำเร็จแต่ API return ผิด
    if errorMsg == "false" or errorMsg == "" or errorMsg == "nil" then
        return "possible_success"
    end
    
    -- Error อื่นๆ
    return "other_error"
end

-- ฟังก์ชันรอแบบไม่บล็อกเกม - ปรับปรุงประสิทธิภาพ
local function smartWait(duration)
    if duration <= 0 then return end
    
    local startTime = tick()
    local targetTime = startTime + duration
    
    repeat
        task.wait(math.min(1, targetTime - tick())) -- รอนานขึ้น เช็คน้อยลง
    until tick() >= targetTime
end

-- ส่งคำขอเป็นเพื่อนทีละคน - ปรับปรุงประสิทธิภาพ
local function processQueue()
    while true do
        -- เช็คเงื่อนไขแบบรวดเร็ว
        local queueSize = #PlayersQueue
        if queueSize > 0 and not isProcessing then
            -- เช็คว่าพอเวลาส่งครั้งต่อไปหรือยัง
            local currentTime = tick()
            local timeSinceLastRequest = currentTime - lastRequestTime
            
            if timeSinceLastRequest < REQUEST_COOLDOWN then
                local remainingCooldown = REQUEST_COOLDOWN - timeSinceLastRequest
                -- ลด print เหลือแค่กรณีสำคัญ
                if remainingCooldown > 5 then
                    print("⏰ รอคูลดาวน์อีก " .. math.ceil(remainingCooldown) .. " วินาที...")
                end
                smartWait(remainingCooldown)
            end
            
            isProcessing = true
            lastRequestTime = tick()
            
            local player = PlayersQueue[1]
            table.remove(PlayersQueue, 1)
            
            -- เช็คว่า player ยังใช้งานได้
            if not player or not player.Parent or player.Parent ~= Players then
                print("⚠️ ผู้เล่นออกจากเกมแล้ว")
                isProcessing = false
                continue
            end
            
            -- ลด print เหลือแค่สำคัญ
            if queueSize <= 10 or queueSize % 10 == 0 then
                print("🔄 ส่งไปยัง: " .. player.Name .. " (เหลือ: " .. (queueSize-1) .. ")")
            end
            
            -- ส่งคำขอแบบ async
            task.spawn(function()
                local success, result = pcall(LocalPlayer.RequestFriendship, LocalPlayer, player)
                local resultType = handleResult(player, success, result)
                
                if resultType == "success" or resultType == "possible_success" then
                    -- ลด notification เหลือแค่กรณีสำคัญ
                    print("✅ " .. player.Name .. " สำเร็จ")
                    if queueSize <= 5 then -- แจ้งแค่ 5 คนสุดท้าย
                        StarterGui:SetCore("SendNotification", {
                            Title = "Friend Sent ✅",
                            Text = player.Name,
                            Duration = 2
                        })
                    end
                    RequeueCount[player.UserId] = nil
                    
                elseif resultType == "rate_limit" then
                    print("⏸️ Rate Limit! พัก " .. RATE_LIMIT_PAUSE .. " วินาที")
                    StarterGui:SetCore("SendNotification", {
                        Title = "Rate Limited ⏸️",
                        Text = "พัก 5 นาที",
                        Duration = 3
                    })
                    table.insert(PlayersQueue, 1, player)
                    isProcessing = false
                    smartWait(RATE_LIMIT_PAUSE)
                    return
                    
                elseif resultType == "already_friends" then
                    -- ลด print สำหรับกรณีปกติ
                    RequeueCount[player.UserId] = nil
                    
                elseif resultType == "friend_limit_full" then
                    print("🛑 Friend limit เต็ม - หยุดการทำงาน")
                    StarterGui:SetCore("SendNotification", {
                        Title = "Friend Limit Full 🛑",
                        Text = "ไม่สามารถเพิ่มเพื่อนได้แล้ว",
                        Duration = 5
                    })
                    isProcessing = false
                    return
                    
                else
                    -- Error handling แบบ simplified
                    local retryCount = (RequeueCount[player.UserId] or 0) + 1
                    RequeueCount[player.UserId] = retryCount
                    
                    if retryCount <= REQUEUE_LIMIT then
                        -- ลด notification เหลือแค่ครั้งสุดท้าย
                        if retryCount == REQUEUE_LIMIT then
                            print("❌ " .. player.Name .. " ลองครั้งสุดท้าย")
                        end
                        table.insert(PlayersQueue, player)
                    else
                        print("🚫 ข้าม " .. player.Name)
                        RequeueCount[player.UserId] = nil
                    end
                end
                
                isProcessing = false
            end)
            
            -- รอให้ request เสร็จ
            while isProcessing do
                task.wait(0.5) -- เพิ่มจาก 0.1 เป็น 0.5
            end
            
            -- รอเวลาก่อนส่งคนต่อไป
            if #PlayersQueue > 0 then
                local waitTime = getRandomWait()
                -- ลด print การรอ
                if waitTime > 100 then
                    print("⏳ รอ " .. waitTime .. " วินาที...")
                end
                smartWait(waitTime)
            end
        else
            -- ไม่มีคิว รอนานขึ้น
            task.wait(10) -- เพิ่มจาก 5 เป็น 10 วินาที
        end
    end
end

-- เริ่มลูปประมวลผล
print("🚀 เริ่มต้นระบบส่ง Friend Request (ป้องกันเกมค้าง)")
print("⚙️ ตั้งค่า:")
print("   - รอระหว่างการส่ง: " .. MIN_WAIT .. "-" .. MAX_WAIT .. " วินาที")
print("   - ลองซ้ำสูงสุด: " .. REQUEUE_LIMIT .. " ครั้ง")
print("   - พักเมื่อ rate limit: " .. RATE_LIMIT_PAUSE .. " วินาที")
print("   - คูลดาวน์ขั้นต่ำ: " .. REQUEST_COOLDOWN .. " วินาที")

task.spawn(processQueue)
