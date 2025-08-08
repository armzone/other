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

-- เพิ่มผู้เล่นลงคิว (ไม่รวมตัวเอง)
local function addPlayer(player)
    if player ~= LocalPlayer and not table.find(PlayersQueue, player) then
        table.insert(PlayersQueue, player)
        print("➕ " .. player.Name .. " ถูกเพิ่มลงคิว (คิวปัจจุบัน: " .. #PlayersQueue .. ")")
    end
end

-- ลบผู้เล่นออกจากคิว
local function removePlayer(player)
    for i = #PlayersQueue, 1, -1 do
        if PlayersQueue[i] == player then
            table.remove(PlayersQueue, i)
            print("➖ " .. player.Name .. " ถูกลบออกจากคิว")
            break
        end
    end
    
    -- ลบข้อมูล requeue count ด้วย
    if player and player.UserId then
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

-- ฟังก์ชันรอแบบไม่บล็อกเกม
local function smartWait(duration)
    local startTime = tick()
    repeat
        task.wait(0.1) -- รอ 0.1 วินาที แล้วเช็คใหม่
    until tick() - startTime >= duration
end

-- ส่งคำขอเป็นเพื่อนทีละคน
local function processQueue()
    while true do
        if #PlayersQueue > 0 and not isProcessing then
            -- เช็คว่าพอเวลาส่งครั้งต่อไปหรือยัง
            local currentTime = tick()
            if currentTime - lastRequestTime < REQUEST_COOLDOWN then
                local remainingCooldown = REQUEST_COOLDOWN - (currentTime - lastRequestTime)
                print("⏰ รอคูลดาวน์อีก " .. math.ceil(remainingCooldown) .. " วินาที...")
                smartWait(remainingCooldown)
            end
            
            isProcessing = true
            lastRequestTime = tick()
            
            local player = PlayersQueue[1]
            table.remove(PlayersQueue, 1)
            
            if player and player.Parent == Players then
                print("🔄 กำลังส่ง friend request ไปยัง: " .. player.Name)
                
                -- ส่งคำขอแบบ async เพื่อไม่ให้เกมค้าง
                local requestThread = task.spawn(function()
                    local success, result = pcall(function()
                        return LocalPlayer:RequestFriendship(player)
                    end)
                    
                    local resultType = handleResult(player, success, result)
                    
                    if resultType == "success" or resultType == "possible_success" then
                        -- ส่งสำเร็จ
                        print("✅ ส่ง friend request ไปยัง: " .. player.Name .. " สำเร็จ")
                        StarterGui:SetCore("SendNotification", {
                            Title = "Friend Request Sent ✅",
                            Text = player.Name,
                            Duration = 3
                        })
                        
                        -- ล้างข้อมูล requeue
                        RequeueCount[player.UserId] = nil
                        
                    elseif resultType == "rate_limit" then
                        print("⏸️ เจอ Rate Limit! พักการทำงาน " .. RATE_LIMIT_PAUSE .. " วินาที")
                        StarterGui:SetCore("SendNotification", {
                            Title = "Rate Limited ⏸️",
                            Text = "พัก 5 นาที",
                            Duration = 5
                        })
                        
                        -- ใส่ player กลับไปที่หัวคิว
                        table.insert(PlayersQueue, 1, player)
                        
                        isProcessing = false
                        smartWait(RATE_LIMIT_PAUSE)
                        return
                        
                    elseif resultType == "already_friends" then
                        print("👥 " .. player.Name .. " เป็นเพื่อนอยู่แล้วหรือรอการยืนยัน")
                        
                    elseif resultType == "friend_limit_full" then
                        print("🛑 Friend limit เต็มแล้ว หยุดการทำงาน")
                        StarterGui:SetCore("SendNotification", {
                            Title = "Friend Limit Full 🛑",
                            Text = "ไม่สามารถเพิ่มเพื่อนได้แล้ว",
                            Duration = 5
                        })
                        isProcessing = false
                        return
                        
                    else
                        -- Error อื่นๆ
                        RequeueCount[player.UserId] = (RequeueCount[player.UserId] or 0) + 1
                        
                        if RequeueCount[player.UserId] <= REQUEUE_LIMIT then
                            print("❌ ส่ง friend request ไปยัง: " .. player.Name .. " ไม่สำเร็จ - ลองใหม่ครั้งที่ " .. RequeueCount[player.UserId])
                            print("🔍 Error detail:", tostring(result))
                            StarterGui:SetCore("SendNotification", {
                                Title = "Friend Request Failed ❌",
                                Text = player.Name .. " (ลองใหม่: " .. RequeueCount[player.UserId] .. ")",
                                Duration = 3
                            })
                            
                            -- ใส่กลับไปในคิว
                            table.insert(PlayersQueue, player)
                        else
                            print("🚫 ข้าม " .. player.Name .. " หลังจากลองไม่สำเร็จ " .. REQUEUE_LIMIT .. " ครั้ง")
                            StarterGui:SetCore("SendNotification", {
                                Title = "Player Skipped 🚫",
                                Text = player.Name,
                                Duration = 3
                            })
                        end
                    end
                    
                    isProcessing = false
                end)
                
                -- รอให้ request เสร็จ แต่ไม่บล็อกเกม
                while isProcessing do
                    task.wait(0.1)
                end
                
            else
                print("⚠️ ผู้เล่นออกจากเกมแล้ว: " .. (player and player.Name or "Unknown"))
                isProcessing = false
            end
            
            -- รอเวลาสุ่มก่อนประมวลผลคนต่อไป (แต่ไม่บล็อกเกม)
            if #PlayersQueue > 0 then
                local waitTime = getRandomWait()
                print("⏳ รอ " .. waitTime .. " วินาที ก่อนส่งคนต่อไป...")
                smartWait(waitTime)
            end
        else
            -- ไม่มีคิวหรือกำลังประมวลผล รอ 5 วินาที
            task.wait(5)
        end
    end
    
    print("🏁 จบการทำงาน - ไม่มีผู้เล่นในคิวแล้ว")
end

-- เริ่มลูปประมวลผล
print("🚀 เริ่มต้นระบบส่ง Friend Request (ป้องกันเกมค้าง)")
print("⚙️ ตั้งค่า:")
print("   - รอระหว่างการส่ง: " .. MIN_WAIT .. "-" .. MAX_WAIT .. " วินาที")
print("   - ลองซ้ำสูงสุด: " .. REQUEUE_LIMIT .. " ครั้ง")
print("   - พักเมื่อ rate limit: " .. RATE_LIMIT_PAUSE .. " วินาที")
print("   - คูลดาวน์ขั้นต่ำ: " .. REQUEST_COOLDOWN .. " วินาที")

task.spawn(processQueue)
