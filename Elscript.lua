-- ElHub - Five Night: Hunted (Updated with Opacity Slider)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Welcome in ElHub!",
	LoadingTitle = "Patience is a key..",
	LoadingSubtitle = "Elproject",
	ConfigurationSaving = { Enabled = true, FileName = "FIVE NIGHT: HUNTED" },
	Discord = { Enabled = false },
	KeySystem = false
})

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Variables - Heartbeat
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14
local Knit, Vetween, HeartbeatController, SoundController, HeartbeatGui
local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

-- Variables - ESP
local espEnabled = false
local computerESPEnabled = false
local showESPText = false 
local trackedModels = {} 
local ESP_UPDATE_INTERVAL = 0.25
local espFillTransparency = 0.5 -- Default Opacity (0 = Solid, 1 = Invisible)

-- Variables - Movement
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

--------------------------------------------------------------------------------
-- AUTO HEARTBEAT SYSTEM
--------------------------------------------------------------------------------
local function initializeHeartbeatReferences()
	if Knit and HeartbeatController and SoundController and HeartbeatGui and Vetween then return true end

	local successKnit, knitModule = pcall(require, ReplicatedStorage.Packages.Knit)
	if not successKnit then return false end
	Knit = knitModule

	local successVetween, vetweenModule = pcall(require, ReplicatedStorage.Packages.Vetween)
	if not successVetween then return false end
	Vetween = vetweenModule

	local attempts = 0
	while (attempts < 50) do
		HeartbeatController = Knit.GetController("HeartbeatController")
		if HeartbeatController then break end
		attempts = attempts + 1
		task.wait(0.1)
	end

	if not HeartbeatController then return false end
	SoundController = Knit.GetController("SoundController")
	
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	HeartbeatGui = playerGui:WaitForChild("Heartbeat", 5)
	if HeartbeatGui then HeartbeatGui = HeartbeatGui:WaitForChild("Heartbeat", 5) end
	
	return (HeartbeatGui and HeartbeatController and HeartbeatController.Trigger)
end

local function getCurrentHeartbeatGameStateAndStatus()
	if not HeartbeatController or not HeartbeatController.Trigger then return nil, false end
	local _, active = pcall(debug.getupvalue, HeartbeatController.Trigger, 1)
	local _, state = pcall(debug.getupvalue, HeartbeatController.Trigger, 6)
	return state, active
end

local function onHeartbeatRenderStep()
	if not (heartbeatAutoClickerActive and Knit and Vetween and HeartbeatGui and HeartbeatController) then return end
	
	local state, active = getCurrentHeartbeatGameStateAndStatus()
	if not active or not state or not state.Notes or #state.Notes == 0 then return end

	local gameTime = tick() - state.InitTick
	local bestHit = nil
	local minDiff = math.huge

	for i, note in ipairs(state.Notes) do
		local beatIdx = note[1]
		if state.Beats[beatIdx] then
			local diff = (state.Beats[beatIdx] - gameTime) - HIT_OFFSET_SECONDS
			if math.abs(diff) <= PERFECT_WINDOW_SECONDS and math.abs(diff) < minDiff then
				minDiff = math.abs(diff)
				bestHit = { data = note, idx = i, error = gameTime - state.Beats[beatIdx] }
			end
		end
	end

	if bestHit and not table.find(state.Passed, bestHit.data[1]) then
		if math.abs(bestHit.error) < PERFECT_WINDOW_SECONDS then
			if SoundController then pcall(SoundController.PlaySound, SoundController, "SingleHeartbeat") end

			HeartbeatGui.Playfield.BackgroundTransparency = 0
			state.Stats.Perfect = state.Stats.Perfect + 1
			Vetween.new(HeartbeatGui.Playfield, Vetween.newInfo(0.5, Vetween.Style.Linear), { ["BackgroundTransparency"] = 1 }):Play()
			
			if bestHit.data[2] and bestHit.data[2].Parent then bestHit.data[2]:Destroy() end

			table.insert(state.Passed, bestHit.data[1])
			table.remove(state.Notes, bestHit.idx)

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
		if not initializeHeartbeatReferences() then
			Rayfield:Notify({Title = "Error", Content = "Failed to init modules.", Duration = 3})
			heartbeatAutoClickerActive = false
			return
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Enabled", Duration = 3})
	else
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
		Rayfield:Notify({Title = "Auto Heartbeat", Content = "Disabled", Duration = 3})
	end
end

--------------------------------------------------------------------------------
-- ESP SYSTEM
--------------------------------------------------------------------------------
local function clearESP(model)
	if not model or not trackedModels[model] then return end
	local esp = trackedModels[model]
	if esp.Tag then esp.Tag:Destroy() end
	if esp.Highlight then esp.Highlight:Destroy() end
	trackedModels[model] = nil
end

local function createOrUpdateESP(model, label, color, subText)
	if not model or not model:IsA("Model") then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local esp = trackedModels[model] or {}
	local fullText = subText and (label .. "\n" .. subText) or label
	
	-- Create/Update Tag
	if not esp.Tag or not esp.Tag.Parent then
		local gui = Instance.new("BillboardGui", model)
		gui.Name, gui.Adornee, gui.Size, gui.AlwaysOnTop = "ESPTag", root, UDim2.new(0, 150, 0, 60), true
		gui.StudsOffset = Vector3.new(0, 5, 0)
		
		local txt = Instance.new("TextLabel", gui)
		txt.Name, txt.Size, txt.BackgroundTransparency = "ESPText", UDim2.new(1,0,1,0), 1
		txt.Font, txt.TextSize, txt.TextStrokeTransparency = Enum.Font.GothamSemibold, 14, 0.5
		
		esp.Tag = gui
	end
	
	esp.Tag.ESPText.Text = fullText
	esp.Tag.ESPText.TextColor3 = color
	esp.Tag.Enabled = showESPText
	
	-- Create/Update Highlight
	if not esp.Highlight or not esp.Highlight.Parent then
		local hl = Instance.new("Highlight", model)
		hl.Name, hl.Adornee, hl.DepthMode = "ESPHighlight", model, Enum.HighlightDepthMode.AlwaysOnTop
		esp.Highlight = hl
	end
	
	esp.Highlight.FillColor = color
	esp.Highlight.OutlineColor = Color3.new(color.r*0.7, color.g*0.7, color.b*0.7)
	-- Gunakan variabel transparansi global
	esp.Highlight.FillTransparency = espFillTransparency
	esp.Highlight.OutlineTransparency = 0.5 
	
	trackedModels[model] = esp
end

local function scanEntities()
	if espEnabled then
		for _, v in ipairs(Players:GetPlayers()) do
			if v ~= LocalPlayer and v.Character then
				local role = v:GetAttribute("Role")
				local col = (role == "Monster" and Color3.fromRGB(255, 50, 50)) or (role == "Survivor" and Color3.fromRGB(255, 236, 161)) or Color3.fromRGB(220, 220, 220)
				createOrUpdateESP(v.Character, v.Name, col)
			end
		end
	end

	if computerESPEnabled then
		local folder = Workspace:FindFirstChild("Tasks", true)
		if folder then
			for _, v in ipairs(folder:GetChildren()) do 
				if v:IsA("Model") and v.Name:lower() == "computer" then
					local prog, comp = v:GetAttribute("Progress"), v:GetAttribute("Completed")
					local txt, col = "Progress: N/A", Color3.fromRGB(50, 255, 50)
					if comp then txt, col = "Completed", Color3.fromRGB(100, 150, 255)
					elseif type(prog) == "number" then txt = string.format("%.1f%%", prog) end
					createOrUpdateESP(v, "COMPUTER", col, txt)
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		for m in pairs(trackedModels) do if not m or not m.Parent then clearESP(m) end end
		pcall(scanEntities)
		task.wait(ESP_UPDATE_INTERVAL)
	end
end)

Players.PlayerRemoving:Connect(function(p) if p.Character then clearESP(p.Character) end end)

--------------------------------------------------------------------------------
-- UI & MOVEMENT
--------------------------------------------------------------------------------
local MainTab = Window:CreateTab("Main", 4483362458)
local MoveTab = Window:CreateTab("Movement", 4483362458)

MainTab:CreateToggle({
	Name = "Auto Heartbeat", CurrentValue = false, Flag = "AutoHeartbeat",
	Callback = function(v) if not enableAutoHeartbeat(v) and v then Rayfield:SetFlag("AutoHeartbeat", false) end end
})

MainTab:CreateSection("ESP Options")
MainTab:CreateToggle({
	Name = "ESP Player", CurrentValue = false, Flag = "ESPPlayer",
	Callback = function(v) espEnabled = v; if not v then for m in pairs(trackedModels) do if m:FindFirstChild("Humanoid") then clearESP(m) end end end end
})
MainTab:CreateToggle({
	Name = "ESP Computer", CurrentValue = false, Flag = "ESPComp",
	Callback = function(v) computerESPEnabled = v; if not v then for m in pairs(trackedModels) do if m.Name:lower() == "computer" then clearESP(m) end end end end
})
MainTab:CreateToggle({
	Name = "Show ESP Text", CurrentValue = false, Flag = "ESPText",
	Callback = function(v) showESPText = v; for _, e in pairs(trackedModels) do if e.Tag then e.Tag.Enabled = v end end end
})

-- SLIDER TRANSPARENCY BARU
MainTab:CreateSlider({
	Name = "ESP Transparency (Fill)",
	Range = {0, 1},
	Increment = 0.1,
	Suffix = "Alpha",
	CurrentValue = 0.5,
	Flag = "ESPTransparency",
	Callback = function(Value)
		espFillTransparency = Value
		-- Update real-time ke semua ESP yang aktif
		for _, esp in pairs(trackedModels) do
			if esp.Highlight then
				esp.Highlight.FillTransparency = Value
			end
		end
	end,
})

MoveTab:CreateSlider({
	Name = "WalkSpeed", Range = {16, 100}, Increment = 1, CurrentValue = 16, Flag = "WS",
	Callback = function(v) targetSpeed = v; if LocalPlayer.Character then LocalPlayer.Character.Humanoid.WalkSpeed = v end end
})

MoveTab:CreateToggle({
	Name = "Loop Speed", CurrentValue = false,
	Callback = function(v)
		persistentSpeedEnabled = v
		if speedConnection then speedConnection:Disconnect() speedConnection = nil end
		if v then
			local h = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")
			if h then h.WalkSpeed = targetSpeed; speedConnection = h:GetPropertyChangedSignal("WalkSpeed"):Connect(function() h.WalkSpeed = targetSpeed end) end
		end
	end
})

MoveTab:CreateToggle({
	Name = "Noclip", CurrentValue = false,
	Callback = function(v)
		noclipActive = v
		if LocalPlayer.Character then for _,p in ipairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = not v end end end
	end
})

LocalPlayer.CharacterAdded:Connect(function(c)
	if noclipActive then task.wait(0.1) for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
end)

Rayfield:Notify({Title = "ElHub", Content = "Loaded.", Duration = 3})
