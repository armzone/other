-- Made By Masterp (Enhanced: Requeue if failed)
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer.Character

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local PlayersQueue = {}
local isProcessing = false

-- เพิ่มผู้เล่นลงคิว (ไม่รวมตัวเอง)
local function addPlayer(player)
	if player ~= LocalPlayer and not table.find(PlayersQueue, player) then
		table.insert(PlayersQueue, player)
		print(player.Name .. " has been added to queue.")
	end
end

-- ลบผู้เล่นออกจากคิว
local function removePlayer(player)
	for i = #PlayersQueue, 1, -1 do
		if PlayersQueue[i] == player then
			table.remove(PlayersQueue, i)
			print(player.Name .. " has been removed from queue.")
		end
	end
end

-- เชื่อม event
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(removePlayer)

-- ใส่ผู้เล่นตอนเริ่ม
print("============== << INITIALIZING QUEUE >> ==============")
for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end

-- ส่งคำขอเป็นเพื่อนทีละคน
local function processQueue()
	while true do
		task.wait(1)
		if not isProcessing and #PlayersQueue > 0 then
			isProcessing = true
			local player = PlayersQueue[1]
			table.remove(PlayersQueue, 1)

			if player and player.Parent == Players then
				local success, result = pcall(function()
					return LocalPlayer:RequestFriendship(player)
				end)

				if success and result == true then
					print("✅ Friend request sent to: " .. player.Name)
					StarterGui:SetCore("SendNotification", {
						Title = "Friend Request Sent",
						Text = player.Name,
						Duration = 3
					})
				else
					print("❌ Failed to send friend request to: " .. player.Name .. " - Requeuing.")
					StarterGui:SetCore("SendNotification", {
						Title = "Friend Request Failed",
						Text = player.Name,
						Duration = 3
					})
					-- เพิ่มกลับไปในคิว
					table.insert(PlayersQueue, player)
				end
			else
				print("⚠️ Player is no longer in game: " .. (player and player.Name or "Unknown"))
			end

			isProcessing = false
			task.wait(3) -- รอระยะก่อนเริ่มรอบใหม่
		end
	end
end

-- เริ่มลูปประมวลผล
task.spawn(processQueue)
