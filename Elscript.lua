-- ElHub - Five Night: Hunted (V8: Ultimate Monster & Advanced ESP)
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name = "Welcome in ElHub!",
	LoadingTitle = "Patience is a key..",
	LoadingSubtitle = "Elproject",
	ConfigurationSaving = { Enabled = true, FileName = "FIVE NIGHT: HUNTED_V8" },
	Discord = { Enabled = false },
	KeySystem = false
})

-- ==============================================================================
-- 1. SERVICES & VARIABLES
-- ==============================================================================
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Heartbeat Variables
local HIT_OFFSET_SECONDS = 0.01
local PERFECT_WINDOW_SECONDS = 0.14
local Knit, Vetween, HeartbeatController, SoundController, HeartbeatGui
local heartbeatAutoClickerActive = false
local heartbeatConnection = nil

-- ESP Variables
local espNameEnabled = false      -- [DEFAULT OFF]
local espDistanceEnabled = true   -- [DEFAULT ON]
local computerESPEnabled = true   -- [DEFAULT ON]
local showFullESPText = true      -- [DEFAULT ON]
local trackedModels = {} 
local ESP_UPDATE_INTERVAL = 0.25
local espFillTransparency = 0.5 
local ESP_FONT_SIZE = 10          -- [REQUEST: Font Kecil]

-- Monster / Advanced Variables
local monsterLogicConnection = nil
local noCooldownEnabled = false
local killAuraEnabled = false
local hitboxExpanderEnabled = false
local desyncEnabled = false
local killAuraRange = 15
local hitboxSize = 15

-- Desync Internals
local ghostPart = nil
local originalCFrame = nil

-- Movement Variables
local targetSpeed = 16
local persistentSpeedEnabled = false
local speedConnection = nil
local noclipActive = false

-- ==============================================================================
-- 2. HEARTBEAT MINIGAME SYSTEM
-- ==============================================================================
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
			Rayfield:Notify({Title = "Error", Content = "Modules Failed.", Duration = 3})
			heartbeatAutoClickerActive = false
			return
		end
		if heartbeatConnection then heartbeatConnection:Disconnect() end 
		heartbeatConnection = RunService:BindToRenderStep("HeartbeatAutoClicker", Enum.RenderPriority.Character.Value + 1, onHeartbeatRenderStep)
	else
		if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	end
end

-- ==============================================================================
-- 3. ESP SYSTEM
-- ==============================================================================
local function clearESP(model)
	if not model or not trackedModels[model] then return end
	local esp = trackedModels[model]
	if esp.Tag then esp.Tag:Destroy() end
	if esp.Highlight then esp.Highlight:Destroy() end
	trackedModels[model] = nil
end

local function createOrUpdateESP(model, textContent, color)
	if not model or not model:IsA("Model") then return end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not root then return end

	local esp = trackedModels[model] or {}
	
	-- Create/Update Tag
	if not esp.Tag or not esp.Tag.Parent then
		local gui = Instance.new("BillboardGui", model)
		gui.Name, gui.Adornee, gui.Size, gui.AlwaysOnTop = "ESPTag", root, UDim2.new(0, 150, 0, 60), true
		gui.StudsOffset = Vector3.new(0, 4, 0) -- Sedikit diturunkan
		
		local txt = Instance.new("TextLabel", gui)
		txt.Name, txt.Size, txt.BackgroundTransparency = "ESPText", UDim2.new(1,0,1,0), 1
		txt.Font, txt.TextSize, txt.TextStrokeTransparency = Enum.Font.GothamSemibold, ESP_FONT_SIZE, 0.5
		
		esp.Tag = gui
	end
	
	esp.Tag.ESPText.Text = textContent
	esp.Tag.ESPText.TextColor3 = color
	esp.Tag.Enabled = (textContent and textContent ~= "")
	
	-- Create/Update Highlight
	if not esp.Highlight or not esp.Highlight.Parent then
		local hl = Instance.new("Highlight", model)
		hl.Name, hl.Adornee, hl.DepthMode = "ESPHighlight", model, Enum.HighlightDepthMode.AlwaysOnTop
		esp.Highlight = hl
	end
	
	esp.Highlight.FillColor = color
	esp.Highlight.OutlineColor = Color3.new(color.r*0.7, color.g*0.7, color.b*0.7)
	esp.Highlight.FillTransparency = espFillTransparency
	esp.Highlight.OutlineTransparency = 0.5 
	
	trackedModels[model] = esp
end

local function scanEntities()
	local myChar = LocalPlayer.Character
	local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar.PrimaryPart)

	-- SCAN PLAYER
	if espNameEnabled or espDistanceEnabled then
		for _, v in ipairs(Players:GetPlayers()) do
			if v ~= LocalPlayer and v.Character then
				local role = v:GetAttribute("Role")
				local col = (role == "Monster" and Color3.fromRGB(255, 50, 50)) or (role == "Survivor" and Color3.fromRGB(255, 236, 161)) or Color3.fromRGB(220, 220, 220)
				local txt = ""
				if espNameEnabled then txt = v.Name end
				if espDistanceEnabled and myRoot and v.Character:FindFirstChild("HumanoidRootPart") then
					local dist = (myRoot.Position - v.Character.HumanoidRootPart.Position).Magnitude
					if txt ~= "" then txt = txt .. "\n" end
					txt = txt .. string.format("[%dm]", dist)
				end
				createOrUpdateESP(v.Character, txt, col)
			end
		end
	end

	-- SCAN COMPUTER
	if computerESPEnabled then
		local folder = Workspace:FindFirstChild("Tasks", true)
		if folder then
			for _, v in ipairs(folder:GetChildren()) do 
				if v:IsA("Model") and v.Name:lower() == "computer" then
					local prog, comp = v:GetAttribute("Progress"), v:GetAttribute("Completed")
					
					-- Gradient Ease Out (Putih -> Hijau)
					local alpha = 0
					local info = "N/A"
					if comp then info = "Done"; alpha = 1
					elseif type(prog) == "number" then info = string.format("%.0f%%", prog); alpha = 1 - (1 - math.clamp(prog/100,0,1))^2 end
					
					local col = Color3.new(1,1,1):Lerp(Color3.fromRGB(50,255,50), alpha)
					local txt = ""
					if espNameEnabled then txt = "PC" end
					if espDistanceEnabled and myRoot and v.PrimaryPart then
						local dist = (myRoot.Position - v.PrimaryPart.Position).Magnitude
						if txt ~= "" then txt = txt .. "\n" end
						txt = txt .. string.format("[%dm]", dist)
					end
					if showFullESPText then
						if txt ~= "" then txt = txt .. "\n" end
						txt = txt .. info
					end
					
					-- Tetap highlight walau teks kosong
					if txt == "" and not showFullESPText then txt = " " end
					createOrUpdateESP(v, txt, col)
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

-- ==============================================================================
-- 4. MONSTER & ADVANCED SYSTEM (LOGIC TERPISAH)
-- ==============================================================================

-- Helper: Update Visual Ghost
local function updateGhostVisual(cframe)
    if not ghostPart then
        ghostPart = Instance.new("Part")
        ghostPart.Name = "ServerGhost"
        ghostPart.Size = Vector3.new(4, 6, 4)
        ghostPart.Anchored = true
        ghostPart.CanCollide = false
        ghostPart.Transparency = 0.6
        ghostPart.Color = Color3.new(0, 0, 0)
        ghostPart.Material = Enum.Material.ForceField
        ghostPart.Parent = workspace
    end
    ghostPart.CFrame = cframe
end

local function removeGhost()
    if ghostPart then ghostPart:Destroy(); ghostPart = nil end
end

-- Helper: Reset Hitboxes (Saat fitur dimatikan)
local function resetHitboxes()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local rp = p.Character.HumanoidRootPart
            rp.Size = Vector3.new(2, 2, 1) -- Ukuran standar
            rp.Transparency = 1
            rp.Color = Color3.new(1,1,1) -- Reset warna standar (biasanya tidak terlihat)
        end
    end
end

-- MAIN MONSTER LOGIC LOOP
local function runMonsterLogic()
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local myRoot = char.HumanoidRootPart
	local myHuman = char:FindFirstChild("Humanoid")
	if not myHuman or myHuman.Health <= 0 then removeGhost(); return end

	-- A. DESYNC / GHOST MODE
	if desyncEnabled then
		if not originalCFrame then
			originalCFrame = myRoot.CFrame
			updateGhostVisual(originalCFrame)
			-- Freeze Velocity
			myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			myRoot.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		end
		-- Server Lag Trick
		pcall(function() sethiddenproperty(myRoot, "NetworkIsSleeping", true) end)
	else
		if originalCFrame then
			originalCFrame = nil
			removeGhost()
			myRoot.AssemblyLinearVelocity = Vector3.new(0,0,0)
		end
	end

	-- B. HITBOX EXPANDER
	if hitboxExpanderEnabled then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LocalPlayer and p.Character then
				local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
				local tHuman = p.Character:FindFirstChild("Humanoid")
				if tRoot and tHuman and tHuman.Health > 0 then
					tRoot.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
					tRoot.Transparency = 0.7
					tRoot.CanCollide = false
					tRoot.Color = Color3.fromRGB(255, 0, 0) -- Merah biar jelas
				end
			end
		end
	end

	-- C. KILL AURA & NO COOLDOWN
	if killAuraEnabled or noCooldownEnabled then
		local tool = char:FindFirstChildOfClass("Tool")
		local closestTarget = nil
		
		-- Logic Jarak (Dari Ghost jika desync nyala, dari Badan jika mati)
		local originPos = (desyncEnabled and originalCFrame) and originalCFrame.Position or myRoot.Position
		
		if killAuraEnabled then
			local shortestDist = killAuraRange
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer and p.Character then
					local tRoot = p.Character:FindFirstChild("HumanoidRootPart")
					local tHuman = p.Character:FindFirstChild("Humanoid")
					if tRoot and tHuman and tHuman.Health > 0 then
						local dist = (originPos - tRoot.Position).Magnitude
						if dist < shortestDist then
							shortestDist = dist
							closestTarget = p.Character
						end
					end
				end
			end
		end

		-- Auto Equip
		if closestTarget and not tool then
			local backpack = LocalPlayer:FindFirstChild("Backpack")
			if backpack then
				local bestTool = backpack:FindFirstChildOfClass("Tool")
				if bestTool then bestTool.Parent = char; tool = bestTool end
			end
		end

		-- Action
		if tool then
			if noCooldownEnabled then tool.Enabled = true end
			if closestTarget then tool:Activate() end
		end
	end
end

-- Toggle Handler
local function toggleMonsterLoop()
	local shouldRun = noCooldownEnabled or killAuraEnabled or hitboxExpanderEnabled or desyncEnabled
	if shouldRun then
		if not monsterLogicConnection then
			monsterLogicConnection = RunService.Stepped:Connect(runMonsterLogic)
		end
	else
		if monsterLogicConnection then
			monsterLogicConnection:Disconnect()
			monsterLogicConnection = nil
			removeGhost()
			resetHitboxes() -- Bersihkan hitbox saat mati
		end
	end
end

-- ==============================================================================
-- 5. UTILITY & MOVEMENT
-- ==============================================================================
local function applyInstantInteract()
    for _, v in ipairs(workspace:GetDescendants()) do if v:IsA("ProximityPrompt") then v.HoldDuration = 0 end end
end

local instantInteractConnection = nil

-- ==============================================================================
-- 6. UI CONSTRUCTION (RAYFIELD)
-- ==============================================================================
local MainTab = Window:CreateTab("Main", 4483362458)
local MonsterTab = Window:CreateTab("Monster", 4483362458)
local MoveTab = Window:CreateTab("Movement", 4483362458)
local UtilityTab = Window:CreateTab("Utility", 4483362458)

-- [MAIN TAB]
MainTab:CreateToggle({
	Name = "Auto Heartbeat", CurrentValue = false, Flag = "AutoHeartbeat",
	Callback = function(v) enableAutoHeartbeat(v); if not v then Rayfield:SetFlag("AutoHeartbeat", false) end end
})

MainTab:CreateSection("ESP Options")
MainTab:CreateToggle({
	Name = "ESP Player Name", CurrentValue = espNameEnabled, Flag = "ESPName",
	Callback = function(v) espNameEnabled = v end
})
MainTab:CreateToggle({
	Name = "Show Distance", CurrentValue = espDistanceEnabled, Flag = "ESPDistance",
	Callback = function(v) espDistanceEnabled = v end
})
MainTab:CreateToggle({
	Name = "ESP Computer", CurrentValue = computerESPEnabled, Flag = "ESPComp",
	Callback = function(v) computerESPEnabled = v; if not v then for m in pairs(trackedModels) do if m.Name:lower() == "computer" then clearESP(m) end end end end
})
MainTab:CreateToggle({
	Name = "Show Progress Info", CurrentValue = showFullESPText, Flag = "ESPText",
	Callback = function(v) showFullESPText = v end
})
MainTab:CreateSlider({
	Name = "ESP Transparency (Fill)", Range = {0, 1}, Increment = 0.1, Suffix = "Alpha", CurrentValue = 0.5, Flag = "ESPTransparency",
	Callback = function(Value) espFillTransparency = Value; for _, esp in pairs(trackedModels) do if esp.Highlight then esp.Highlight.FillTransparency = Value end end end,
})

-- [MONSTER TAB - ADVANCED]
MonsterTab:CreateSection("Combat")
MonsterTab:CreateToggle({
	Name = "No Attack Cooldown", CurrentValue = false, Flag = "NoCooldown",
	Callback = function(v) noCooldownEnabled = v; toggleMonsterLoop() end
})
MonsterTab:CreateToggle({
	Name = "Kill Aura (15m)", CurrentValue = false, Flag = "KillAura",
	Callback = function(v) killAuraEnabled = v; toggleMonsterLoop() end
})
MonsterTab:CreateSection("Exploits")
MonsterTab:CreateToggle({
	Name = "Hitbox Expander", CurrentValue = false, Flag = "Hitbox",
	Callback = function(v) hitboxExpanderEnabled = v; toggleMonsterLoop() end
})
MonsterTab:CreateSlider({
	Name = "Hitbox Size", Range = {5, 30}, Increment = 1, CurrentValue = 15, Flag = "HitboxSize",
	Callback = function(v) hitboxSize = v end,
})
MonsterTab:CreateToggle({
	Name = "Ghost Mode [Key: V]", CurrentValue = false, Flag = "GhostMode",
	Callback = function(v) desyncEnabled = v; toggleMonsterLoop() end
})
-- Keybind V Listener
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.V then
		desyncEnabled = not desyncEnabled
		Rayfield:SetFlag("GhostMode", desyncEnabled) -- Update Toggle UI
		toggleMonsterLoop()
	end
end)


-- [MOVEMENT TAB]
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
LocalPlayer.CharacterAdded:Connect(function(c) if noclipActive then task.wait(0.1) for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end end)


-- [UTILITY TAB]
UtilityTab:CreateToggle({
    Name = "Instant Interact (Insta-E)", CurrentValue = false, Flag = "InstaE",
    Callback = function(Value)
        if Value then
            applyInstantInteract()
            instantInteractConnection = workspace.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("ProximityPrompt") then task.wait(0.1) descendant.HoldDuration = 0 end
            end)
        else
            if instantInteractConnection then instantInteractConnection:Disconnect() instantInteractConnection = nil end
        end
    end
})

Rayfield:Notify({Title = "ElHub V8", Content = "Loaded. Monster Tab + Small Fonts Ready.", Duration = 3})
