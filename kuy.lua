-- 🛡️ Anti-Data Leak Detector
-- รันก่อนสคริปต์อื่น ๆ
-- แจ้งเตือนทันทีเมื่อมีการดึงข้อมูลส่วนตัว
-- รองรับ: JobId, HardwareId, IP, UserId, Username

repeat wait() until game:IsLoaded()
local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- สร้างหน้าต่างแจ้งเตือน
local function Notify(title, text)
    game.StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = text,
        Duration = 10,
        Button1 = "OK"
    })
    print("[⚠️ Anti-Leak] " .. title .. ": " .. text)
end

-- 1. ป้องกันการดึง Hardware ID
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")
local original_GetClientId = RbxAnalyticsService.GetClientId

RbxAnalyticsService.GetClientId = newcclosure(function(self, ...)
    local source = debug.info(2, 's') or "Unknown"
    Notify("ตรวจพบ!", "สคริปต์พยายามดึง Hardware ID")
    Notify("แหล่งที่มา", "จาก: " .. source)
    return "HACKED-HWID-PROTECTED" -- ปลอมค่าที่ส่งออกไป
end)

-- 2. ป้องกันการดึง JobId
local mt = getrawmetatable(game)
setreadonly(mt, false)
local original_index = mt.__index

mt.__index = newcclosure(function(t, k)
    if t == game and k == "JobId" then
        local source = debug.info(2, 's') or "Unknown"
        Notify("ตรวจพบ!", "สคริปต์พยายามอ่าน game.JobId")
        Notify("แหล่งที่มา", "จาก: " .. source)
        return "FAKE-JOBID-PROTECTED"
    end
    return original_index(t, k)
end)

-- 3. ป้องกันการดึง IP ผ่าน http_request
local original_http_request = http_request or request or syn.request

if original_http_request then
    http_request = newcclosure(function(request_table)
        local url = request_table.Url or request_table.url
        if type(url) == "string" then
            -- ตรวจจับ API ที่ดึง IP
            if string.find(url, "ip%-api") or string.find(url, "ipinfo") or string.find(url, "geo") then
                Notify("ตรวจพบ!", "สคริปต์พยายามดึง IP ของคุณ")
                Notify("URL", url)
                return { Success = true, Body = '{"ip":"127.0.0.1 (Blocked)"}' }
            end

            -- ตรวจจับ Webhook
            if string.find(url, "discord%.com/api/webhooks/") then
                local body = request_table.Body or "{}"
                if string.find(body, "JobId") or string.find(body, "Hardware") or string.find(body, "UserId") then
                    Notify("ตรวจพบ!", "สคริปต์พยายามส่งข้อมูลของคุณไปยัง Discord Webhook!")
                    Notify("URL", url)
                    return { Success = false, StatusMessage = "Request blocked by Anti-Leak" }
                end
            end
        end
        return original_http_request(request_table)
    end)

    -- ป้องกัน request, syn.request
    getgenv().request = http_request
    getgenv().syn = getgenv().syn and setmetatable({ request = http_request }, {}) or nil
end

-- 4. ป้องกันการคัดลอก JobId ไปยังคลิปบอร์ด
local original_setclipboard = setclipboard
setclipboard = newcclosure(function(text)
    if string.find(tostring(text), game.JobId) or string.find(tostring(text), player.UserId) then
        Notify("ตรวจพบ!", "สคริปต์พยายามคัดลอก JobId หรือ UserId ของคุณ!")
        Notify("ข้อมูล", tostring(text))
        return
    end
    return original_setclipboard(text)
end)

-- 5. แจ้งเตือนเมื่อมีการเข้าถึงข้อมูลผู้เล่นโดยตรง
local original_Player = {}
for k, v in pairs(player) do
    original_Player[k] = v
end

local player_mt = getrawmetatable(player)
setreadonly(player_mt, false)
local original_player_index = player_mt.__index

player_mt.__index = newcclosure(function(t, k)
    if t == player and (k == "UserId" or k == "Name" or k == "DisplayName") then
        local source = debug.info(2, 's') or "Unknown"
        if debug.info(2, 'n') ~= "getgenv" then -- ยกเว้นการอ่านจาก getgenv()
            Notify("ตรวจสอบ", k .. " ถูกอ่านโดยสคริปต์อื่น")
            Notify("จาก", source)
        end
    end
    return original_player_index(t, k)
end)

-- ✅ ติดตั้งสำเร็จ
Notify("🛡️ Anti-Data Leak", "ระบบป้องกันข้อมูลรั่วไหลถูกเปิดใช้งานแล้ว")
print("✅ Anti-Leak Detector ทำงานแล้ว — กำลังตรวจจับสคริปต์อันตราย...")


spawn(function()
    wait(5)
    print("ทดสอบ: อ่าน JobId")
    print(game.JobId) -- จะถูกจับ
end)
