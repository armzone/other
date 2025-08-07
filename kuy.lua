-- ✅ Anti-Leak JobId Spoofer (Safe for Delta / No bitwise)

if not getrawmetatable or not setreadonly or not newcclosure then
    warn("❌ Executor นี้ไม่รองรับฟังก์ชันจำเป็น")
    return
end

-- ✅ UUID4 generator (no bitwise)
local function generateUUID4()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local r = math.random(0, 15)
        local v
        if c == "x" then
            v = r
        else
            -- simulate (r & 0x3 | 0x8) → only possible values: 8-11
            v = ({8, 9, 10, 11})[(r % 4) + 1]
        end
        return string.format("%x", v)
    end)
end

-- 📦 ค่าปลอมปัจจุบัน
local fakeJobId = generateUUID4()
print("🔁 Spoofed JobId started with:", fakeJobId)

-- ⏱ สุ่มใหม่ทุก 60 วินาที
task.spawn(function()
    while true do
        task.wait(60)
        fakeJobId = generateUUID4()
        print("🕒 Updated JobId →", fakeJobId)
    end
end)

-- 💥 Hook __index
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old_index = mt.__index

mt.__index = newcclosure(function(t, k)
    if t == game and k == "JobId" then
        return fakeJobId
    end
    return old_index(t, k)
end)

-- 🔍 ทดสอบแสดงผล
print("✅ Current JobId is now:", game.JobId)
