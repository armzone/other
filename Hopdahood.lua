-- วางเป็น LocalScript ใน StarterPlayerScripts

local Http = game:GetService("HttpService")
local TPS = game:GetService("TeleportService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- ====== CONFIG ======
local MAX_ALLOWED = 5          -- ถ้าห้องเรามีคน > ตัวเลขนี้ จะหาห้องใหม่
local CHECK_INTERVAL = 10      -- วินาที เช็คแต่ละครั้ง
local COUNTDOWN = 5            -- นับถอยหลังก่อนเทเลพอร์ต
local ServerType = "Public"
local SortOrder = "Asc"
local ExcludeFullGames = true
local Limit = 100
-- ====================

local PlaceId = game.PlaceId
local ApiUrl = string.format(
    "https://games.roblox.com/v1/games/%d/servers/%s?sortOrder=%s&excludeFullGames=%s&limit=%d",
    PlaceId, ServerType, SortOrder, tostring(ExcludeFullGames), Limit
)

-- สร้าง/ดึง GUI และทำให้ไม่หายตอนรีสปอน
local function getOrCreateGui()
    local pg = player:WaitForChild("PlayerGui")
    local screenGui = pg:FindFirstChild("CountdownGui")
    if not screenGui then
        screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CountdownGui"
        screenGui.ResetOnSpawn = false -- สำคัญ! กันหายตอนตาย/รีสปอน
        screenGui.Parent = pg

        local bg = Instance.new("Frame")
        bg.Name = "CountdownBackground"
        bg.Size = UDim2.new(0, 320, 0, 70)
        bg.Position = UDim2.new(0.5, -160, 0.5, -35)
        bg.BackgroundColor3 = Color3.fromRGB(45,45,45)
        bg.BackgroundTransparency = 0.3
        bg.BorderSizePixel = 0
        bg.Parent = screenGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 15)
        corner.Parent = bg

        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 3
        stroke.Color = Color3.fromRGB(0,170,255)
        stroke.Parent = bg

        local label = Instance.new("TextLabel")
        label.Name = "CountdownLabel"
        label.Size = UDim2.new(1, -20, 1, -20)
        label.Position = UDim2.new(0, 10, 0, 10)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(0,170,255)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.Text = "Checking server..."
        label.Parent = bg
    end
    return screenGui, screenGui:WaitForChild("CountdownBackground"):WaitForChild("CountdownLabel")
end

local function listServers(cursor)
    local url = ApiUrl .. (cursor and ("&cursor="..cursor) or "")
    local response = game:HttpGet(url)
    return Http:JSONDecode(response)
end

-- สุ่มเซิร์ฟเวอร์ที่คน ≤ MAX_ALLOWED และไม่ใช่ห้องปัจจุบัน
local function findRandomServer()
    local pool = {}
    local nextCursor = nil
    repeat
        local page = listServers(nextCursor)
        for _, s in ipairs(page.data or {}) do
            local count = tonumber(s.playing) or tonumber(s.playerCount) or 0
            if s.id and s.id ~= game.JobId and count <= MAX_ALLOWED then
                table.insert(pool, s)
            end
        end
        nextCursor = page.nextPageCursor
        task.wait() -- ผ่อนภาระ
    until not nextCursor

    if #pool > 0 then
        return pool[math.random(1, #pool)]
    end
    return nil
end

-- ลูปเฝ้ารอ (อยู่ได้ข้ามการรีสปอนเพราะสคริปต์อยู่ใน StarterPlayerScripts)
local running = false
local function startWatcher()
    if running then return end
    running = true

    local _, label = getOrCreateGui()

    while running do
        label.Text = "Checking server..."
        local currentCount = #Players:GetPlayers()

        if currentCount > MAX_ALLOWED then
            local target = findRandomServer()
            if target then
                for i = COUNTDOWN, 1, -1 do
                    label.Text = ("Teleporting in %d seconds..."):format(i)
                    task.wait(1)
                end
                label.Text = "Teleporting now..."
                TPS:TeleportToPlaceInstance(PlaceId, target.id, player)
                -- หลังจากเรียก Teleport โค้ดอาจหยุดต่อ (กำลังย้ายเซิร์ฟ)
                return
            else
                label.Text = ("No suitable server (≤ %d players). Retrying..."):format(MAX_ALLOWED)
            end
        else
            label.Text = ("Current server OK (≤ %d players). Recheck in %ds."):format(MAX_ALLOWED, CHECK_INTERVAL)
        end

        task.wait(CHECK_INTERVAL)
    end
end

-- เริ่มทำงานทันที
startWatcher()

-- เผื่อบางเกมรีเซ็ต GUI ตอนรีสปอน: ผูกกับ CharacterAdded ให้แน่ใจว่า GUI ถูกสร้างซ้ำ
player.CharacterAdded:Connect(function()
    task.defer(function()
        getOrCreateGui()
    end)
end)
