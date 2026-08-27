--[[
    TWEEN SCRIPT GENERATOR - Roblox Studio Plugin
    ------------------------------------------------
    Lets you set:
      - Tween Target Type: Part (3D) or UI Element (GuiObject)
      - Start values (Position / Size / Rotation) for either a Part or a UI element
      - Offset values added to Start to produce End - e.g. an offset of 0.5
        means "Start + 0.5". Use a negative number (e.g. -2) to go the other way.
      - Full TweenInfo (Duration, EasingStyle, EasingDirection,
        RepeatCount, Reverses, DelayTime)

    Buttons:
      - Generate Script  -> builds the Lua code (referencing whatever matching
        object is currently selected in Explorer) and shows it in the output box
      - Preview on Selected Object -> applies the start state and plays the
        tween live in Studio on whatever's selected, so you can see it before
        shipping (Part mode needs a BasePart selected, UI mode needs a GuiObject)
      - Convert to Script -> creates a real Script (Part mode) or LocalScript
        (UI mode - GUIs only run client-side) as a child of whatever is
        selected in Explorer (falls back to ServerScriptService if nothing
        is selected)

    INSTALLATION:
      1. Find your local Plugins folder:
           Windows: %localappdata%\Roblox\Plugins
           Mac:     ~/Documents/Roblox/Plugins
         (In Studio you can also go to Plugins tab -> Plugins Folder, which
         opens this folder directly.)
      2. Save this file into that folder as "TweenGenerator.lua"
         (or any name you like, must end in .lua)
      3. Restart Studio (or Plugins tab -> Manage Plugins -> reload).
      4. A "Tween Generator" button will appear on the Plugins toolbar.
]]

local TweenService = game:GetService("TweenService")
local Selection = game:GetService("Selection")
local ServerScriptService = game:GetService("ServerScriptService")

-- ============================================================
-- TOOLBAR + WIDGET
-- ============================================================

local toolbar = plugin:CreateToolbar("Tween Generator")
local toggleButton = toolbar:CreateButton(
    "Tween Generator",
    "Open the Tween Script Generator",
    "rbxassetid://74787673852217"
)
toggleButton.ClickableWhenViewportHidden = true

local widgetInfo = DockWidgetPluginGuiInfo.new(
    Enum.InitialDockState.Float,
    false,  -- widget starts closed
    false,
    380, 640,
    340, 520
)

local widget = plugin:CreateDockWidgetPluginGui("TweenGeneratorWidget", widgetInfo)
widget.Title = "Tween Script Generator"

toggleButton.Click:Connect(function()
    widget.Enabled = not widget.Enabled
end)

-- UI STYLE HELPERS
-- ============================================================

local function applyCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = instance
end

local function applyStroke(instance, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(60, 60, 60)
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
end

local function applyPadding(instance, left, right, top, bottom)
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, left or 8)
    padding.PaddingRight = UDim.new(0, right or 8)
    padding.PaddingTop = UDim.new(0, top or 0)
    padding.PaddingBottom = UDim.new(0, bottom or 0)
    padding.Parent = instance
end

-- Lightens a Color3 by a fixed amount per channel - used to give buttons a
-- subtle highlighted border a shade lighter than their own fill color.
local function lighten(color, amount)
    amount = (amount or 25) / 255
    return Color3.new(
        math.clamp(color.R + amount, 0, 1),
        math.clamp(color.G + amount, 0, 1),
        math.clamp(color.B + amount, 0, 1)
    )
end

-- ============================================================
-- LAYOUT CONTAINER
-- ============================================================

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, 0)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 6
scroll.BackgroundColor3 = Color3.fromRGB(46, 46, 46)
scroll.BorderSizePixel = 0
scroll.Parent = widget
applyCorner(scroll, 8)
applyStroke(scroll, Color3.fromRGB(30, 30, 30), 1, 0.3)

local uiListLayout = Instance.new("UIListLayout")
uiListLayout.Padding = UDim.new(0, 6)
uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
uiListLayout.Parent = scroll

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingTop = UDim.new(0, 8)
uiPadding.PaddingLeft = UDim.new(0, 8)
uiPadding.PaddingRight = UDim.new(0, 8)
uiPadding.PaddingBottom = UDim.new(0, 12)
uiPadding.Parent = scroll

local orderCounter = 0
local function nextOrder()
    orderCounter += 1
    return orderCounter
end

-- ============================================================
-- UI HELPER BUILDERS
-- ============================================================

local function addHeader(text, group)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 26)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = nextOrder()
    label.Parent = scroll
    if group then
        table.insert(group, label)
    end
    return label
end

local function addVector3Row(labelText, defX, defY, defZ, group)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 46)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = nextOrder()
    frame.Parent = scroll

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local names = { "X", "Y", "Z" }
    local defaults = { defX, defY, defZ }
    local boxes = {}

    for i = 1, 3 do
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.31, 0, 0, 24)
        box.Position = UDim2.new((i - 1) * 0.345, 0, 0, 20)
        box.PlaceholderText = names[i]
        box.Text = tostring(defaults[i])
        box.ClearTextOnFocus = false
        box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.Parent = frame
        boxes[names[i]] = box
        applyStroke(box, Color3.fromRGB(70, 70, 70), 1)
        applyCorner(box, 4)
        applyPadding(box, 4, 4)
    end

    if group then
        table.insert(group, frame)
    end

    return boxes
end

-- UDim2 input row: 4 fields (Scale X, Offset X, Scale Y, Offset Y). Used for
-- UI element Position and Size, which are UDim2 rather than Vector3.
local function addUDim2Row(labelText, defSX, defOX, defSY, defOY, group)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 46)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = nextOrder()
    frame.Parent = scroll

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = labelText .. "  (Scale X / Offset X / Scale Y / Offset Y)"
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local names = { "SX", "OX", "SY", "OY" }
    local defaults = { defSX, defOX, defSY, defOY }
    local boxes = {}

    for i = 1, 4 do
        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.23, 0, 0, 24)
        box.Position = UDim2.new((i - 1) * 0.25, 0, 0, 20)
        box.PlaceholderText = names[i]
        box.Text = tostring(defaults[i])
        box.ClearTextOnFocus = false
        box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        box.TextColor3 = Color3.fromRGB(255, 255, 255)
        box.Font = Enum.Font.SourceSans
        box.TextSize = 13
        box.Parent = frame
        boxes[names[i]] = box

        applyStroke(box, Color3.fromRGB(70, 70, 70), 1)
        applyCorner(box, 4)
        applyPadding(box, 3, 3)
    end

    if group then
        table.insert(group, frame)
    end

    return boxes
end

local function makeTextField(labelText, default, group)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = nextOrder()
    frame.Parent = scroll

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 24)
    box.Position = UDim2.new(0, 0, 0, 20)
    box.Text = tostring(default)
    box.ClearTextOnFocus = false
    box.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.Parent = frame
    applyCorner(box, 4)
    applyStroke(box, Color3.fromRGB(70, 70, 70), 1)
    applyPadding(box, 6, 6)

    if group then
        table.insert(group, frame)
    end

    return box
end

local function makeCycleButton(labelText, options, defaultIndex, onChanged)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 44)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = nextOrder()
    frame.Parent = scroll
    

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame
    

    local index = defaultIndex or 1
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 24)
    button.Position = UDim2.new(0, 0, 0, 20)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 14
    button.Text = options[index]
    button.Parent = frame
    applyCorner(button, 4)
    applyStroke(button, Color3.fromRGB(70, 70, 70), 1)

    button.MouseButton1Click:Connect(function()
        index = index % #options + 1
        button.Text = options[index]
        if onChanged then
            onChanged(options[index])
        end
    end)

    return {
        getValue = function()
            return options[index]
        end,
    }
end

local function makeCheckbox(labelText, default)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = nextOrder()
    frame.Parent = scroll
    

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local checked = default or false
    local box = Instance.new("TextButton")
    box.Size = UDim2.new(0, 24, 0, 24)
    box.Position = UDim2.new(1, -24, 0, 2)
    box.BackgroundColor3 = checked and Color3.fromRGB(80, 170, 80) or Color3.fromRGB(60, 60, 60)
    box.Text = checked and "\226\156\147" or ""
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Parent = frame
    applyCorner(box, 4)
    applyStroke(box, Color3.fromRGB(70, 70, 70), 1)

    box.MouseButton1Click:Connect(function()
        checked = not checked
        box.BackgroundColor3 = checked and Color3.fromRGB(80, 170, 80) or Color3.fromRGB(60, 60, 60)
        box.Text = checked and "\226\156\147" or ""
    end)

    return {
        getValue = function()
            return checked
        end,
    }
end

-- ============================================================
-- BUILD THE FORM
-- ============================================================

local easingStyles = {
    "Linear", "Sine", "Back", "Quad", "Quart", "Quint",
    "Bounce", "Elastic", "Exponential", "Circular", "Cubic",
}
local easingDirections = { "In", "Out", "InOut" }

-- Groups of UI elements that get shown/hidden together depending on
-- whether we're tweening a 3D Part or a UI element (GuiObject).
local partGroup = {}
local uiGroup = {}
local setMode -- assigned once every element below has been created

addHeader("Tween Target")
local modeCycle = makeCycleButton(
    "Tween Target Type",
    { "Part (3D)", "UI Element (GuiObject)" },
    1,
    function(value)
        if setMode then
            setMode(value)
        end
    end
)

local useCurrentButton = Instance.new("TextButton")
useCurrentButton.Size = UDim2.new(1, 0, 0, 32)
useCurrentButton.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
useCurrentButton.TextColor3 = Color3.fromRGB(255, 255, 255)
useCurrentButton.Font = Enum.Font.SourceSansBold
useCurrentButton.TextSize = 14
useCurrentButton.Text = "Use Current Properties as Start"
useCurrentButton.LayoutOrder = nextOrder()
useCurrentButton.Parent = scroll
applyCorner(useCurrentButton,4)
applyStroke(useCurrentButton, lighten(useCurrentButton.BackgroundColor3, 30), 1, 0.4)

-- ---- Part (3D) fields --------------------------------------------------

addHeader("Position", partGroup)
local startPosBoxes = addVector3Row("Start Position", 0, 5, 0, partGroup)
local endPosBoxes = addVector3Row("Position Offset (added to Start)", 0, 10, 0, partGroup)

addHeader("Size", partGroup)
local startSizeBoxes = addVector3Row("Start Size", 4, 1, 2, partGroup)
local endSizeBoxes = addVector3Row("Size Offset (added to Start)", 0, 0, 0, partGroup)

addHeader("Rotation (Orientation, degrees)", partGroup)
local startRotBoxes = addVector3Row("Start Rotation", 0, 0, 0, partGroup)
local endRotBoxes = addVector3Row("Rotation Offset (added to Start)", 0, 90, 0, partGroup)

-- ---- UI Element (GuiObject) fields --------------------------------------

addHeader("UI Position", uiGroup)
local startUIPosBoxes = addUDim2Row("Start Position", 0, 0, 0, 0, uiGroup)
local endUIPosBoxes = addUDim2Row("Position Offset (added to Start)", 0, 0, 0.5, 0, uiGroup)

addHeader("UI Size", uiGroup)
local startUISizeBoxes = addUDim2Row("Start Size", 0, 100, 0, 50, uiGroup)
local endUISizeBoxes = addUDim2Row("Size Offset (added to Start)", 0, 0, 0, 0, uiGroup)

addHeader("UI Rotation (degrees)", uiGroup)
local startUIRotBox = makeTextField("Start Rotation", 0, uiGroup)
local endUIRotBox = makeTextField("Rotation Offset (added to Start)", 45, uiGroup)

-- ---- Shared TweenInfo ----------------------------------------------------

addHeader("TweenInfo")
local durationBox = makeTextField("Duration (seconds)", 1)
local easingStyleCycle = makeCycleButton("Easing Style", easingStyles, 1)
local easingDirectionCycle = makeCycleButton("Easing Direction", easingDirections, 2)
local repeatBox = makeTextField("Repeat Count (-1 = infinite)", 0)
local reversesCheck = makeCheckbox("Reverses", false)
local delayBox = makeTextField("Delay Time (seconds)", 0)

addHeader(" ")

local generateButton = Instance.new("TextButton")
generateButton.Size = UDim2.new(1, 0, 0, 36)
generateButton.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
generateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
generateButton.Font = Enum.Font.SourceSansBold
generateButton.TextSize = 16
generateButton.Text = "Generate Script"
generateButton.LayoutOrder = nextOrder()
generateButton.Parent = scroll
applyCorner(generateButton,4)
applyStroke(generateButton, lighten(generateButton.BackgroundColor3, 30), 1, 0.4)

local outputBox = Instance.new("TextBox")
outputBox.Size = UDim2.new(1, 0, 0, 240)
outputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
outputBox.TextColor3 = Color3.fromRGB(150, 255, 150)
outputBox.Font = Enum.Font.Code
outputBox.TextSize = 13
outputBox.TextXAlignment = Enum.TextXAlignment.Left
outputBox.TextYAlignment = Enum.TextYAlignment.Top
outputBox.MultiLine = true
outputBox.ClearTextOnFocus = false
outputBox.TextWrapped = true
outputBox.Text = ''
outputBox.LayoutOrder = nextOrder()
outputBox.Parent = scroll
applyCorner(outputBox, 6)
applyStroke(outputBox, Color3.fromRGB(60, 60, 60), 1)
applyPadding(outputBox, 8, 8, 6, 6)

local previewButton = Instance.new("TextButton")
previewButton.Size = UDim2.new(1, 0, 0, 36)
previewButton.BackgroundColor3 = Color3.fromRGB(200, 150, 50)
previewButton.TextColor3 = Color3.fromRGB(255, 255, 255)
previewButton.Font = Enum.Font.SourceSansBold
previewButton.TextSize = 16
previewButton.Text = "Preview on Selected Object"
previewButton.LayoutOrder = nextOrder()
previewButton.Parent = scroll
applyCorner(previewButton,4)
applyStroke(previewButton, lighten(previewButton.BackgroundColor3, 30), 1, 0.4)

local resetButton = Instance.new("TextButton")
resetButton.Size = UDim2.new(1, 0, 0, 32)
resetButton.BackgroundColor3 = Color3.fromRGB(150, 70, 70)
resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
resetButton.Font = Enum.Font.SourceSansBold
resetButton.TextSize = 14
resetButton.Text = "Reset to Original"
resetButton.LayoutOrder = nextOrder()
resetButton.Parent = scroll
applyCorner(resetButton,4)
applyStroke(resetButton, lighten(resetButton.BackgroundColor3, 30), 1, 0.4)

local insertButton = Instance.new("TextButton")
insertButton.Size = UDim2.new(1, 0, 0, 36)
insertButton.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
insertButton.TextColor3 = Color3.fromRGB(255, 255, 255)
insertButton.Font = Enum.Font.SourceSansBold
insertButton.TextSize = 16
insertButton.Text = "Convert to Script"
insertButton.LayoutOrder = nextOrder()
insertButton.Parent = scroll
applyCorner(insertButton,4)
applyStroke(insertButton, lighten(insertButton.BackgroundColor3, 30), 1, 0.4)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = ""
statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
statusLabel.Font = Enum.Font.SourceSansItalic
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.LayoutOrder = nextOrder()
statusLabel.Parent = scroll

-- ============================================================
-- CORE LOGIC
-- ============================================================

-- Builds a Lua-indexable path string for an Instance, e.g. game.Workspace.Part
-- or game.Workspace["My Part"] if the name isn't a valid identifier.
local function buildPath(instance)
    local parts = {}
    local current = instance
    while current and current ~= game do
        table.insert(parts, 1, current.Name)
        current = current.Parent
    end

    local path = "game"
    for _, name in ipairs(parts) do
        if name:match("^[%a_][%w_]*$") then
            path = path .. "." .. name
        else
            path = path .. '["' .. name:gsub('"', '\\"') .. '"]'
        end
    end
    return path
end

local function getSelectedTarget(mode)
    local target = Selection:Get()[1]
    if not target then
        return nil
    end
    if mode == "UI Element (GuiObject)" then
        if target:IsA("GuiObject") then
            return target
        end
    else
        if target:IsA("BasePart") then
            return target
        end
    end
    return nil
end

local function readVector3(boxes)
    local x = tonumber(boxes.X.Text) or 0
    local y = tonumber(boxes.Y.Text) or 0
    local z = tonumber(boxes.Z.Text) or 0
    return x, y, z
end

local function readUDim2(boxes)
    local sx = tonumber(boxes.SX.Text) or 0
    local ox = tonumber(boxes.OX.Text) or 0
    local sy = tonumber(boxes.SY.Text) or 0
    local oy = tonumber(boxes.OY.Text) or 0
    return sx, ox, sy, oy
end

-- Formats a number for display in a text field: whole numbers show with no
-- decimals, otherwise trimmed to 3 decimal places.
local function formatNum(n)
    if math.abs(n - math.floor(n + 0.5)) < 1e-4 then
        return tostring(math.floor(n + 0.5))
    end
    return string.format("%.3f", n)
end

local function getTweenSettings()
    local duration = tonumber(durationBox.Text) or 1
    local repeatCount = tonumber(repeatBox.Text) or 0
    local delayTime = tonumber(delayBox.Text) or 0
    local reverses = reversesCheck.getValue()
    local easingStyleName = easingStyleCycle.getValue()
    local easingDirectionName = easingDirectionCycle.getValue()
    return duration, repeatCount, delayTime, reverses, easingStyleName, easingDirectionName
end

local lastGeneratedCode = nil

local function generateCode()
    local mode = modeCycle.getValue()
    local isUIMode = mode == "UI Element (GuiObject)"
    local duration, repeatCount, delayTime, reverses, easingStyleName, easingDirectionName = getTweenSettings()

    local selectedTarget = getSelectedTarget(mode)
    local objectLine
    if selectedTarget then
        objectLine = string.format(
            "-- Direct reference to the %s that was selected in Explorer\nlocal object = %s",
            isUIMode and "UI element" or "part",
            buildPath(selectedTarget)
        )
    else
        objectLine = "-- No matching object was selected when this was generated, so this\n"
            .. "-- assumes the Script sits directly inside the object being tweened.\n"
            .. "local object = script.Parent"
    end

    local code
    if isUIMode then
        local sSX, sOX, sSY, sOY = readUDim2(startUIPosBoxes)
        local oSX, oOX, oSY, oOY = readUDim2(endUIPosBoxes)
        local ssSX, ssOX, ssSY, ssOY = readUDim2(startUISizeBoxes)
        local osSX, osOX, osSY, osOY = readUDim2(endUISizeBoxes)
        local startRotation = tonumber(startUIRotBox.Text) or 0
        local rotationOffset = tonumber(endUIRotBox.Text) or 0

        code = string.format(
            [[local TweenService = game:GetService("TweenService")

%s


local startPosition = UDim2.new(%s, %s, %s, %s)
local startSize = UDim2.new(%s, %s, %s, %s)
local startRotation = %s

object.Position = startPosition
object.Size = startSize
object.Rotation = startRotation


local sizeOffset = UDim2.new(%s, %s, %s, %s)
local rotationOffset = %s

-- TweenInfo
local tweenInfo = TweenInfo.new(
	%s,             
	Enum.EasingStyle.%s,
	Enum.EasingDirection.%s,
	%s,
	%s,
	%s
)


local goal = {
	Position = startPosition + positionOffset,
	Size = startSize + sizeOffset,
	Rotation = startRotation + rotationOffset,
}


local tween = TweenService:Create(object, tweenInfo, goal)
tween:Play()
]],
            objectLine,
            sSX, sOX, sSY, sOY, ssSX, ssOX, ssSY, ssOY, startRotation,
            oSX, oOX, oSY, oOY, osSX, osOX, osSY, osOY, rotationOffset,
            duration, easingStyleName, easingDirectionName, repeatCount, tostring(reverses), delayTime
        )
    else
        local sx, sy, sz = readVector3(startPosBoxes)
        local ox, oy, oz = readVector3(endPosBoxes)
        local ssx, ssy, ssz = readVector3(startSizeBoxes)
        local osx, osy, osz = readVector3(endSizeBoxes)
        local srx, sry, srz = readVector3(startRotBoxes)
        local orx, ory, orz = readVector3(endRotBoxes)

        code = string.format(
            [[local TweenService = game:GetService("TweenService")

%s


local startPosition = Vector3.new(%s, %s, %s)
local startSize = Vector3.new(%s, %s, %s)
local startRotation = Vector3.new(%s, %s, %s)

object.Position = startPosition
object.Size = startSize
object.Orientation = startRotation


local positionOffset = Vector3.new(%s, %s, %s)
local sizeOffset = Vector3.new(%s, %s, %s)
local rotationOffset = Vector3.new(%s, %s, %s)

-- TweenInfo
local tweenInfo = TweenInfo.new(
	%s,
	Enum.EasingStyle.%s,
	Enum.EasingDirection.%s,
	%s,
	%s,
	%s
)

local goal = {
	Position = startPosition + positionOffset,
	Size = startSize + sizeOffset,
	Orientation = startRotation + rotationOffset,
}


local tween = TweenService:Create(object, tweenInfo, goal)
tween:Play()
]],
            objectLine,
            sx, sy, sz, ssx, ssy, ssz, srx, sry, srz,
            ox, oy, oz, osx, osy, osz, orx, ory, orz,
            duration, easingStyleName, easingDirectionName, repeatCount, tostring(reverses), delayTime
        )
    end

    lastGeneratedCode = code
    outputBox.Text = code

    if selectedTarget then
        statusLabel.Text = 'Script generated for "' .. selectedTarget.Name .. '" (from current selection).'
    else
        statusLabel.Text = "Script generated. No matching selection found, so it assumes script.Parent."
    end
end

generateButton.MouseButton1Click:Connect(generateCode)

local lastPreviewSnapshot = nil
local lastTween = nil

useCurrentButton.MouseButton1Click:Connect(function()
    local mode = modeCycle.getValue()
    local isUIMode = mode == "UI Element (GuiObject)"
    local target = getSelectedTarget(mode)

    if not target then
        statusLabel.Text = isUIMode
            and "Select a UI element (GuiObject) in Explorer first."
            or "Select a BasePart in Explorer first."
        return
    end

    if isUIMode then
        local pos = target.Position
        startUIPosBoxes.SX.Text = formatNum(pos.X.Scale)
        startUIPosBoxes.OX.Text = formatNum(pos.X.Offset)
        startUIPosBoxes.SY.Text = formatNum(pos.Y.Scale)
        startUIPosBoxes.OY.Text = formatNum(pos.Y.Offset)

        local size = target.Size
        startUISizeBoxes.SX.Text = formatNum(size.X.Scale)
        startUISizeBoxes.OX.Text = formatNum(size.X.Offset)
        startUISizeBoxes.SY.Text = formatNum(size.Y.Scale)
        startUISizeBoxes.OY.Text = formatNum(size.Y.Offset)

        startUIRotBox.Text = formatNum(target.Rotation)
    else
        local pos = target.Position
        startPosBoxes.X.Text = formatNum(pos.X)
        startPosBoxes.Y.Text = formatNum(pos.Y)
        startPosBoxes.Z.Text = formatNum(pos.Z)

        local size = target.Size
        startSizeBoxes.X.Text = formatNum(size.X)
        startSizeBoxes.Y.Text = formatNum(size.Y)
        startSizeBoxes.Z.Text = formatNum(size.Z)

        local rot = target.Orientation
        startRotBoxes.X.Text = formatNum(rot.X)
        startRotBoxes.Y.Text = formatNum(rot.Y)
        startRotBoxes.Z.Text = formatNum(rot.Z)
    end

    statusLabel.Text = 'Pulled current properties from "' .. target.Name .. '" into the Start fields.'
end)

local function ResetCurrent()
    if not lastPreviewSnapshot then
            statusLabel.Text = "Nothing to reset yet - run a preview first."
            return
        end

        if lastTween then
            lastTween:Cancel()
            lastTween = nil
        end

        local snap = lastPreviewSnapshot
        local target = snap.target

        if not target or not target.Parent then
            statusLabel.Text = "The previewed object no longer exists."
            lastPreviewSnapshot = nil
            return
        end

        target.Position = snap.Position
        target.Size = snap.Size
        if snap.mode == "UI Element (GuiObject)" then
            target.Rotation = snap.Rotation
        else
            target.Orientation = snap.Orientation
        end

        statusLabel.Text = 'Restored "' .. target.Name .. '" to its pre-preview state.'
end

previewButton.MouseButton1Click:Connect(function()
    local mode = modeCycle.getValue()
    local isUIMode = mode == "UI Element (GuiObject)"
    local target = getSelectedTarget(mode)

    if not target then
        statusLabel.Text = isUIMode
            and "Select a UI element (GuiObject) in Explorer first to preview."
            or "Select a BasePart in Explorer first to preview."
        return
    end

    -- Cancel any tween still running from a previous preview
    if lastTween then
        lastTween:Cancel()
        lastTween = nil
    end

    -- Snapshot the object's current state so "Reset to Original" can restore it
    if isUIMode then
        lastPreviewSnapshot = {
            mode = mode,
            target = target,
            Position = target.Position,
            Size = target.Size,
            Rotation = target.Rotation,
        }
    else
        lastPreviewSnapshot = {
            mode = mode,
            target = target,
            Position = target.Position,
            Size = target.Size,
            Orientation = target.Orientation,
        }
    end

    local duration, repeatCount, delayTime, reverses, easingStyleName, easingDirectionName = getTweenSettings()
    local tweenInfo = TweenInfo.new(
        duration,
        Enum.EasingStyle[easingStyleName],
        Enum.EasingDirection[easingDirectionName],
        repeatCount,
        reverses,
        delayTime
    )

    local goal
    if isUIMode then
        local sSX, sOX, sSY, sOY = readUDim2(startUIPosBoxes)
        local oSX, oOX, oSY, oOY = readUDim2(endUIPosBoxes)
        local ssSX, ssOX, ssSY, ssOY = readUDim2(startUISizeBoxes)
        local osSX, osOX, osSY, osOY = readUDim2(endUISizeBoxes)
        local startRotation = tonumber(startUIRotBox.Text) or 0
        local rotationOffset = tonumber(endUIRotBox.Text) or 0

        local startPosition = UDim2.new(sSX, sOX, sSY, sOY)
        local startSize = UDim2.new(ssSX, ssOX, ssSY, ssOY)
        local positionOffset = UDim2.new(oSX, oOX, oSY, oOY)
        local sizeOffset = UDim2.new(osSX, osOX, osSY, osOY)

        target.Position = startPosition
        target.Size = startSize
        target.Rotation = startRotation

        goal = {
            Position = startPosition + positionOffset,
            Size = startSize + sizeOffset,
            Rotation = startRotation + rotationOffset,
        }
    else
        local sx, sy, sz = readVector3(startPosBoxes)
        local ox, oy, oz = readVector3(endPosBoxes)
        local ssx, ssy, ssz = readVector3(startSizeBoxes)
        local osx, osy, osz = readVector3(endSizeBoxes)
        local srx, sry, srz = readVector3(startRotBoxes)
        local orx, ory, orz = readVector3(endRotBoxes)

        local startPosition = Vector3.new(sx, sy, sz)
        local startSize = Vector3.new(ssx, ssy, ssz)
        local startRotation = Vector3.new(srx, sry, srz)
        local positionOffset = Vector3.new(ox, oy, oz)
        local sizeOffset = Vector3.new(osx, osy, osz)
        local rotationOffset = Vector3.new(orx, ory, orz)

        target.Position = startPosition
        target.Size = startSize
        target.Orientation = startRotation

        goal = {
            Position = startPosition + positionOffset,
            Size = startSize + sizeOffset,
            Orientation = startRotation + rotationOffset,
        }
    end

    local tween = TweenService:Create(target, tweenInfo, goal)
    lastTween = tween
    tween:Play()
    statusLabel.Text = 'Playing preview on "' .. target.Name .. '".'
    task.wait(duration + 1)
    ResetCurrent()
end)

resetButton.MouseButton1Click:Connect(function()
    ResetCurrent()
end)

insertButton.MouseButton1Click:Connect(function()
    if not lastGeneratedCode then
        generateCode()
    end

    local mode = modeCycle.getValue()
    local isUIMode = mode == "UI Element (GuiObject)"

    local target = Selection:Get()[1]
    local scriptParent = target or ServerScriptService

    -- UI elements only run their logic on the client, so they need a
    -- LocalScript. Parts commonly use a server Script.
    local newScript = Instance.new(isUIMode and "LocalScript" or "Script")
    newScript.Name = "TweenScript"
    newScript.Source = lastGeneratedCode
    newScript.Parent = scriptParent

    Selection:Set({ newScript })

    if target then
        statusLabel.Text = 'Inserted "'
            .. newScript.ClassName
            .. '" named TweenScript inside "'
            .. target.Name
            .. '".'
    else
        statusLabel.Text = 'No selection - inserted "'
            .. newScript.ClassName
            .. '" into ServerScriptService.'
    end
end)

-- ============================================================
-- MODE SWITCHING
-- ============================================================

setMode = function(modeName)
    local showPart = modeName ~= "UI Element (GuiObject)"
    for _, element in ipairs(partGroup) do
        element.Visible = showPart
    end
    for _, element in ipairs(uiGroup) do
        element.Visible = not showPart
    end
end

setMode(modeCycle.getValue())