-- Enhanced Friend Request Script with Proper Error Handling
-- Made By Masterp (Fixed by Assistant)

repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer.Character

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local PlayersQueue = {}
local isProcessing = false
local RequeueCount = {}

-- ตั้งค่า
local REQUEUE_LIMIT = 3
local MIN_WAIT = 60 -- 60 วินาที
local MAX_WAIT = 120 -- 120 วินาที
local RATE_LIMIT_PAUSE = 300 -- พัก 5 นาที (300 วินาที) เมื่อเจอ rate limit

-- ฟังก์ชันสุ่มเวลารอ
local function getRandomWait()
    return math.random(MIN_WAIT, MAX_WAIT)
end

-- ลบฟังก์ชันเช็ค friend limit ออกตามที่ขอ

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

-- ฟังก์ชันส่งคำขอเป็นเพื่อน
local function sendFriendRequest(player)
    local success, result = pcall(function()
        return LocalPlayer:RequestFriendship(player)
    end)
    
    return success, result
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

-- ส่งคำขอเป็นเพื่อนทีละคน
local function processQueue()
    while true do
        if #PlayersQueue > 0 and not isProcessing then
            isProcessing = true
            
            local player = PlayersQueue[1]
            table.remove(PlayersQueue, 1)
            
            if player and player.Parent == Players then
                print("🔄 กำลังส่ง friend request ไปยัง: " .. player.Name)
                
                local success, result = sendFriendRequest(player)
                local resultType = handleResult(player, success, result)
                
                if resultType == "success" or resultType == "possible_success" then
                    -- ส่งสำเร็จ (รวมกรณีที่อาจสำเร็จแต่ API ตอบผิด)
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
                    task.wait(RATE_LIMIT_PAUSE)
                    continue
                    
                elseif resultType == "already_friends" then
                    print("👥 " .. player.Name .. " เป็นเพื่อนอยู่แล้วหรือรอการยืนยัน")
                    -- ไม่ต้องแจ้งเตือน เพราะไม่ใช่ error จริง
                    
                elseif resultType == "friend_limit_full" then
                    print("🛑 Friend limit เต็มแล้ว หยุดการทำงาน")
                    StarterGui:SetCore("SendNotification", {
                        Title = "Friend Limit Full 🛑",
                        Text = "ไม่สามารถเพิ่มเพื่อนได้แล้ว",
                        Duration = 5
                    })
                    break
                    
                else
                    -- Error อื่นๆ ที่เป็น error จริง
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
            else
                print("⚠️ ผู้เล่นออกจากเกมแล้ว: " .. (player and player.Name or "Unknown"))
            end
            
            isProcessing = false
            
            -- รอเวลาสุ่มก่อนประมวลผลคนต่อไป
            local waitTime = getRandomWait()
            print("⏳ รอ " .. waitTime .. " วินาที ก่อนส่งคนต่อไป...")
            task.wait(waitTime)
        else
            -- ไม่มีคิวหรือกำลังประมวลผล รอ 5 วินาที
            task.wait(5)
        end
    end
    
    print("🏁 จบการทำงาน - ไม่มีผู้เล่นในคิวแล้ว")
end

-- เริ่มลูปประมวลผล
print("🚀 เริ่มต้นระบบส่ง Friend Request")
print("⚙️ ตั้งค่า:")
print("   - รอระหว่างการส่ง: " .. MIN_WAIT .. "-" .. MAX_WAIT .. " วินาที")
print("   - ลองซ้ำสูงสุด: " .. REQUEUE_LIMIT .. " ครั้ง")
print("   - พักเมื่อ rate limit: " .. RATE_LIMIT_PAUSE .. " วินาที")

task.spawn(processQueue)
