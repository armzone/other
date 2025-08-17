local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlaceId = game.PlaceId
local ServerType = "Public"
local SortOrder = "Asc"
local ExcludeFullGames = true
local Limit = 100

local ApiUrl = string.format("https://games.roblox.com/v1/games/%d/servers/%s?sortOrder=%s&excludeFullGames=%s&limit=%d",
    PlaceId, ServerType, SortOrder, tostring(ExcludeFullGames), Limit)

function ListServers(cursor)
    local url = ApiUrl .. ((cursor and "&cursor="..cursor) or "")
    local response = game:HttpGet(url)
    return Http:JSONDecode(response)
end

-- สร้าง GUI ที่มี TextLabel สำหรับการนับถอยหลัง
local player = Players.LocalPlayer
local screenGui = Instance.new("ScreenGui")
local countdownLabel = Instance.new("TextLabel")
local countdownBackground = Instance.new("Frame") -- เพิ่มพื้นหลังให้กับ TextLabel

screenGui.Name = "CountdownGui"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- ตั้งค่า Frame สำหรับพื้นหลังของข้อความ
countdownBackground.Name = "CountdownBackground"
countdownBackground.Size = UDim2.new(0, 320, 0, 70) -- กำหนดขนาดของพื้นหลัง
countdownBackground.Position = UDim2.new(0.5, -160, 0.5, -35) -- กำหนดตำแหน่งของพื้นหลัง
countdownBackground.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- สีพื้นหลังเข้ม
countdownBackground.BackgroundTransparency = 0.3 -- ความโปร่งใสเล็กน้อย
countdownBackground.BorderSizePixel = 0 -- ไม่มีเส้นขอบ
countdownBackground.Parent = screenGui

-- กำหนดคุณสมบัติของ TextLabel
countdownLabel.Name = "CountdownLabel"
countdownLabel.Size = UDim2.new(1, -20, 1, -20) -- ขนาดลดลงเล็กน้อยเพื่อลงในพื้นหลัง
countdownLabel.Position = UDim2.new(0, 10, 0, 10) -- ขยับให้ตรงกับพื้นหลัง
countdownLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255) -- สีพื้นหลังของ TextLabel
countdownLabel.BackgroundTransparency = 1 -- ทำให้โปร่งใสทั้งหมด
countdownLabel.TextColor3 = Color3.fromRGB(0, 170, 255) -- สีข้อความ (สีฟ้าสดใส)
countdownLabel.TextScaled = true -- ขยายขนาดข้อความให้พอดี
countdownLabel.Font = Enum.Font.GothamBold -- เลือกฟอนต์
countdownLabel.Text = "Checking server..."
countdownLabel.Parent = countdownBackground

-- เพิ่มเอฟเฟกต์มุมโค้งให้กับพื้นหลัง
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 15) -- มุมโค้งมน
corner.Parent = countdownBackground

-- เพิ่มเส้นขอบสีสวย ๆ รอบพื้นหลัง
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Thickness = 3 -- ความหนาของเส้นขอบ
stroke.Color = Color3.fromRGB(0, 170, 255) -- สีฟ้าสดใส
stroke.Parent = countdownBackground

local foundSuitableServer = false

-- วนลูปตรวจสอบเซิร์ฟเวอร์เรื่อย ๆ ทุก 10 วินาที
while true do
    local Servers, Server, Next
    foundSuitableServer = false
    
    repeat
        Servers = ListServers(Next)
        for _, s in ipairs(Servers.data) do
            if s.playing <= 5 then  -- ตรวจสอบว่ามีผู้เล่นน้อยกว่าหรือเท่ากับ 5 คน
                Server = s
                foundSuitableServer = true
                break
            end
        end
        Next = Servers.nextPageCursor
    until Server or not Next  -- หากเจอเซิร์ฟเวอร์ที่ต้องการหรือไม่มีเซิร์ฟเวอร์เพิ่มเติม

    if foundSuitableServer then
        -- ตรวจสอบจำนวนผู้เล่นในเซิร์ฟเวอร์ปัจจุบัน
        local currentPlayerCount = #Players:GetPlayers()

        if currentPlayerCount > 5 then  -- เปลี่ยนตัวเลขตามความต้องการ
            countdownLabel.Text = "Teleporting in 5 seconds..."
            
            -- นับถอยหลัง 5 วินาที
            for i = 5, 1, -1 do
                countdownLabel.Text = "Teleporting in " .. i .. " seconds..."
                wait(1)
            end

            -- ทำการเทเลพอร์ตผู้เล่น
            TPS:TeleportToPlaceInstance(PlaceId, Server.id, player)
            countdownLabel.Text = "Teleporting now..."
            break  -- ออกจากลูป `while true` เมื่อเทเลพอร์ตสำเร็จ
        else
            countdownLabel.Text = "Current server has 5 or fewer players. Not teleporting."
        end
    else
        countdownLabel.Text = "All servers have more than 5 players. Staying in the current server."
    end

    -- รอ 10 วินาทีก่อนจะตรวจสอบเซิร์ฟเวอร์ใหม่อีกครั้ง
    wait(10)
end
