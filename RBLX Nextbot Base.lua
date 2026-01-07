-- Var --

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local PS = game:GetService("PhysicsService")

local player = game.Players.LocalPlayer
local character = nil
local rootPart = nil
local camera = workspace.CurrentCamera
local humanoid = nil
local torso = nil

local loaded = false
local followPart: BasePart = nil

local animations = {
	idle = {id = "180435571", speed = 0.85}, --135619218428335 --0.65
	walk = {id = "180426354", speed = 1}, --100793209841923 --1.8
	run = {id = "180426354", speed = 2.4}, --119263125069920 --2
	fall = {id = "180426354", speed = 2.8}, --119263125069920 --2.2
	attack1 = {id = "128853357", speed = 2}, --129006188994017
	attack2 = {id = "128777973", speed = 2}, --129687603146615
}

local walkspeed = 300
local runspeed = 650
local acceleration = 500
local deceleration = 500
local jumpheight = 50
local stepheight = 20
local attributeScale = 16
local animFadeTime = 0.2

local currentAnimation = nil

local currentVelocity = Vector3.new(0, 0, 0)

local attackCD = 0

local cameraMaxZoom = player.CameraMaxZoomDistance
local cameraMinZoom = player.CameraMinZoomDistance
local cameraMode = player.CameraMode

local disableScripts = {
	"GrabbingScript",
	"BobbingAndCrouch",
	"Animate"
}

local cameraOffset = Vector3.new(0, 3, 0)

local skin = 0.05

local teleportDelayCurrent = 0
local teleportDelay = 0.4

-- Func --

function GetInputs()
	local function GetGrounded()
		if not followPart then return false end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		params.RespectCanCollide = true
		params.CollisionGroup = torso.CollisionGroup
		local result = workspace:Blockcast(followPart.CFrame, followPart.Size / 2, Vector3.new(0, -2.5, 0), params)
		return result
	end
	local function GetMoveDir()
		local camCF = camera.CFrame
		local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
		local right = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z)
		if forward.Magnitude > 0 then forward = forward.Unit end
		if right.Magnitude > 0 then right = right.Unit end
		local dir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir += forward end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= forward end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= right end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir += right end
		return dir.Magnitude > 0 and dir.Unit or Vector3.zero
	end

	if UIS:GetFocusedTextBox() then return nil end
	return {
		jumping = UIS:IsKeyDown(Enum.KeyCode.Space),
		sprinting = UIS:IsKeyDown(Enum.KeyCode.LeftShift),
		moveDir = GetMoveDir(),
		grounded = GetGrounded(),
		attacking = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
		teleporting = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton3),
	}
end

function CalculateJumpVelocity()
	return math.sqrt(workspace.Gravity * jumpheight) * attributeScale
end

function CreateFollowPart()
	if loaded then return end

	local newPart = Instance.new("Part")
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.CanTouch = false
	newPart.CanQuery = false
	newPart.Transparency = 0.25
	newPart.Size = Vector3.new(2, 5, 2)
	newPart.Material = Enum.Material.ForceField
	newPart.Color = Color3.new(1, 0, 0)
	newPart.Parent = workspace
	newPart.Name = "Nextbot Follow"

	newPart.Position = Vector3.new(0, -0.5, 0) + rootPart.Position
	
	local cameraPart = Instance.new("Part")
	cameraPart.Anchored = true
	cameraPart.CanCollide = false
	cameraPart.CanTouch = false
	cameraPart.CanQuery = false
	cameraPart.Transparency = 0.25
	cameraPart.Size = Vector3.new(1, 1, 1)
	cameraPart.Material = Enum.Material.ForceField
	cameraPart.Color = Color3.new(0, 0, 1)
	cameraPart.Parent = newPart
	cameraPart.Name = "Nextbot Camera"

	camera.CameraSubject = cameraPart

	followPart = newPart
end

function LoadAnimations(char)
	local animator = char:FindFirstChildWhichIsA("Animator", true)
	for name, info in pairs(animations) do
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://" .. info.id
		anim.Parent = animator
		anim.Name = name
		anim = animator:LoadAnimation(anim)
		animations[name].anim = anim
	end
end

function DisableScripts(char)
	for _, i in disableScripts do
		local scr = char:FindFirstChild(i)
		if scr then
			scr.Enabled = false
		end
	end
end

function Load(char)
	char = char or player.Character
	if loaded or not char then return end
	character = char
	rootPart = char:WaitForChild("HumanoidRootPart")
	humanoid = char:WaitForChild("Humanoid")
	humanoid.Died:Connect(Unload)
	torso = char:WaitForChild("Torso")

	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = 15
	player.CameraMinZoomDistance = 15

	char.PrimaryPart = rootPart

	CreateFollowPart()
	LoadAnimations(char)

	loaded = true
end

function Think(delta)
	if not loaded or not followPart or not rootPart or not camera or not character or not torso then return end
	attackCD -= delta
	teleportDelayCurrent -= delta

	DisableScripts(character)

	local inputs = GetInputs()
	if not inputs then return end
	
	local function GetSpeed()
		local speed = inputs.sprinting and runspeed or walkspeed
		return speed * 1.5
	end

	local function UpdateAnimation(forceAnim)
		local function GetIsInAnims(anim)
			for _, i in animations do
				if i.anim == anim then
					return true
				end
			end
		end
		local animator = character:FindFirstChildWhichIsA("Animator", true)
		for _, anim in animator:GetPlayingAnimationTracks() do
			if not GetIsInAnims(anim) then
				anim:Stop()
			end
		end
		
		local lastAnimation = currentAnimation
		if forceAnim then
			currentAnimation = animations[forceAnim]
		elseif not inputs.grounded then
			currentAnimation = animations["fall"]
		elseif inputs.moveDir.Magnitude > 0 then
			currentAnimation = animations[inputs.sprinting and "run" or "walk"]
		else
			currentAnimation = animations["idle"]
		end

		if currentAnimation ~= lastAnimation then
			currentAnimation.anim.Priority = Enum.AnimationPriority.Movement
			currentAnimation.anim:Play(animFadeTime)
			currentAnimation.anim:AdjustSpeed(currentAnimation.speed or 1)
			if lastAnimation then
				lastAnimation.anim:Stop(animFadeTime)
			end
		end
		if inputs.attacking and attackCD <= 0 then
			local id = math.random(1, 2)
			animations["attack"..id].anim.Priority = Enum.AnimationPriority.Action
			animations["attack"..id].anim:Play()
			animations["attack"..id].anim:AdjustSpeed(animations["attack"..id].speed or 1)
			attackCD = 1
		end
	end
	
	local function SetPartPosition(cframe)
		followPart.CFrame = CFrame.new(cframe.Position)
		local cameraPart = followPart:FindFirstChild("Nextbot Camera")
		if cameraPart then
			cameraPart.CFrame = CFrame.new(cframe.Position + cameraOffset)
		end
	end
	
	local function MoveWithCollision(delta)
		local moveDelta = currentVelocity / attributeScale * delta
		if moveDelta.Magnitude == 0 then
			return followPart.CFrame
		end
		
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = {character}
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.CollisionGroup = torso.CollisionGroup
		params.RespectCanCollide = true
		
		local result = workspace:Blockcast(followPart.CFrame + Vector3.new(0, stepheight / 2, 0), followPart.Size - Vector3.new(0, stepheight, 0), moveDelta, params)
		if result then
			local normal = result.Normal
			local vDot = currentVelocity:Dot(normal)
			if vDot < 0 then
				currentVelocity -= normal * vDot
			end
			moveDelta = currentVelocity / attributeScale * delta
		end
		return followPart.CFrame + moveDelta
	end

	if not humanoid or humanoid.Health <= 0 then return end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Seated or state == Enum.HumanoidStateType.PlatformStanding or state == Enum.HumanoidStateType.FallingDown then
		currentVelocity = Vector3.new()
		SetPartPosition(rootPart.CFrame + Vector3.new(0, 2.5, 0))
		UpdateAnimation("fall")
		return
	end
	rootPart.AssemblyLinearVelocity = Vector3.new()
	rootPart.AssemblyAngularVelocity = Vector3.new()

	if inputs.grounded then
		currentVelocity -= Vector3.new(0, currentVelocity.Y, 0)
		if inputs.jumping then
			currentVelocity += Vector3.new(0, CalculateJumpVelocity(), 0)
		elseif inputs.moveDir.Magnitude > 0 then
			local targetVelocity = inputs.moveDir * GetSpeed()
			local velocityDelta = targetVelocity - Vector3.new(currentVelocity.X, 0, currentVelocity.Z)

			local accel = acceleration * delta * attributeScale / 5
			if velocityDelta.Magnitude > accel then
				velocityDelta = velocityDelta.Unit * accel
			end

			currentVelocity += Vector3.new(velocityDelta.X, 0, velocityDelta.Z)
		else
			local horizontalVelocity = Vector3.new(currentVelocity.X, 0, currentVelocity.Z)
			local speed = horizontalVelocity.Magnitude

			if speed > 0 then
				local drop = deceleration * delta * attributeScale / 5
				local newSpeed = math.max(speed - drop, 0)
				currentVelocity = Vector3.new(horizontalVelocity.Unit.X * newSpeed, currentVelocity.Y, horizontalVelocity.Unit.Z * newSpeed)
			end
		end
	else
		currentVelocity -= Vector3.new(0, workspace.Gravity * attributeScale, 0) * delta
	end
	
	SetPartPosition(MoveWithCollision(delta))
	if inputs.grounded and not inputs.jumping then
		local groundY = inputs.grounded.Position.Y - skin
		local desiredY = groundY + (followPart.Size.Y / 2)
		SetPartPosition(CFrame.new(followPart.Position.X, desiredY, followPart.Position.Z))
	end
	if (followPart.CFrame.Position - rootPart.CFrame.Position).Magnitude > 5 then
		SetPartPosition(rootPart.CFrame + Vector3.new(0, 1, 0))
	end
	
	if inputs.teleporting and teleportDelayCurrent <= 0 then
		teleportDelayCurrent = teleportDelay
		local mouse = UIS:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y, 0)
		
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {character}
		params.RespectCanCollide = true
		params.CollisionGroup = torso.CollisionGroup
		local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if result then
			SetPartPosition(CFrame.new(result.Position + Vector3.new(0, 2.5, 0)))
			currentVelocity = Vector3.new()
		end
	end

	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0 then
		character:PivotTo(CFrame.new(followPart.Position + Vector3.new(0, 0.5, 0)) * CFrame.lookAt(Vector3.zero, flatLook.Unit))
	end

	rootPart.AssemblyLinearVelocity = currentVelocity / 10
	UpdateAnimation()
end

function AttackPlayers()
	
end

function Unload()
	loaded = false
	
	if character then
		camera.CameraSubject = character
		character.PrimaryPart = character:FindFirstChild("Head")
	end

	player.CameraMaxZoomDistance = cameraMaxZoom
	player.CameraMinZoomDistance = cameraMinZoom
	player.CameraMode = cameraMode
	
	followPart:Destroy()
	currentVelocity = Vector3.new()
	currentAnimation = nil
	attackCD = 0
end

-- Exec --

Load()
player.CharacterAdded:Connect(Load)

RunService.PostSimulation:Connect(Think)
