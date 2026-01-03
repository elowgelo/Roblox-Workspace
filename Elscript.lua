--[[
	SCRIPT OPTIMIZED & FIXED BY GEMINI
	---------------------------------
	Perubahan (Update):
	- Default "Show ESP Text" diubah menjadi FALSE (Teks tidak muncul saat awal run).
	- Menambahkan Toggle "Show ESP Text" untuk menampilkan nama/info jika dibutuhkan.
	- Sistem ESP Player & Komputer tetap berjalan normal.
]]

-- Load Rayfield UI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Welcome in ElHub!",
	LoadingTitle = "Patience is a key..",
	LoadingSubtitle = "Elproject",
	ConfigurationSaving = {
		Enabled = true,
		FolderName = nil,
		FileName = "FIVE NIGHT: HUNTED"
	},
	Discord = {
		Enabled = false
	},
	KeySystem = false
})

--==================================================--
--[[               SERVICE & LOCALS               ]]--
--==================================================--
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--==================================================--
--[[              AUTO HEART BEAT                 ]]--
--==================================================--
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14
local Knit, Vetween, HeartbeatController, SoundController, HeartbeatGui
local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

local function initializeHeartbeatReferences()
	if Knit and HeartbeatController and SoundController and HeartbeatGui and Vetween then return true end
	local successKnit, knitModule = pcall(require, ReplicatedStorage.Packages.Knit)
	if not successKnit then warn("AutoHeartbeat: Gagal memuat Knit:", knitModule) return false end
	Knit = knitModule
	local successVetween, vetweenModule = pcall(require, ReplicatedStorage.Packages.Vetween)
	if not successVetween then warn("AutoHeartbeat: Gagal memuat Vetween:", vetweenModule) return false end
	Vetween = vetweenModule
	local controllerFetchAttempts = 0
	while not HeartbeatController and controllerFetchAttempts < 50 do
		HeartbeatController = Knit.GetController("HeartbeatController")
		if not HeartbeatController then controllerFetchAttempts = controllerFetchAttempts + 1; task.wait(0.1) end
	end
	if not HeartbeatController then warn("AutoHeartbeat: HeartbeatController tidak ditemukan.") return false end
	SoundController = Knit.GetController("SoundController")
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
	if HeartbeatGui then HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5) end
	if not HeartbeatGui then warn("AutoHeartbeat: Heartbeat GUI tidak ditemukan.") return false end
	if not (HeartbeatController and HeartbeatController.Trigger) then warn("AutoHeartbeat: HeartbeatController.Trigger tidak valid.") return false end
	return true
end
local function getCurrentHeartbeatGameStateAndStatus()
	if not HeartbeatController or not HeartbeatController.Trigger then return nil, false end
	local _, currentIsActive = pcall(debug.getupvalue, HeartbeatController.Trigger, 1)
	local _, currentGameState = pcall(debug.getupvalue, HeartbeatController.Trigger, 6)
	return currentGameState, currentIsActive
end
local function onHeartbeatRenderStep()
	if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then return end
	local currentLocalState, isGameActive = getCurrentHeartbeatGameStateAndStatus()
	if not (isGameActive and currentLocalState and currentLocalState.InitTick and currentLocalState.Beats and currentLocalState.Notes and #currentLocalState.Notes > 0) then return end
	local gameTime = tick() - currentLocalState.InitTick
	local bestNoteToHit, smallestTimeDifferenceToHitPoint = nil, math.huge
	for i, noteInfo in ipairs(currentLocalState.Notes) do
		local beatIndex = noteInfo[1]
		if currentLocalState.Beats[beatIndex] then
			local targetTime, timeUntilHit = currentLocalState.Beats[beatIndex], currentLocalState.Beats[beatIndex] - gameTime
			local diffFromIdealClick = timeUntilHit - HIT_OFFSET_SECONDS
			if math.abs(diffFromIdealClick) <= PERFECT_WINDOW_SECONDS and math.abs(diffFromIdealClick) < smallestTimeDifferenceToHitPoint then
				smallestTimeDifferenceToHitPoint = math.abs(diffFromIdealClick)
				bestNoteToHit = { noteData = noteInfo, arrayIndex = i, timeError = gameTime - targetTime }
			end
		end
	end
	if bestNoteToHit then
		local noteData, beatIndex, noteObject, arrayIndex, timeError = bestNoteToHit.noteData, bestNoteToHit.noteData[1], bestNoteToHit.noteData[2], bestNoteToHit.arrayIndex, bestNoteToHit.timeError
		if table.find(currentLocalState.Passed, beatIndex) then return end
		if math.abs(timeError) < PERFECT_WINDOW_SECONDS then
			if SoundController then pcall(SoundController.PlaySound, SoundController, "SingleHeartbeat") end
			HeartbeatGui.Playfield.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			HeartbeatGui.Playfield.BackgroundTransparency = 0
			currentLocalState.Stats.Perfect = currentLocalState.Stats.Perfect + 1
			Vetween.new(HeartbeatGui.Playfield, Vetween.newInfo(0.5, Vetween.Style.Linear), { ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0), ["BackgroundTransparency"] = 1 }):Play()
			if noteObject and noteObject.Parent then noteObject:Destroy() end
			table.insert(currentLocalState.Passed, beatIndex)
			table.remove(currentLocalState.Notes, arrayIndex)
			if HeartbeatGui.UIScale then
				HeartbeatGui.UIScale.Scale = 1.1
				Vetween.new(HeartbeatGui.UIScale, Vetween.newInfo(2, Vetween.Style.Quint), { ["Scale"] = 1 }):Play()
			end
		end
	end
end
local function enableAutoHeartbeat(enable)
	heartbeatAutoClickerActive = enable
	if enable then
		if not (Knit and Vetween and HeartbeatGui and HeartbeatController) then
			if not initializeHeartbeatReferences() then
				Rayfield:Notify({Title = "Auto Heartbeat", Content = "Gagal menginisialisasi modul.", Duration = 5, Image = 4483362458})
				heartbeatAutoClickerActive = false; return false 
			end
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Diaktifkan!", Duration = 5, Image = 4483362458})
	else
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Dinonaktifkan!", Duration = 5, Image = 4483362458})
	end
	return true 
end

--==================================================--
--[[      ESP SYSTEM (OPTIMIZED FROM ORIGINAL)    ]]--
--==================================================--
local espEnabled = false
local computerESPEnabled = false
-- [PERUBAHAN]: Default diubah menjadi false agar teks tidak muncul otomatis
local showESPText = false 
local trackedModels = {} 
local ESP_UPDATE_INTERVAL = 0.25

-- Fungsi untuk membersihkan elemen ESP dari sebuah model
local function clearESP(model)
	if not model or not trackedModels[model] then return end
	local espElements = trackedModels[model]
	if espElements.Tag and espElements.Tag.Parent then espElements.Tag:Destroy() end
	if espElements.Highlight and espElements.Highlight.Parent then espElements.Highlight:Destroy() end
	trackedModels[model] = nil
end

-- Fungsi yang dioptimalkan untuk membuat/memperbarui ESP
local function createOrUpdateESP(model, labelText, fillColor, progressText)
	if not model or not model:IsA("Model") then return end

	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local espInfo = trackedModels[model] or {}
	local displayText = labelText
	if progressText then displayText = displayText .. "\n" .. progressText end
	
	-- Membuat Tag jika belum ada
	if not espInfo.Tag or not espInfo.Tag.Parent then
		local gui = Instance.new("BillboardGui", model); gui.Name = "ESPTag"; gui.Adornee = root; gui.Size = UDim2.new(0, 150, 0, 60); gui.StudsOffset = Vector3.new(0, 5, 0); gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.ResetOnSpawn = false
		local text = Instance.new("TextLabel", gui); text.Name = "ESPText"; text.Size = UDim2.new(1, 0, 1, 0); text.BackgroundTransparency = 1; text.TextColor3 = fillColor; text.Font = Enum.Font.GothamSemibold; text.TextSize = 14; text.TextWrapped = true; text.RichText = true
		text.TextTransparency = 0.2; text.TextStrokeTransparency = 0.5
		espInfo.Tag = gui
	end
	
	-- Update properti text
	espInfo.Tag.ESPText.Text = displayText
	espInfo.Tag.ESPText.TextColor3 = fillColor
	espInfo.Tag.Adornee = root
	
	-- [PERUBAHAN]: Memastikan visibilitas mengikuti variabel showESPText
	espInfo.Tag.Enabled = showESPText 
	
	-- Membuat Highlight jika belum ada
	if not espInfo.Highlight or not espInfo.Highlight.Parent then
		local hl = Instance.new("Highlight", model); hl.Name = "ESPHighlight"; hl.Adornee = model; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		espInfo.Highlight = hl
	end
	
	espInfo.Highlight.FillColor = fillColor; espInfo.Highlight.OutlineColor = Color3.new(fillColor.r * 0.7, fillColor.g * 0.7, fillColor.b * 0.7)
	espInfo.Highlight.FillTransparency = 0.8; espInfo.Highlight.OutlineTransparency = 0.6
	
	trackedModels[model] = espInfo
end

-- FUNGSI SCAN PLAYER
local function scanAllPlayers()
    if not espEnabled then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local role = player:GetAttribute("Role")

            local color = Color3.fromRGB(220, 220, 220)
            if role == "Monster" then
                color = Color3.fromRGB(255, 50, 50)
            elseif role == "Survivor" then
                color = Color3.fromRGB(255, 236, 161)
            end

            createOrUpdateESP(char, player.Name, color)
        end
    end
end

-- FUNGSI SCAN KOMPUTER
local function scanComputersESP()
	if not computerESPEnabled then return end
	local tasksFolder = Workspace:FindFirstChild("Tasks", true)
	if not tasksFolder then return end
	for _, item in ipairs(tasksFolder:GetChildren()) do 
		if item:IsA("Model") and item.Name:lower() == "computer" then
			local progress = item:GetAttribute("Progress"); local completed = item:GetAttribute("Completed"); local progressText, espColor
			if completed then progressText = "Completed"; espColor = Color3.fromRGB(100, 150, 255) elseif type(progress) == "number" then progressText = string.format("Progress: %.1f", progress); espColor = Color3.fromRGB(50, 255, 50) else progressText = "Progress: N/A"; espColor = Color3.fromRGB(50, 255, 50) end
			createOrUpdateESP(item, "COMPUTER", espColor, progressText)
		end
	end
end

-- Loop utama ESP
task.spawn(function()
	while true do
		-- Hapus ESP dari model yang sudah tidak ada
		for model in pairs(trackedModels) do
			if not model or not model.Parent then
				clearESP(model)
			end
		end

		if espEnabled then
			pcall(scanAllPlayers)
		end
		
		if computerESPEnabled then
			pcall(scanComputersESP)
		end
		
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)

-- Membersihkan ESP saat player keluar
Players.PlayerRemoving:Connect(function(player)
    if player.Character and trackedModels[player.Character] then
        clearESP(player.Character)
    end
end)

--==================================================--
--[[            MOVEMENT (OPTIMIZED)              ]]--
--==================================================--
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

local function setNoclip(character, enabled)
	if not character then return end
	pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = not enabled end
		end
	end)
end

--==================================================--
--[[                 UI TOGGLES                   ]]--
--==================================================--
local MainTab = Window:CreateTab("Main", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)

MainTab:CreateToggle({ Name = "Auto Heartbeat", CurrentValue = heartbeatAutoClickerActive, Flag = "AutoHeartbeatEnabled", Callback = function(Value) if not enableAutoHeartbeat(Value) and Value then heartbeatAutoClickerActive = false; Rayfield:SetFlag("AutoHeartbeatEnabled", false) end end })

-- ESP TOGGLES
MainTab:CreateSection("ESP Options")
MainTab:CreateToggle({ Name = "ESP Player", CurrentValue = espEnabled, Flag = "ESPEnabled", Callback = function(Value) espEnabled = Value; if not Value then for object in pairs(trackedModels) do if object:IsA("Player") or (object:FindFirstChild("Humanoid") and object ~= LocalPlayer.Character) then clearESP(object) end end end end })
MainTab:CreateToggle({ Name = "ESP Computer", CurrentValue = computerESPEnabled, Flag = "ComputerESPEnabled", Callback = function(Value) computerESPEnabled = Value; if not Value then for object in pairs(trackedModels) do if object.Name:lower() == "computer" then clearESP(object) end end end end })

-- TOGGLE BARU: SHOW ESP TEXT (DEFAULT: FALSE)
MainTab:CreateToggle({ 
	Name = "Show ESP Text", 
	CurrentValue = showESPText, -- Mengikuti variabel lokal (False)
	Flag = "ShowESPText", 
	Callback = function(Value) 
		showESPText = Value
		-- Update instan untuk semua ESP yang sedang aktif
		for _, espInfo in pairs(trackedModels) do
			if espInfo.Tag then
				espInfo.Tag.Enabled = Value
			end
		end
	end 
})

MovementTab:CreateSlider({ Name = "Speed Hack (WalkSpeed)", Range = {16, 100}, Increment = 1, Suffix = "Speed", CurrentValue = 16, Flag = "SpeedHackSlider", Callback = function(Value) targetSpeed = Value; local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = Value end end })

MovementTab:CreateToggle({
	Name = "Persistent Speed (Anti-Reset)",
	CurrentValue = false,
	Flag = "PersistentSpeedToggle",
	Callback = function(Value)
		persistentSpeedEnabled = Value
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
		if Value and hum then
			hum.WalkSpeed = targetSpeed
			speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
			end)
		end
	end,
})

MovementTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(Value)
		noclipActive = Value
		setNoclip(LocalPlayer.Character, noclipActive)
	end,
})
-- Handle Noclip saat respawn
LocalPlayer.CharacterAdded:Connect(function(character)
	if noclipActive then
		task.wait(0.1) -- Beri sedikit jeda agar semua part termuat
		setNoclip(character, true)
	end
end)

Rayfield:Notify({ Title = "ElHub Loaded!", Content = "Selamat datang di ElHub. (Optimized & Fixed)", Duration = 7, Image = 4483362458 })
local LocalPlayer = Players.LocalPlayer

--==================================================--
--[[              AUTO HEART BEAT                 ]]--
--==================================================--
-- Bagian ini tidak diubah dan seharusnya berfungsi seperti sebelumnya.
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14
local Knit, Vetween, HeartbeatController, SoundController, HeartbeatGui
local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

local function initializeHeartbeatReferences()
	if Knit and HeartbeatController and SoundController and HeartbeatGui and Vetween then return true end
	local successKnit, knitModule = pcall(require, ReplicatedStorage.Packages.Knit)
	if not successKnit then warn("AutoHeartbeat: Gagal memuat Knit:", knitModule) return false end
	Knit = knitModule
	local successVetween, vetweenModule = pcall(require, ReplicatedStorage.Packages.Vetween)
	if not successVetween then warn("AutoHeartbeat: Gagal memuat Vetween:", vetweenModule) return false end
	Vetween = vetweenModule
	local controllerFetchAttempts = 0
	while not HeartbeatController and controllerFetchAttempts < 50 do
		HeartbeatController = Knit.GetController("HeartbeatController")
		if not HeartbeatController then controllerFetchAttempts = controllerFetchAttempts + 1; task.wait(0.1) end
	end
	if not HeartbeatController then warn("AutoHeartbeat: HeartbeatController tidak ditemukan.") return false end
	SoundController = Knit.GetController("SoundController")
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
	if HeartbeatGui then HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5) end
	if not HeartbeatGui then warn("AutoHeartbeat: Heartbeat GUI tidak ditemukan.") return false end
	if not (HeartbeatController and HeartbeatController.Trigger) then warn("AutoHeartbeat: HeartbeatController.Trigger tidak valid.") return false end
	return true
end
local function getCurrentHeartbeatGameStateAndStatus()
	if not HeartbeatController or not HeartbeatController.Trigger then return nil, false end
	local _, currentIsActive = pcall(debug.getupvalue, HeartbeatController.Trigger, 1)
	local _, currentGameState = pcall(debug.getupvalue, HeartbeatController.Trigger, 6)
	return currentGameState, currentIsActive
end
local function onHeartbeatRenderStep()
	if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then return end
	local currentLocalState, isGameActive = getCurrentHeartbeatGameStateAndStatus()
	if not (isGameActive and currentLocalState and currentLocalState.InitTick and currentLocalState.Beats and currentLocalState.Notes and #currentLocalState.Notes > 0) then return end
	local gameTime = tick() - currentLocalState.InitTick
	local bestNoteToHit, smallestTimeDifferenceToHitPoint = nil, math.huge
	for i, noteInfo in ipairs(currentLocalState.Notes) do
		local beatIndex = noteInfo[1]
		if currentLocalState.Beats[beatIndex] then
			local targetTime, timeUntilHit = currentLocalState.Beats[beatIndex], currentLocalState.Beats[beatIndex] - gameTime
			local diffFromIdealClick = timeUntilHit - HIT_OFFSET_SECONDS
			if math.abs(diffFromIdealClick) <= PERFECT_WINDOW_SECONDS and math.abs(diffFromIdealClick) < smallestTimeDifferenceToHitPoint then
				smallestTimeDifferenceToHitPoint = math.abs(diffFromIdealClick)
				bestNoteToHit = { noteData = noteInfo, arrayIndex = i, timeError = gameTime - targetTime }
			end
		end
	end
	if bestNoteToHit then
		local noteData, beatIndex, noteObject, arrayIndex, timeError = bestNoteToHit.noteData, bestNoteToHit.noteData[1], bestNoteToHit.noteData[2], bestNoteToHit.arrayIndex, bestNoteToHit.timeError
		if table.find(currentLocalState.Passed, beatIndex) then return end
		if math.abs(timeError) < PERFECT_WINDOW_SECONDS then
			if SoundController then pcall(SoundController.PlaySound, SoundController, "SingleHeartbeat") end
			HeartbeatGui.Playfield.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			HeartbeatGui.Playfield.BackgroundTransparency = 0
			currentLocalState.Stats.Perfect = currentLocalState.Stats.Perfect + 1
			Vetween.new(HeartbeatGui.Playfield, Vetween.newInfo(0.5, Vetween.Style.Linear), { ["BackgroundColor3"] = Color3.fromRGB(0, 0, 0), ["BackgroundTransparency"] = 1 }):Play()
			if noteObject and noteObject.Parent then noteObject:Destroy() end
			table.insert(currentLocalState.Passed, beatIndex)
			table.remove(currentLocalState.Notes, arrayIndex)
			if HeartbeatGui.UIScale then
				HeartbeatGui.UIScale.Scale = 1.1
				Vetween.new(HeartbeatGui.UIScale, Vetween.newInfo(2, Vetween.Style.Quint), { ["Scale"] = 1 }):Play()
			end
		end
	end
end
local function enableAutoHeartbeat(enable)
	heartbeatAutoClickerActive = enable
	if enable then
		if not (Knit and Vetween and HeartbeatGui and HeartbeatController) then
			if not initializeHeartbeatReferences() then
				Rayfield:Notify({Title = "Auto Heartbeat", Content = "Gagal menginisialisasi modul.", Duration = 5, Image = 4483362458})
				heartbeatAutoClickerActive = false; return false 
			end
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Diaktifkan!", Duration = 5, Image = 4483362458})
	else
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Auto Heartbeat Dinonaktifkan!", Duration = 5, Image = 4483362458})
	end
	return true 
end

--==================================================--
--[[      ESP SYSTEM (OPTIMIZED FROM ORIGINAL)    ]]--
--==================================================--
local espEnabled = false
local computerESPEnabled = false
local trackedModels = {} -- Melacak Model (Karakter atau Komputer) untuk efisiensi
local ESP_UPDATE_INTERVAL = 0.25

-- Fungsi untuk membersihkan elemen ESP dari sebuah model
local function clearESP(model)
	if not model or not trackedModels[model] then return end
	local espElements = trackedModels[model]
	if espElements.Tag and espElements.Tag.Parent then espElements.Tag:Destroy() end
	if espElements.Highlight and espElements.Highlight.Parent then espElements.Highlight:Destroy() end
	trackedModels[model] = nil
end

-- Fungsi yang dioptimalkan untuk membuat/memperbarui ESP pada sebuah MODEL
-- Fungsi ini sekarang hanya menerima Model, membuatnya lebih sederhana dan andal
local function createOrUpdateESP(model, labelText, fillColor, progressText)
	if not model or not model:IsA("Model") then return end

	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local espInfo = trackedModels[model] or {}
	local displayText = labelText
	if progressText then displayText = displayText .. "\n" .. progressText end
	
	if not espInfo.Tag or not espInfo.Tag.Parent then
		local gui = Instance.new("BillboardGui", model); gui.Name = "ESPTag"; gui.Adornee = root; gui.Size = UDim2.new(0, 150, 0, 60); gui.StudsOffset = Vector3.new(0, 5, 0); gui.AlwaysOnTop = true; gui.LightInfluence = 0; gui.ResetOnSpawn = false
		local text = Instance.new("TextLabel", gui); text.Name = "ESPText"; text.Size = UDim2.new(1, 0, 1, 0); text.BackgroundTransparency = 1; text.TextColor3 = fillColor; text.Font = Enum.Font.GothamSemibold; text.TextSize = 14; text.TextWrapped = true; text.RichText = true
		text.TextTransparency = 0.2; text.TextStrokeTransparency = 0.5
		espInfo.Tag = gui
	end
	
	espInfo.Tag.ESPText.Text = displayText; espInfo.Tag.ESPText.TextColor3 = fillColor; espInfo.Tag.Adornee = root
	
	if not espInfo.Highlight or not espInfo.Highlight.Parent then
		local hl = Instance.new("Highlight", model); hl.Name = "ESPHighlight"; hl.Adornee = model; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		espInfo.Highlight = hl
	end
	
	espInfo.Highlight.FillColor = fillColor; espInfo.Highlight.OutlineColor = Color3.new(fillColor.r * 0.7, fillColor.g * 0.7, fillColor.b * 0.7)
	espInfo.Highlight.FillTransparency = 0.8; espInfo.Highlight.OutlineTransparency = 0.6
	
	trackedModels[model] = espInfo
end

-- =================================================================== --
-- == FUNGSI SCAN UTAMA - MENGGUNAKAN LOGIKA DARI SCRIPT AWAL ANDA == --
-- =================================================================== --
local function scanAllPlayers()
    if not espEnabled then return end

    -- Loop melalui semua pemain, sama seperti script awal Anda
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local role = player:GetAttribute("Role")

            -- Menentukan warna berdasarkan role, sama seperti script awal
            local color = Color3.fromRGB(220, 220, 220) -- Warna default
            if role == "Monster" then
                color = Color3.fromRGB(255, 50, 50)
            elseif role == "Survivor" then
                color = Color3.fromRGB(255, 236, 161)
            end

            -- Terapkan ESP ke MODEL KARAKTER dengan NAMA PLAYER dan WARNA yang sesuai
            -- Ini adalah cara kerja script asli Anda, sekarang hanya dioptimalkan.
            createOrUpdateESP(char, player.Name, color)
        end
    end
end

-- Fungsi scan untuk komputer tidak diubah
local function scanComputersESP()
	if not computerESPEnabled then return end
	local tasksFolder = Workspace:FindFirstChild("Tasks", true)
	if not tasksFolder then return end
	for _, item in ipairs(tasksFolder:GetChildren()) do 
		if item:IsA("Model") and item.Name:lower() == "computer" then
			local progress = item:GetAttribute("Progress"); local completed = item:GetAttribute("Completed"); local progressText, espColor
			if completed then progressText = "Completed"; espColor = Color3.fromRGB(100, 150, 255) elseif type(progress) == "number" then progressText = string.format("Progress: %.1f", progress); espColor = Color3.fromRGB(50, 255, 50) else progressText = "Progress: N/A"; espColor = Color3.fromRGB(50, 255, 50) end
			createOrUpdateESP(item, "COMPUTER", espColor, progressText)
		end
	end
end

-- Loop utama ESP
task.spawn(function()
	while true do
		-- Hapus ESP dari model yang sudah tidak ada
		for model in pairs(trackedModels) do
			if not model or not model.Parent then
				clearESP(model)
			end
		end

		if espEnabled then
			pcall(scanAllPlayers)
		end
		
		if computerESPEnabled then
			pcall(scanComputersESP)
		end
		
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)

-- Membersihkan ESP saat player keluar
Players.PlayerRemoving:Connect(function(player)
    if player.Character and trackedModels[player.Character] then
        clearESP(player.Character)
    end
end)

--==================================================--
--[[            MOVEMENT (OPTIMIZED)              ]]--
--==================================================--
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

local function setNoclip(character, enabled)
	if not character then return end
	pcall(function()
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = not enabled end
		end
	end)
end

--==================================================--
--[[                 UI TOGGLES                   ]]--
--==================================================--
local MainTab = Window:CreateTab("Main", 4483362458)
local MovementTab = Window:CreateTab("Movement", 4483362458)

MainTab:CreateToggle({ Name = "Auto Heartbeat", CurrentValue = heartbeatAutoClickerActive, Flag = "AutoHeartbeatEnabled", Callback = function(Value) if not enableAutoHeartbeat(Value) and Value then heartbeatAutoClickerActive = false; Rayfield:SetFlag("AutoHeartbeatEnabled", false) end end })
MainTab:CreateToggle({ Name = "ESP Player", CurrentValue = espEnabled, Flag = "ESPEnabled", Callback = function(Value) espEnabled = Value; if not Value then for object in pairs(trackedObjects) do if object:IsA("Player") then clearESP(object) end end end end })
MainTab:CreateToggle({ Name = "ESP Computer", CurrentValue = computerESPEnabled, Flag = "ComputerESPEnabled", Callback = function(Value) computerESPEnabled = Value; if not Value then for object in pairs(trackedObjects) do if object:IsA("Model") then clearESP(object) end end end end })
MovementTab:CreateSlider({ Name = "Speed Hack (WalkSpeed)", Range = {16, 100}, Increment = 1, Suffix = "Speed", CurrentValue = 16, Flag = "SpeedHackSlider", Callback = function(Value) targetSpeed = Value; local char = LocalPlayer.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = Value end end })

MovementTab:CreateToggle({
	Name = "Persistent Speed (Anti-Reset)",
	CurrentValue = false,
	Flag = "PersistentSpeedToggle",
	Callback = function(Value)
		persistentSpeedEnabled = Value
		local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if speedConnection then speedConnection:Disconnect(); speedConnection = nil end
		if Value and hum then
			hum.WalkSpeed = targetSpeed
			speedConnection = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
				if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
			end)
		end
	end,
})

MovementTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "NoclipToggle",
	Callback = function(Value)
		noclipActive = Value
		setNoclip(LocalPlayer.Character, noclipActive)
	end,
})
-- Handle Noclip saat respawn
LocalPlayer.CharacterAdded:Connect(function(character)
	if noclipActive then
		task.wait(0.1) -- Beri sedikit jeda agar semua part termuat
		setNoclip(character, true)
	end
end)

Rayfield:Notify({ Title = "ElHub Loaded!", Content = "Selamat datang di ElHub. (Optimized & Fixed)", Duration = 7, Image = 4483362458 })
