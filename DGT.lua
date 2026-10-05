-- DGT Library (3단계): 창 + 탭 + 그룹박스 + 토글 + 배경색 선택기 + 배경 투명도 슬라이더

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Library = {
	Toggles = {},
	Options = {},
	Unloaded = false,
	_connections = {},
	Theme = {
		Background = Color3.fromRGB(24, 24, 28),
		Sidebar = Color3.fromRGB(30, 30, 36),
		Group = Color3.fromRGB(34, 34, 42),
		Element = Color3.fromRGB(46, 46, 56),
		Outline = Color3.fromRGB(60, 60, 72),
		Accent = Color3.fromRGB(110, 140, 255),
		Text = Color3.fromRGB(235, 235, 240),
	},
}

-- ===== 도구 함수 =====
local function create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	return inst
end

local function corner(r)
	return create("UICorner", { CornerRadius = UDim.new(0, r or 4) })
end

local function stroke()
	return create("UIStroke", { Color = Library.Theme.Outline, Thickness = 1 })
end

local function tween(inst, props)
	TweenService:Create(inst, TweenInfo.new(0.15), props):Play()
end

local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Library._connections, c)
	return c
end

local function isPointer(i)
	return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
end

local function isMove(i)
	return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
end

local function fire(obj)
	for _, f in ipairs(obj._cbs) do
		task.spawn(f, obj.Value)
	end
end

local function textLabel(props)
	local base = {
		BackgroundTransparency = 1,
		TextColor3 = Library.Theme.Text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	}
	for k, v in pairs(props) do
		base[k] = v
	end
	return create("TextLabel", base)
end

local function getGui()
	local gui = create("ScreenGui", { Name = "DGTLibrary", ResetOnSpawn = false })
	local ok = pcall(function()
		gui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
	end)
	if not ok or not gui.Parent then
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	return gui
end

-- ===== 그룹박스 (컴포넌트를 담는 상자) =====
local Groupbox = {}
Groupbox.__index = Groupbox

local function row(self, height)
	return create("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = self.Holder })
end

-- 토글: 켜짐/꺼짐 값을 가지고, 바뀔 때마다 Callback을 부름
function Groupbox:AddToggle(idx, info)
	info = info or {}
	local T = Library.Theme
	local obj = { Type = "Toggle", Value = info.Default == true, _cbs = {} }

	local r = row(self, 22)
	local box = create("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(0, 3),
		BackgroundColor3 = obj.Value and T.Accent or T.Element,
		Parent = r,
	}, { corner(4), stroke() })
	textLabel({ Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0), Text = info.Text or idx, Parent = r })
	local btn = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = r })

	function obj:SetValue(v)
		self.Value = v and true or false
		tween(box, { BackgroundColor3 = self.Value and T.Accent or T.Element })
		fire(self)
	end
	function obj:OnChanged(fn)
		table.insert(self._cbs, fn)
	end

	connect(btn.MouseButton1Click, function()
		obj:SetValue(not obj.Value)
	end)
	if info.Callback then
		obj:OnChanged(info.Callback)
	end
	if idx then
		Library.Toggles[idx] = obj
	end
	return obj
end

-- 색 선택기: R/G/B 슬라이더 3개로 Color3 값을 만들고, 바뀔 때마다 Callback을 부름
local function channelSlider(parent, y, name, start, onChange)
	local T = Library.Theme
	textLabel({ Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(16, 16), Text = name, Parent = parent })
	local bar = create("Frame", {
		Position = UDim2.new(0, 20, 0, y + 4),
		Size = UDim2.new(1, -60, 0, 8),
		BackgroundColor3 = T.Element,
		BorderSizePixel = 0,
		Parent = parent,
	}, { corner(4) })
	local fill = create("Frame", { Size = UDim2.fromScale(start / 255, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar }, { corner(4) })
	local num = textLabel({
		Position = UDim2.new(1, -34, 0, y),
		Size = UDim2.fromOffset(34, 16),
		Text = tostring(start),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = parent,
	})

	local function set(v)
		v = math.clamp(math.floor(v + 0.5), 0, 255)
		fill.Size = UDim2.fromScale(v / 255, 1)
		num.Text = tostring(v)
		return v
	end

	local dragging = false
	local function update(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		onChange(set(a * 255))
	end
	connect(bar.InputBegan, function(i)
		if isPointer(i) then
			dragging = true
			update(i.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if isPointer(i) then
			dragging = false
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and isMove(i) then
			update(i.Position.X)
		end
	end)

	return set
end

function Groupbox:AddColorPicker(idx, info)
	info = info or {}
	local default = info.Default or Color3.fromRGB(255, 255, 255)
	local obj = { Type = "ColorPicker", Value = default, _cbs = {} }
	local c = { r = math.floor(default.R * 255 + 0.5), g = math.floor(default.G * 255 + 0.5), b = math.floor(default.B * 255 + 0.5) }

	local r = row(self, 86)
	textLabel({ Size = UDim2.new(1, -30, 0, 16), Text = info.Text or idx, Parent = r })
	local swatch = create("Frame", {
		Position = UDim2.new(1, -20, 0, 0),
		Size = UDim2.fromOffset(20, 16),
		BackgroundColor3 = default,
		Parent = r,
	}, { corner(4), stroke() })

	local function apply()
		obj.Value = Color3.fromRGB(c.r, c.g, c.b)
		swatch.BackgroundColor3 = obj.Value
		fire(obj)
	end

	local setR = channelSlider(r, 22, "R", c.r, function(v) c.r = v apply() end)
	local setG = channelSlider(r, 44, "G", c.g, function(v) c.g = v apply() end)
	local setB = channelSlider(r, 66, "B", c.b, function(v) c.b = v apply() end)

	function obj:SetValue(color)
		c.r = math.floor(color.R * 255 + 0.5)
		c.g = math.floor(color.G * 255 + 0.5)
		c.b = math.floor(color.B * 255 + 0.5)
		setR(c.r) setG(c.g) setB(c.b)
		apply()
	end
	function obj:OnChanged(fn)
		table.insert(self._cbs, fn)
	end

	if info.Callback then
		obj:OnChanged(info.Callback)
	end
	if idx then
		Library.Options[idx] = obj
	end
	return obj
end

-- 슬라이더: Min~Max 사이 값을 가지고, 바뀔 때마다 Callback을 부름
function Groupbox:AddSlider(idx, info)
	info = info or {}
	local T = Library.Theme
	local min, max = info.Min or 0, info.Max or 100
	local rounding = info.Rounding or 0
	local obj = { Type = "Slider", Value = info.Default or min, _cbs = {} }

	local r = row(self, 38)
	local label = textLabel({ Size = UDim2.new(1, 0, 0, 18), Parent = r })
	local bar = create("Frame", {
		Position = UDim2.new(0, 0, 1, -12),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = T.Element,
		BorderSizePixel = 0,
		Parent = r,
	}, { corner(4) })
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Accent, BorderSizePixel = 0, Parent = bar }, { corner(4) })

	local function render()
		label.Text = (info.Text or idx) .. ": " .. tostring(obj.Value)
		fill.Size = UDim2.fromScale((obj.Value - min) / (max - min), 1)
	end

	function obj:SetValue(v)
		local m = 10 ^ rounding
		self.Value = math.clamp(math.floor(v * m + 0.5) / m, min, max)
		render()
		fire(self)
	end
	function obj:OnChanged(fn)
		table.insert(self._cbs, fn)
	end

	local dragging = false
	local function update(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		obj:SetValue(min + (max - min) * a)
	end
	connect(bar.InputBegan, function(i)
		if isPointer(i) then
			dragging = true
			update(i.Position.X)
		end
	end)
	connect(UIS.InputEnded, function(i)
		if isPointer(i) then
			dragging = false
		end
	end)
	connect(UIS.InputChanged, function(i)
		if dragging and isMove(i) then
			update(i.Position.X)
		end
	end)

	render()
	if info.Callback then
		obj:OnChanged(info.Callback)
	end
	if idx then
		Library.Options[idx] = obj
	end
	return obj
end

local function newGroupbox(column, name)
	local T = Library.Theme
	local g = setmetatable({}, Groupbox)
	g.Frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.Group,
		BorderSizePixel = 0,
		Parent = column,
	}, {
		corner(6),
		stroke(),
		create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		create("UIListLayout", { Padding = UDim.new(0, 6) }),
	})
	textLabel({ Size = UDim2.new(1, 0, 0, 18), Text = name, Font = Enum.Font.GothamBold, Parent = g.Frame })
	g.Holder = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = g.Frame }, {
		create("UIListLayout", { Padding = UDim.new(0, 6) }),
	})
	return g
end

-- ===== 탭 =====
local Tab = {}
Tab.__index = Tab

function Tab:AddLeftGroupbox(name)
	return newGroupbox(self.Left, name)
end

function Tab:AddRightGroupbox(name)
	return newGroupbox(self.Right, name)
end

-- ===== 창 =====
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local T = self.Theme
	local Window = { Tabs = {}, ActiveTab = nil }

	self.Gui = self.Gui or getGui()

	local main = create("Frame", {
		Name = "Main",
		Size = cfg.Size or UDim2.fromOffset(560, 380),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = cfg.BackgroundColor or T.Background,
		BackgroundTransparency = math.clamp(cfg.BackgroundTransparency or 0, 0, 1),
		BorderSizePixel = 0,
		Parent = self.Gui,
	}, { corner(8), stroke() })
	Window.Main = main

	local top = create("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = T.Sidebar, BorderSizePixel = 0, Parent = main }, { corner(8) })
	textLabel({ Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), Text = cfg.Title or "DGT Library", Font = Enum.Font.GothamBold, Parent = top })

	local sidebar = create("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(0, 120, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = main,
	}, { create("UIListLayout", { Padding = UDim.new(0, 4) }) })

	local pages = create("Frame", { Position = UDim2.fromOffset(136, 40), Size = UDim2.new(1, -144, 1, -48), BackgroundTransparency = 1, Parent = main })

	local function column(x, w)
		return create("ScrollingFrame", {
			Position = x,
			Size = w,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 2,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, { create("UIListLayout", { Padding = UDim.new(0, 8) }) })
	end

	local function select(tab)
		if Window.ActiveTab then
			Window.ActiveTab.Page.Visible = false
			tween(Window.ActiveTab.Button, { BackgroundColor3 = T.Sidebar })
		end
		Window.ActiveTab = tab
		tab.Page.Visible = true
		tween(tab.Button, { BackgroundColor3 = T.Accent })
	end

	function Window:AddTab(name)
		local tab = setmetatable({}, Tab)
		tab.Button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = T.Sidebar,
			Text = name,
			TextColor3 = T.Text,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			AutoButtonColor = false,
			Parent = sidebar,
		}, { corner(4) })
		tab.Page = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = pages })
		tab.Left = column(UDim2.fromScale(0, 0), UDim2.new(0.5, -4, 1, 0))
		tab.Right = column(UDim2.new(0.5, 4, 0, 0), UDim2.new(0.5, -4, 1, 0))
		tab.Left.Parent = tab.Page
		tab.Right.Parent = tab.Page

		connect(tab.Button.MouseButton1Click, function()
			select(tab)
		end)
		table.insert(self.Tabs, tab)
		if #self.Tabs == 1 then
			select(tab)
		end
		return tab
	end

	-- 배경색 변경
	function Window:SetBackgroundColor(color, animate)
		if animate then
			TweenService:Create(main, TweenInfo.new(0.25), { BackgroundColor3 = color }):Play()
		else
			main.BackgroundColor3 = color
		end
	end

	function Window:GetBackgroundColor()
		return main.BackgroundColor3
	end

	-- 배경 투명도 변경 (0 = 불투명, 1 = 완전 투명)
	function Window:SetBackgroundTransparency(value, animate)
		value = math.clamp(value, 0, 1)
		if animate then
			TweenService:Create(main, TweenInfo.new(0.25), { BackgroundTransparency = value }):Play()
		else
			main.BackgroundTransparency = value
		end
	end

	function Window:GetBackgroundTransparency()
		return main.BackgroundTransparency
	end

	-- 켜기 / 끄기
	function Window:SetVisible(state)
		main.Visible = state
	end

	function Window:Toggle()
		main.Visible = not main.Visible
	end

	function Window:IsVisible()
		return main.Visible
	end

	-- 키로 다시 켜기 (기본: RightShift)
	local key = cfg.ToggleKeybind or Enum.KeyCode.RightShift
	connect(UIS.InputBegan, function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == key then
			Window:Toggle()
		end
	end)

	return Window
end

function Library:Unload()
	self.Unloaded = true
	for _, c in ipairs(self._connections) do
		c:Disconnect()
	end
	if self.Gui then
		self.Gui:Destroy()
	end
end

return Library

--[[ 사용 예시

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/geonholim2012-max/DGT-Library/main/DGT.lua"))()

local Window = Library:CreateWindow({ Title = "DGT", ToggleKeybind = Enum.KeyCode.RightShift })
local Tab = Window:AddTab("Main")
local Group = Tab:AddLeftGroupbox("UI")

-- 껐다켰다 토글 (꺼지면 RightShift로 다시 켬)
Group:AddToggle("ShowUI", {
	Text = "Show UI",
	Default = true,
	Callback = function(on) Window:SetVisible(on) end,
})

-- 배경색 바꾸기
Group:AddColorPicker("BG", {
	Text = "Background",
	Default = Window:GetBackgroundColor(),
	Callback = function(color) Window:SetBackgroundColor(color) end,
})

-- 배경 투명도 바꾸기 (0 = 불투명, 1 = 완전 투명)
Group:AddSlider("BGTransparency", {
	Text = "Transparency",
	Min = 0,
	Max = 1,
	Default = Window:GetBackgroundTransparency(),
	Rounding = 2,
	Callback = function(v) Window:SetBackgroundTransparency(v) end,
})

]]
