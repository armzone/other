-- ฟังก์ชันตรวจสอบค่า text และสร้างไฟล์
local function checkTextAndCreateFile()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- หา TextLabel ตาม path ที่ให้มา
    local success, textLabel = pcall(function()
        return player.PlayerGui.MainUI.MenuFrame.BottomFrame.BottomExpand.CashFrame.Premium.ExpandFrame.TextLabel
    end)
    
    if not success then
        warn("❌ ไม่พบ TextLabel ตาม path ที่กำหนด")
        return false
    end
    
    -- ตรวจสอบค่า text
    local currentText = textLabel.Text
    print("🔍 ตรวจสอบค่า Text:", currentText)
    
    if currentText == "10000" then
        -- สร้างไฟล์
        local playerName = player.Name
        local fileName = playerName .. ".txt"
        local customMessage = "Completed-Somethingyouwantowritehere"
        
        -- เขียนไฟล์
        writefile(fileName, customMessage)
        
        print("✅ พบค่า 10000! สร้างไฟล์แล้ว:")
        print("   📁 ชื่อไฟล์:", fileName)
        print("   📝 ข้อความ:", customMessage)
        
        return true
    else
        print("⏳ ค่าปัจจุบัน:", currentText, "- รอให้เป็น 10000")
        return false
    end
end

-- ลูปตรวจสอบทุก 10 วินาที
print("🚀 เริ่มระบบตรวจสอบทุก 10 วินาที...")

while true do
    local success = checkTextAndCreateFile()
    
    if success then
        print("🏁 เสร็จสิ้น! หยุดการตรวจสอบ")
        break -- หยุดลูปเมื่อสร้างไฟล์แล้ว
    end
    
    wait(10) -- รอ 10 วินาทีก่อนตรวจสอบครั้งต่อไป
end

-- ส่งออกฟังก์ชันให้ใช้งานภายนอก
_G.checkTextAndCreateFile = checkTextAndCreateFile

print("✅ ระบบทำงานเสร็จสิ้น")
