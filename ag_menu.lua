--!nostrict
-- AG HUB : Anti-AFK / WalkSpeed / JumpPower / Fly
-- Client-side only. Mobile-first UI (works on Delta and other UNC executors).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local lp = Players.LocalPlayer

local env = (getgenv and getgenv()) or _G
if env.AGMenuUnload then
	pcall(env.AGMenuUnload)
end

local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local state = { afk = false, speed = false, jump = false, fly = false }
local value = { speed = 50, jump = 100, fly = 60 }
local defaults = {}
local up, down = false, false

local function getHum()
	local c = lp.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
	local c = lp.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function isPress(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

-- ===== Features =====

-- Anti-AFK
bind(lp.Idled, function()
	if state.afk then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

-- Speed / Jump (re-applied every frame because many games reset them)
bind(RunService.Heartbeat, function()
	local h = getHum()
	if not h then
		return
	end
	if state.speed then
		h.WalkSpeed = value.speed
	end
	if state.jump then
		h.UseJumpPower = true
		h.JumpPower = value.jump
	end
end)

-- Fly
local flyBV, flyBG
local function stopFly()
	if flyBV then
		flyBV:Destroy()
		flyBV = nil
	end
	if flyBG then
		flyBG:Destroy()
		flyBG = nil
	end
	local h = getHum()
	if h then
		h.PlatformStand = false
	end
end
local function startFly()
	stopFly()
	local root, hum = getRoot(), getHum()
	if not root or not hum then
		return
	end
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
	flyBV.Velocity = Vector3.new(0, 0, 0)
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
	flyBG.P = 90000
	flyBG.CFrame = root.CFrame
	flyBG.Parent = root
	hum.PlatformStand = true
end

bind(RunService.RenderStepped, function()
	if not state.fly then
		return
	end
	local root, hum, cam = getRoot(), getHum(), workspace.CurrentCamera
	if not (root and hum and cam) then
		return
	end
	if not flyBV or flyBV.Parent ~= root then
		startFly()
		if not flyBV then
			return
		end
	end
	local vel = Vector3.new(0, 0, 0)
	local md = hum.MoveDirection
	if md.Magnitude > 0 then
		local lv = cam.CFrame:VectorToObjectSpace(md)
		vel = cam.CFrame.RightVector * lv.X + cam.CFrame.LookVector * (-lv.Z)
	end
	local v = (up and 1 or 0) - (down and 1 or 0)
	vel = vel + Vector3.new(0, v, 0)
	if vel.Magnitude > 1 then
		vel = vel.Unit
	end
	flyBV.Velocity = vel * value.fly
	flyBG.CFrame = cam.CFrame
end)

-- PC keys: E up, Q down
bind(UIS.InputBegan, function(i, gp)
	if gp then
		return
	end
	if i.KeyCode == Enum.KeyCode.E then
		up = true
	elseif i.KeyCode == Enum.KeyCode.Q then
		down = true
	end
end)
bind(UIS.InputEnded, function(i)
	if i.KeyCode == Enum.KeyCode.E then
		up = false
	elseif i.KeyCode == Enum.KeyCode.Q then
		down = false
	end
end)

-- ===== UI helpers =====

local C = {
	bg = Color3.fromRGB(16, 16, 24),
	card = Color3.fromRGB(27, 27, 40),
	accent = Color3.fromRGB(130, 90, 255),
	accent2 = Color3.fromRGB(0, 200, 255),
	text = Color3.fromRGB(240, 240, 250),
	sub = Color3.fromRGB(150, 150, 175),
	off = Color3.fromRGB(58, 58, 80),
	red = Color3.fromRGB(235, 70, 90),
	white = Color3.fromRGB(255, 255, 255),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	if parent then
		o.Parent = parent
	end
	return o
end
local function round(o, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
end
local function stroke(o, col, th)
	return new("UIStroke", { Color = col, Thickness = th or 1, Transparency = 0.35 }, o)
end

local gui = new("ScreenGui", {
	Name = "AGMenu",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
local okParent = pcall(function()
	gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not okParent or not gui.Parent then
	gui.Parent = lp:WaitForChild("PlayerGui")
end

local function drag(handle, target, onTap)
	local dragging, moved, start, startPos = false, false, nil, nil
	bind(handle.InputBegan, function(i)
		if isPress(i) then
			dragging = true
			moved = false
			start = i.Position
			startPos = target.Position
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and isMove(i) then
			local d = i.Position - start
			if d.Magnitude > 6 then
				moved = true
			end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if dragging and isPress(i) then
			dragging = false
			if not moved and onTap then
				onTap()
			end
		end
	end)
end

-- ===== Main window =====

local main = new("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(300, 330),
	Position = UDim2.new(0.5, -150, 0.5, -165),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
	Active = true,
}, gui)
round(main, 14)
stroke(main, C.accent, 1.5)

local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, main)
local title = new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 24),
	Position = UDim2.fromOffset(14, 5),
	BackgroundTransparency = 1,
	Text = "AG HUB",
	Font = Enum.Font.GothamBlack,
	TextSize = 20,
	TextColor3 = C.white,
	TextXAlignment = Enum.TextXAlignment.Left,
}, bar)
new("UIGradient", { Color = ColorSequence.new(C.accent, C.accent2) }, title)
new("TextLabel", {
	Size = UDim2.new(1, -60, 0, 14),
	Position = UDim2.fromOffset(14, 27),
	BackgroundTransparency = 1,
	Text = "Anti-AFK  |  Speed  |  Jump  |  Fly",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = C.sub,
	TextXAlignment = Enum.TextXAlignment.Left,
}, bar)
local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(30, 30),
	Position = UDim2.new(1, -40, 0, 7),
	BackgroundColor3 = C.card,
	Text = "-",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	AutoButtonColor = false,
}, bar)
round(minBtn, 8)
new("Frame", {
	Size = UDim2.new(1, -24, 0, 1),
	Position = UDim2.new(0, 12, 0, 44),
	BackgroundColor3 = C.off,
	BorderSizePixel = 0,
}, main)

local scroll = new("ScrollingFrame", {
	Size = UDim2.new(1, -16, 1, -56),
	Position = UDim2.fromOffset(8, 50),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.accent,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, scroll)

local order = 0
local function addCard(height, name, hint)
	order = order + 1
	local f = new("Frame", {
		Size = UDim2.new(1, -6, 0, height),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		LayoutOrder = order,
	}, scroll)
	round(f, 10)
	new("TextLabel", {
		Size = UDim2.new(1, -80, 0, 20),
		Position = UDim2.fromOffset(12, 8),
		BackgroundTransparency = 1,
		Text = name,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = C.text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	if hint then
		new("TextLabel", {
			Size = UDim2.new(1, -24, 0, 14),
			Position = UDim2.fromOffset(12, 30),
			BackgroundTransparency = 1,
			Text = hint,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextColor3 = C.sub,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, f)
	end
	return f
end

local function addSwitch(card, onChange)
	local sw = new("TextButton", {
		Size = UDim2.fromOffset(46, 24),
		Position = UDim2.new(1, -58, 0, 8),
		BackgroundColor3 = C.off,
		Text = "",
		AutoButtonColor = false,
	}, card)
	round(sw, 12)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
	}, sw)
	round(knob, 9)
	local on = false
	local function set(v)
		on = v
		TweenService:Create(sw, TweenInfo.new(0.15), { BackgroundColor3 = v and C.accent or C.off }):Play()
		TweenService:Create(knob, TweenInfo.new(0.15), { Position = v and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3) }):Play()
		onChange(v)
	end
	bind(sw.Activated, function()
		set(not on)
	end)
	return set
end

local function addSlider(card, label, min, max, init, cb, dy)
	dy = dy or 0
	local vt = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 16),
		Position = UDim2.fromOffset(12, 34 + dy),
		BackgroundTransparency = 1,
		Text = label .. ": " .. init,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local sbar = new("Frame", {
		Size = UDim2.new(1, -24, 0, 8),
		Position = UDim2.new(0, 12, 0, 62 + dy),
		BackgroundColor3 = C.off,
		BorderSizePixel = 0,
	}, card)
	round(sbar, 4)
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, sbar)
	round(fill, 4)
	new("UIGradient", { Color = ColorSequence.new(C.accent, C.accent2) }, fill)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, sbar)
	round(knob, 9)
	local hit = new("TextButton", {
		Size = UDim2.new(1, 12, 0, 32),
		Position = UDim2.new(0, -6, 0.5, -16),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 3,
	}, sbar)

	local function setAlpha(a)
		a = math.clamp(a, 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		local v = math.floor(min + (max - min) * a + 0.5)
		vt.Text = label .. ": " .. v
		cb(v)
	end
	local function fromInput(i)
		setAlpha((i.Position.X - sbar.AbsolutePosition.X) / math.max(1, sbar.AbsoluteSize.X))
	end

	local sliding = false
	bind(hit.InputBegan, function(i)
		if isPress(i) then
			sliding = true
			scroll.ScrollingEnabled = false
			fromInput(i)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if sliding and isMove(i) then
			fromInput(i)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if sliding and isPress(i) then
			sliding = false
			scroll.ScrollingEnabled = true
		end
	end)
	setAlpha((init - min) / (max - min))
end

-- ===== Fly up/down pad (shown only while fly is on) =====

local pad = new("Frame", {
	Size = UDim2.fromOffset(56, 124),
	Position = UDim2.new(1, -76, 0.5, -62),
	BackgroundTransparency = 1,
	Visible = false,
}, gui)
local function padButton(txt, y, setter)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(56, 56),
		Position = UDim2.fromOffset(0, y),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.2,
		Text = txt,
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextColor3 = C.white,
		AutoButtonColor = false,
	}, pad)
	round(b, 28)
	stroke(b, C.accent2, 2)
	local cur = nil
	bind(b.InputBegan, function(i)
		if isPress(i) then
			cur = i
			setter(true)
		end
	end)
	bind(UIS.InputEnded, function(i)
		if cur and i == cur then
			cur = nil
			setter(false)
		end
	end)
end
padButton("^", 0, function(v)
	up = v
end)
padButton("v", 68, function(v)
	down = v
end)

-- ===== Cards =====

local afkCard = addCard(56, "กันหลุด (Anti-AFK)", "กันโดนเตะเมื่อไม่ขยับ")
addSwitch(afkCard, function(v)
	state.afk = v
end)

local speedCard = addCard(82, "ความเร็ววิ่ง")
addSwitch(speedCard, function(v)
	state.speed = v
	local h = getHum()
	if h then
		if v then
			defaults.speed = h.WalkSpeed
		elseif defaults.speed then
			h.WalkSpeed = defaults.speed
		end
	end
end)
addSlider(speedCard, "ความเร็ว", 16, 300, value.speed, function(v)
	value.speed = v
end)

local jumpCard = addCard(82, "แรงกระโดด")
addSwitch(jumpCard, function(v)
	state.jump = v
	local h = getHum()
	if h then
		if v then
			defaults.jump = h.JumpPower
			defaults.useJP = h.UseJumpPower
		elseif defaults.jump then
			h.JumpPower = defaults.jump
			h.UseJumpPower = defaults.useJP
		end
	end
end)
addSlider(jumpCard, "แรงกระโดด", 50, 300, value.jump, function(v)
	value.jump = v
end)

local flyCard = addCard(94, "โหมดบิน (Fly)", "ปุ่ม ^ v ขวาจอ  |  PC: E ขึ้น, Q ลง")
addSwitch(flyCard, function(v)
	state.fly = v
	up, down = false, false
	pad.Visible = v
	if v then
		startFly()
	else
		stopFly()
	end
end)
addSlider(flyCard, "ความเร็วบิน", 10, 300, value.fly, function(v)
	value.fly = v
end, 14)

local footer = addCard(44, "")
local unloadBtn = new("TextButton", {
	Size = UDim2.new(1, -24, 0, 30),
	Position = UDim2.fromOffset(12, 7),
	BackgroundColor3 = C.red,
	Text = "ปิดสคริปต์ทั้งหมด",
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	TextColor3 = C.white,
	AutoButtonColor = false,
}, footer)
round(unloadBtn, 8)

-- ===== Floating button + show/hide =====

local fab = new("TextButton", {
	Name = "Fab",
	Size = UDim2.fromOffset(48, 48),
	Position = UDim2.new(0, 14, 0.5, -24),
	BackgroundColor3 = C.accent,
	Text = "AG",
	Font = Enum.Font.GothamBlack,
	TextSize = 16,
	TextColor3 = C.white,
	AutoButtonColor = false,
	Active = true,
}, gui)
round(fab, 24)
stroke(fab, C.accent2, 2)

local function toggleMenu()
	main.Visible = not main.Visible
end
drag(fab, fab, toggleMenu)
drag(bar, main)
bind(minBtn.Activated, function()
	main.Visible = false
end)
bind(UIS.InputBegan, function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then
		toggleMenu()
	end
end)

-- ===== Unload =====

local function unload()
	state.fly = false
	stopFly()
	local h = getHum()
	if h then
		if defaults.speed and state.speed then
			h.WalkSpeed = defaults.speed
		end
		if defaults.jump and state.jump then
			h.JumpPower = defaults.jump
			h.UseJumpPower = defaults.useJP
		end
	end
	state.speed, state.jump, state.afk = false, false, false
	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	gui:Destroy()
	env.AGMenuUnload = nil
end
env.AGMenuUnload = unload
bind(unloadBtn.Activated, unload)

pcall(function()
	game:GetService("StarterGui"):SetCore("SendNotification", {
		Title = "AG HUB",
		Text = "โหลดแล้ว: กดวงกลม AG เพื่อเปิด/ปิดเมนู",
		Duration = 4,
	})
end)
