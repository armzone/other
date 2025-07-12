-- Made By Masterp (Enhanced: Requeue if failed, Add Limit, Handle Special Errors)
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer.Character

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer

local PlayersQueue = {}
local isProcessing = false
local RequeueCount = {}
local REQUEUE_LIMIT = 3 -- จำนวนครั้งสูงสุดที่ Requeue
local FRIEND_LIMIT = 200 -- จำนวนเพื่อนสูงสุดใน Roblox

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

-- ฟังก์ชันเช็คเพื่อนเต็มหรือยัง
local function isFriendLimitReached()
	local success, friends = pcall(function()
		return LocalPlayer:GetFriendsOnline()
	end)
	return success and #friends >= FRIEND_LIMIT
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
				-- เช็ค friend เต็ม
				if isFriendLimitReached() then
					print("❗ Friend limit reached. Stopping friend requests.")
					StarterGui:SetCore("SendNotification", {
						Title = "Friend Limit",
						Text = "You have reached your friend limit.",
						Duration = 4
					})
					break -- ออกจาก while true
				end

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
					local msg = tostring(result)
					-- ถ้า already friends หรือกำลัง pending อยู่ จะไม่ requeue
					if msg:find("already friends") or msg:find("pending") then
						print("⚠️ Already friends or pending: " .. player.Name)
					else
						RequeueCount[player.UserId] = (RequeueCount[player.UserId] or 0) + 1
						if RequeueCount[player.UserId] <= REQUEUE_LIMIT then
							print("❌ Failed to send friend request to: " .. player.Name .. " - Requeuing ("..RequeueCount[player.UserId]..")")
							StarterGui:SetCore("SendNotification", {
								Title = "Friend Request Failed",
								Text = player.Name .. " (Retry: "..RequeueCount[player.UserId]..")",
								Duration = 3
							})
							table.insert(PlayersQueue, player)
						else
							print("🚫 Skipping " .. player.Name .. " after "..REQUEUE_LIMIT.." failed attempts.")
							StarterGui:SetCore("SendNotification", {
								Title = "Friend Request Skipped",
								Text = player.Name,
								Duration = 3
							})
						end
					end
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
