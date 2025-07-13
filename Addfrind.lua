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
local FRIEND_LIMIT = 50 -- หยุดเมื่อมีเพื่อน 50 คน
local MIN_WAIT = 60 -- 60 วินาที
local MAX_WAIT = 120 -- 120 วินาที
local RATE_LIMIT_PAUSE = 300 -- พัก 5 นาที (300 วินาที) เมื่อเจอ rate limit

-- ฟังก์ชันสุ่มเวลารอ
local function getRandomWait()
    return math.random(MIN_WAIT, MAX_WAIT)
end

-- ฟังก์ชันเช็คจำนวนเพื่อนปัจจุบัน
local function getCurrentFriendCount()
    local success, result = pcall(function()
        -- ใช้ HTTP request เพื่อเช็คจำนวนเพื่อนจริง
        local url = "https://friends.roblox.com/v1/users/" .. LocalPlayer.UserId .. "/friends/count"
        local response = HttpService:GetAsync(url)
        local data = HttpService:JSONDecode(response)
        return data.count or 0
    end)
    
    if success then
        return result
    else
        print("⚠️ ไม่สามารถเช็คจำนวนเพื่อนได้, ใช้วิธีสำรอง...")
        -- วิธีสำรอง: นับจาก GetFriendsOnline (ไม่แม่นยำ)
        local friends = LocalPlayer:GetFriendsOnline()
        return #friends
    end
end

-- ฟังก์ชันเช็คว่าถึง friend limit หรือยัง
local function isFriendLimitReached()
    local currentCount = getCurrentFriendCount()
    print("📊 จำนวนเพื่อนปัจจุบัน:", currentCount, "/", FRIEND_LIMIT)
    return currentCount >= FRIEND_LIMIT
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

-- ฟังก์ชันส่งคำขอเป็นเพื่อน
local function sendFriendRequest(player)
    local success, result = pcall(function()
        return LocalPlayer:RequestFriendship(player)
    end)
    
    return success, result
end

-- ฟังก์ชันตรวจสอบประเภทของ error
local function handleError(player, result)
    local errorMsg = tostring(result):lower()
    
    -- เช็คว่าเป็น rate limiting หรือไม่
    if errorMsg:find("too many requests") or errorMsg:find("rate limit") or errorMsg:find("flood") then
        return "rate_limit"
    end
    
    -- เช็คว่าเป็นเพื่อนอยู่แล้วหรือ pending
    if errorMsg:find("already friends") or errorMsg:find("pending") then
        return "already_friends"
    end
    
    -- เช็คว่า friend limit เต็ม
    if errorMsg:find("friend limit") or errorMsg:find("too many friends") then
        return "friend_limit_full"
    end
    
    -- Error อื่นๆ
    return "other_error"
end

-- ส่งคำขอเป็นเพื่อนทีละคน
local function processQueue()
    while true do
        if #PlayersQueue > 0 and not isProcessing then
            isProcessing = true
            
            -- เช็ค friend limit ก่อนเริ่ม
            if isFriendLimitReached() then
                print("🛑 ถึงจำนวนเพื่อนสูงสุดแล้ว (" .. FRIEND_LIMIT .. ") หยุดการทำงาน")
                StarterGui:SetCore("SendNotification", {
                    Title = "Friend Limit Reached",
                    Text = "มีเพื่อน " .. FRIEND_LIMIT .. " คนแล้ว",
                    Duration = 5
                })
                break
            end
            
            local player = PlayersQueue[1]
            table.remove(PlayersQueue, 1)
            
            if player and player.Parent == Players then
                print("🔄 กำลังส่ง friend request ไปยัง: " .. player.Name)
                
                local success, result = sendFriendRequest(player)
                
                if success and result == true then
                    -- ส่งสำเร็จ
                    print("✅ ส่ง friend request ไปยัง: " .. player.Name .. " สำเร็จ")
                    StarterGui:SetCore("SendNotification", {
                        Title = "Friend Request Sent ✅",
                        Text = player.Name,
                        Duration = 3
                    })
                    
                    -- ล้างข้อมูล requeue
                    RequeueCount[player.UserId] = nil
                    
                else
                    -- ส่งไม่สำเร็จ
                    local errorType = handleError(player, result)
                    
                    if errorType == "rate_limit" then
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
                        
                    elseif errorType == "already_friends" then
                        print("👥 " .. player.Name .. " เป็นเพื่อนอยู่แล้วหรือรอการยืนยัน")
                        
                    elseif errorType == "friend_limit_full" then
                        print("🛑 Friend limit เต็มแล้ว หยุดการทำงาน")
                        StarterGui:SetCore("SendNotification", {
                            Title = "Friend Limit Full 🛑",
                            Text = "ไม่สามารถเพิ่มเพื่อนได้แล้ว",
                            Duration = 5
                        })
                        break
                        
                    else
                        -- Error อื่นๆ
                        RequeueCount[player.UserId] = (RequeueCount[player.UserId] or 0) + 1
                        
                        if RequeueCount[player.UserId] <= REQUEUE_LIMIT then
                            print("❌ ส่ง friend request ไปยัง: " .. player.Name .. " ไม่สำเร็จ - ลองใหม่ครั้งที่ " .. RequeueCount[player.UserId])
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
    
    print("🏁 จบการทำงาน - ไม่มีผู้เล่นในคิวหรือถึง friend limit แล้ว")
end

-- เริ่มลูปประมวลผล
print("🚀 เริ่มต้นระบบส่ง Friend Request")
print("⚙️ ตั้งค่า:")
print("   - รอระหว่างการส่ง: " .. MIN_WAIT .. "-" .. MAX_WAIT .. " วินาที")
print("   - Friend limit: " .. FRIEND_LIMIT .. " คน")
print("   - ลองซ้ำสูงสุด: " .. REQUEUE_LIMIT .. " ครั้ง")
print("   - พักเมื่อ rate limit: " .. RATE_LIMIT_PAUSE .. " วินาที")

task.spawn(processQueue)
