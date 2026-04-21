--[[
    LOCAL PLAYER AI CHATBOT - IMPROVED UI
    Features:
    - Fully responsive GUI (mobile & PC) using scale-based sizing
    - Fixed dropdown menus with proper ZIndex and overlay parenting
    - Smooth toggle button, minimize, close
    - Tabbed navigation for compact layout on small screens
    - API key stored in GUI (persistent per session)
    - Personality system (on/off, customizable)
    - Chat memory/context
    - Multiple HTTP methods supported
    - Trigger word system
    - Response delay settings
    - Multiple AI Providers: OpenAI, Claude, Gemini, Groq, Grok, Meta AI, OpenRouter, Custom
]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ============ DETECT MOBILE ============
local function IsMobile()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Responsive sizing helpers
local function RS(pcVal, mobileVal)
    return IsMobile() and mobileVal or pcVal
end

-- Configuration Storage
local Config = {
    APIKey = "",
    APIProvider = "OpenAI",
    CustomEndpoint = "",
    ModelOverride = "",
    Enabled = false,
    PersonalityEnabled = true,
    Personality = "You are a friendly gamer. Keep responses short (1-2 sentences), casual, and fun. Use gaming slang occasionally.",
    TriggerMode = "Mention",
    TriggerKeywords = {},
    ResponseDelay = {Min = 1, Max = 3},
    ContextMemory = 10,
    MaxTokens = 100,
    Temperature = 0.8
}

local ProviderConfig = {
    OpenAI = {
        endpoint = "https://api.openai.com/v1/chat/completions",
        defaultModel = "gpt-4o-mini",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        models = {"gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"}
    },
    Claude = {
        endpoint = "https://api.anthropic.com/v1/messages",
        defaultModel = "claude-3-5-sonnet-20241022",
        authHeader = "x-api-key",
        authPrefix = "",
        extraHeaders = {["anthropic-version"] = "2023-06-01"},
        models = {"claude-3-5-sonnet-20241022", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"},
        customFormat = true
    },
    Gemini = {
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
        defaultModel = "gemini-1.5-flash",
        authType = "query",
        models = {"gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash-exp"},
        customFormat = true
    },
    Groq = {
        endpoint = "https://api.groq.com/openai/v1/chat/completions",
        defaultModel = "llama-3.3-70b-versatile",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        models = {"llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"}
    },
    Grok = {
        endpoint = "https://api.x.ai/v1/chat/completions",
        defaultModel = "grok-beta",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        models = {"grok-beta", "grok-2-1212"}
    },
    MetaAI = {
        endpoint = "https://api.llama-api.com/chat/completions",
        defaultModel = "llama3.1-405b",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        models = {"llama3.1-405b", "llama3.1-70b", "llama3.1-8b"}
    },
    OpenRouter = {
        endpoint = "https://openrouter.ai/api/v1/chat/completions",
        defaultModel = "openai/gpt-4o-mini",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        extraHeaders = {
            ["HTTP-Referer"] = "https://roblox.com",
            ["X-Title"] = "Roblox AI Chatbot"
        },
        models = {"openai/gpt-4o-mini", "anthropic/claude-3.5-sonnet", "google/gemini-flash-1.5", "meta-llama/llama-3.1-70b-instruct"}
    },
    Custom = {
        endpoint = "",
        defaultModel = "gpt-3.5-turbo",
        authHeader = "Authorization",
        authPrefix = "Bearer ",
        models = {}
    }
}

local ChatHistory = {}
local ProcessingMessage = false
local MessagesProcessed = 0

-- ============ HTTP REQUEST HANDLER ============
local function HttpRequest(url, method, headers, body)
    local success, response
    if syn and syn.request then
        success, response = pcall(function() return syn.request({Url=url,Method=method,Headers=headers,Body=body}) end)
    elseif http and http.request then
        success, response = pcall(function() return http.request({Url=url,Method=method,Headers=headers,Body=body}) end)
    elseif request then
        success, response = pcall(function() return request({Url=url,Method=method,Headers=headers,Body=body}) end)
    elseif http_request then
        success, response = pcall(function() return http_request({Url=url,Method=method,Headers=headers,Body=body}) end)
    elseif HttpService and HttpService.RequestAsync then
        success, response = pcall(function() return HttpService:RequestAsync({Url=url,Method=method,Headers=headers,Body=body}) end)
    else
        return nil, "No HTTP method available"
    end
    if success and response then return response else return nil, response end
end

-- ============ CREATE MAIN GUI ============
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AICharBotGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

-- Responsive main frame: on mobile use near-full screen width
local FRAME_W = RS(420, 0) -- 0 = use scale
local FRAME_H = RS(560, 0)
local FRAME_W_SCALE = RS(0, 0.95)
local FRAME_H_SCALE = RS(0, 0.88)

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(FRAME_W_SCALE, FRAME_W, FRAME_H_SCALE, FRAME_H)
MainFrame.Position = UDim2.new(0.5, RS(-210, 0), 0.5, RS(-280, 0))
if IsMobile() then
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
end
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
MainFrame.ClipsDescendants = true

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(90, 90, 240)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- ============ TITLE BAR ============
local TITLE_H = RS(48, 54)

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 44)
TitleBar.BorderSizePixel = 0
TitleBar.ZIndex = 2
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 14)
TitleCorner.Parent = TitleBar

-- Fix bottom corners of title bar
local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 14)
TitleFix.Position = UDim2.new(0, 0, 1, -14)
TitleFix.BackgroundColor3 = Color3.fromRGB(28, 28, 44)
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

-- Bot icon
local BotIcon = Instance.new("TextLabel")
BotIcon.Size = UDim2.new(0, 36, 0, 36)
BotIcon.Position = UDim2.new(0, 10, 0.5, -18)
BotIcon.BackgroundColor3 = Color3.fromRGB(80, 80, 210)
BotIcon.Text = "🤖"
BotIcon.TextSize = 20
BotIcon.Font = Enum.Font.GothamBold
BotIcon.TextColor3 = Color3.fromRGB(255,255,255)
BotIcon.ZIndex = 3
BotIcon.Parent = TitleBar
local BotIconCorner = Instance.new("UICorner")
BotIconCorner.CornerRadius = UDim.new(0, 8)
BotIconCorner.Parent = BotIcon

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -110, 1, 0)
TitleLabel.Position = UDim2.new(0, 54, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "AI Chat Bot"
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
TitleLabel.TextSize = RS(17, 19)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.ZIndex = 3
TitleLabel.Parent = TitleBar

local SubTitleLabel = Instance.new("TextLabel")
SubTitleLabel.Size = UDim2.new(1, -110, 0, 14)
SubTitleLabel.Position = UDim2.new(0, 54, 0, 28)
SubTitleLabel.BackgroundTransparency = 1
SubTitleLabel.Text = "Multi-Provider"
SubTitleLabel.TextColor3 = Color3.fromRGB(120, 120, 180)
SubTitleLabel.TextSize = 11
SubTitleLabel.Font = Enum.Font.Gotham
SubTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLabel.ZIndex = 3
SubTitleLabel.Parent = TitleBar

-- Minimize Button
local BTN_SIZE = RS(30, 38)
local BTN_GAP = RS(4, 6)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
MinimizeBtn.Position = UDim2.new(1, -(BTN_SIZE*2 + BTN_GAP*2 + 10), 0.5, -BTN_SIZE/2)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 190, 30)
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
MinimizeBtn.TextSize = RS(18, 22)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.ZIndex = 5
MinimizeBtn.Parent = TitleBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 8)
MinCorner.Parent = MinimizeBtn

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
CloseBtn.Position = UDim2.new(1, -(BTN_SIZE + BTN_GAP + 8), 0.5, -BTN_SIZE/2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 65, 65)
CloseBtn.Text = "×"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = RS(20, 24)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 5
CloseBtn.Parent = TitleBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

-- ============ TAB BAR ============
local TAB_H = RS(38, 46)
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1, 0, 0, TAB_H)
TabBar.Position = UDim2.new(0, 0, 0, TITLE_H)
TabBar.BackgroundColor3 = Color3.fromRGB(22, 22, 36)
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 2
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TabLayout.Padding = UDim.new(0, 4)
TabLayout.Parent = TabBar

local TabPad = Instance.new("UIPadding")
TabPad.PaddingLeft = UDim.new(0, 6)
TabPad.PaddingRight = UDim.new(0, 6)
TabPad.Parent = TabBar

-- ============ CONTENT AREA ============
local CONTENT_Y = TITLE_H + TAB_H + 2

local ContentScroll = Instance.new("ScrollingFrame")
ContentScroll.Name = "Content"
ContentScroll.Size = UDim2.new(1, 0, 1, -CONTENT_Y)
ContentScroll.Position = UDim2.new(0, 0, 0, CONTENT_Y)
ContentScroll.BackgroundTransparency = 1
ContentScroll.ScrollBarThickness = RS(5, 6)
ContentScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 230)
ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ContentScroll.ScrollingDirection = Enum.ScrollingDirection.Y
ContentScroll.ClipsDescendants = true
ContentScroll.Parent = MainFrame

local ContentPad = Instance.new("UIPadding")
ContentPad.PaddingLeft = UDim.new(0, RS(10, 8))
ContentPad.PaddingRight = UDim.new(0, RS(10, 8))
ContentPad.PaddingTop = UDim.new(0, 8)
ContentPad.PaddingBottom = UDim.new(0, 12)
ContentPad.Parent = ContentScroll

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentScroll

-- ============ DROPDOWN OVERLAY (fixes clipping) ============
-- Dropdowns render here so they're never clipped by parent frames
local DropOverlay = Instance.new("Frame")
DropOverlay.Name = "DropOverlay"
DropOverlay.Size = UDim2.new(1, 0, 1, 0)
DropOverlay.BackgroundTransparency = 1
DropOverlay.ZIndex = 50
DropOverlay.Parent = ScreenGui

-- ============ HELPER UI BUILDERS ============

local function ApplyCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function CreateSection(name, parent, layoutOrder)
    local section = Instance.new("Frame")
    section.Name = name
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundColor3 = Color3.fromRGB(26, 26, 40)
    section.BorderSizePixel = 0
    section.LayoutOrder = layoutOrder or 0
    section.Parent = parent
    ApplyCorner(section, 10)

    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 12)
    padding.PaddingLeft = UDim.new(0, 12)
    padding.PaddingRight = UDim.new(0, 12)
    padding.Parent = section

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = section

    return section
end

local function CreateSectionHeader(text, parent)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, RS(26, 32))
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 200, 255)
    lbl.TextSize = RS(14, 16)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = 0
    lbl.Parent = parent
    return lbl
end

local function CreateLabel(text, parent, h, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, h or RS(20, 24))
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(160, 160, 185)
    lbl.TextSize = RS(12, 14)
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.LayoutOrder = order or 99
    lbl.Parent = parent
    return lbl
end

local function CreateTextBox(placeholder, parent, multiline, order)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, multiline and RS(70, 90) or RS(38, 46))
    container.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    container.BorderSizePixel = 0
    container.LayoutOrder = order or 99
    container.Parent = parent
    ApplyCorner(container, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 90)
    stroke.Thickness = 1
    stroke.Parent = container

    local textbox = Instance.new("TextBox")
    textbox.Size = UDim2.new(1, -16, 1, -8)
    textbox.Position = UDim2.new(0, 8, 0, 4)
    textbox.BackgroundTransparency = 1
    textbox.PlaceholderText = placeholder
    textbox.PlaceholderColor3 = Color3.fromRGB(80, 80, 105)
    textbox.Text = ""
    textbox.TextColor3 = Color3.fromRGB(230, 230, 255)
    textbox.TextSize = RS(13, 15)
    textbox.Font = Enum.Font.Gotham
    textbox.TextXAlignment = Enum.TextXAlignment.Left
    textbox.TextYAlignment = Enum.TextYAlignment.Top
    textbox.ClearTextOnFocus = false
    textbox.MultiLine = multiline or false
    textbox.TextWrapped = true
    textbox.Parent = container

    textbox.Focused:Connect(function()
        stroke.Color = Color3.fromRGB(90, 90, 230)
        stroke.Thickness = 2
    end)
    textbox.FocusLost:Connect(function()
        stroke.Color = Color3.fromRGB(60, 60, 90)
        stroke.Thickness = 1
    end)

    return textbox, container
end

local function CreateToggle(text, default, parent, callback, order)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, RS(34, 42))
    container.BackgroundTransparency = 1
    container.LayoutOrder = order or 99
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -RS(60, 70), 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(210, 210, 235)
    label.TextSize = RS(13, 15)
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = container

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, RS(48, 58), 0, RS(24, 30))
    toggleBg.Position = UDim2.new(1, -RS(48, 58), 0.5, -RS(12, 15))
    toggleBg.BackgroundColor3 = default and Color3.fromRGB(70, 190, 110) or Color3.fromRGB(50, 50, 70)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = container
    ApplyCorner(toggleBg, 99)

    local W = RS(48, 58)
    local H = RS(24, 30)
    local CIRCLE = RS(20, 26)
    local toggleCircle = Instance.new("Frame")
    toggleCircle.Size = UDim2.new(0, CIRCLE, 0, CIRCLE)
    toggleCircle.Position = default and UDim2.new(1, -(CIRCLE+2), 0.5, -CIRCLE/2) or UDim2.new(0, 2, 0.5, -CIRCLE/2)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleCircle.BorderSizePixel = 0
    toggleCircle.Parent = toggleBg
    ApplyCorner(toggleCircle, 99)

    local enabled = default
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""
    toggleBtn.Parent = toggleBg

    toggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        toggleBg.BackgroundColor3 = enabled and Color3.fromRGB(70, 190, 110) or Color3.fromRGB(50, 50, 70)
        toggleCircle.Position = enabled and UDim2.new(1, -(CIRCLE+2), 0.5, -CIRCLE/2) or UDim2.new(0, 2, 0.5, -CIRCLE/2)
        if callback then callback(enabled) end
    end)

    return {
        SetEnabled = function(value)
            enabled = value
            toggleBg.BackgroundColor3 = enabled and Color3.fromRGB(70, 190, 110) or Color3.fromRGB(50, 50, 70)
            toggleCircle.Position = enabled and UDim2.new(1, -(CIRCLE+2), 0.5, -CIRCLE/2) or UDim2.new(0, 2, 0.5, -CIRCLE/2)
        end,
        GetEnabled = function() return enabled end
    }
end

-- Tracks current open dropdown so only one can be open at a time
local ActiveDropdown = nil

local function CreateDropdown(labelText, options, default, parent, callback, order)
    local ITEM_H = RS(36, 44)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, RS(60, 72))
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.LayoutOrder = order or 99
    container.Parent = parent

    local lbl = CreateLabel(labelText, container)
    lbl.Size = UDim2.new(1, 0, 0, RS(18, 22))
    lbl.LayoutOrder = 0

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, ITEM_H)
    dropdownBtn.Position = UDim2.new(0, 0, 0, RS(20, 24))
    dropdownBtn.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
    dropdownBtn.Text = ""
    dropdownBtn.ZIndex = 2
    dropdownBtn.Parent = container
    ApplyCorner(dropdownBtn, 8)

    local dropStroke = Instance.new("UIStroke")
    dropStroke.Color = Color3.fromRGB(60, 60, 90)
    dropStroke.Thickness = 1
    dropStroke.Parent = dropdownBtn

    local dropLabel = Instance.new("TextLabel")
    dropLabel.Size = UDim2.new(1, -40, 1, 0)
    dropLabel.Position = UDim2.new(0, 10, 0, 0)
    dropLabel.BackgroundTransparency = 1
    dropLabel.Text = default
    dropLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
    dropLabel.TextSize = RS(13, 15)
    dropLabel.Font = Enum.Font.Gotham
    dropLabel.TextXAlignment = Enum.TextXAlignment.Left
    dropLabel.ZIndex = 3
    dropLabel.Parent = dropdownBtn

    local arrowLabel = Instance.new("TextLabel")
    arrowLabel.Size = UDim2.new(0, 30, 1, 0)
    arrowLabel.Position = UDim2.new(1, -34, 0, 0)
    arrowLabel.BackgroundTransparency = 1
    arrowLabel.Text = "▾"
    arrowLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
    arrowLabel.TextSize = RS(14, 17)
    arrowLabel.Font = Enum.Font.GothamBold
    arrowLabel.ZIndex = 3
    arrowLabel.Parent = dropdownBtn

    local currentValue = default
    local isOpen = false

    -- The list lives in DropOverlay to avoid clipping
    local dropdownList = Instance.new("Frame")
    dropdownList.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
    dropdownList.BorderSizePixel = 0
    dropdownList.Visible = false
    dropdownList.ZIndex = 60
    dropdownList.ClipsDescendants = true
    dropdownList.Parent = DropOverlay
    ApplyCorner(dropdownList, 8)

    local listStroke = Instance.new("UIStroke")
    listStroke.Color = Color3.fromRGB(70, 70, 110)
    listStroke.Thickness = 1
    listStroke.Parent = dropdownList

    local listScroll = Instance.new("ScrollingFrame")
    listScroll.Size = UDim2.new(1, 0, 1, 0)
    listScroll.BackgroundTransparency = 1
    listScroll.ScrollBarThickness = RS(4, 5)
    listScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 200)
    listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listScroll.ZIndex = 61
    listScroll.Parent = dropdownList

    local listLayout = Instance.new("UIListLayout")
    listLayout.Parent = listScroll

    local function PositionList()
        -- Convert dropdownBtn position to ScreenGui space
        local absPos = dropdownBtn.AbsolutePosition
        local absSize = dropdownBtn.AbsoluteSize
        local numOpts = #listScroll:GetChildren() - 1 -- exclude layout
        local listH = math.min(numOpts * ITEM_H, RS(160, 200))
        dropdownList.Size = UDim2.new(0, absSize.X, 0, listH)
        -- decide whether to open above or below
        local screenH = ScreenGui.AbsoluteSize.Y
        if absPos.Y + absSize.Y + listH > screenH - 20 then
            dropdownList.Position = UDim2.new(0, absPos.X, 0, absPos.Y - listH - 2)
        else
            dropdownList.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
        end
    end

    local function CloseList()
        isOpen = false
        dropdownList.Visible = false
        arrowLabel.Text = "▾"
        dropStroke.Color = Color3.fromRGB(60, 60, 90)
        ActiveDropdown = nil
    end

    local function OpenList()
        if ActiveDropdown and ActiveDropdown ~= CloseList then
            ActiveDropdown()
        end
        isOpen = true
        PositionList()
        dropdownList.Visible = true
        arrowLabel.Text = "▴"
        dropStroke.Color = Color3.fromRGB(90, 90, 230)
        ActiveDropdown = CloseList
    end

    local function UpdateOptions(newOptions)
        for _, child in ipairs(listScroll:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, option in ipairs(newOptions) do
            local optionBtn = Instance.new("TextButton")
            optionBtn.Size = UDim2.new(1, 0, 0, ITEM_H)
            optionBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
            optionBtn.BackgroundTransparency = 0
            optionBtn.Text = ""
            optionBtn.ZIndex = 62
            optionBtn.Parent = listScroll

            local optLabel = Instance.new("TextLabel")
            optLabel.Size = UDim2.new(1, -16, 1, 0)
            optLabel.Position = UDim2.new(0, 10, 0, 0)
            optLabel.BackgroundTransparency = 1
            optLabel.Text = option
            optLabel.TextColor3 = Color3.fromRGB(200, 200, 230)
            optLabel.TextSize = RS(12, 15)
            optLabel.Font = Enum.Font.Gotham
            optLabel.TextXAlignment = Enum.TextXAlignment.Left
            optLabel.ZIndex = 63
            optLabel.Parent = optionBtn

            local selIndicator = Instance.new("Frame")
            selIndicator.Size = UDim2.new(0, 3, 0.6, 0)
            selIndicator.Position = UDim2.new(0, 0, 0.2, 0)
            selIndicator.BackgroundColor3 = Color3.fromRGB(90, 90, 230)
            selIndicator.BorderSizePixel = 0
            selIndicator.Visible = (option == currentValue)
            selIndicator.ZIndex = 63
            selIndicator.Parent = optionBtn
            ApplyCorner(selIndicator, 2)

            optionBtn.MouseButton1Click:Connect(function()
                currentValue = option
                dropLabel.Text = option
                -- update indicators
                for _, c in ipairs(listScroll:GetChildren()) do
                    if c:IsA("TextButton") then
                        local ind = c:FindFirstChildWhichIsA("Frame")
                        if ind then ind.Visible = (c:FindFirstChildWhichIsA("TextLabel") and c:FindFirstChildWhichIsA("TextLabel").Text == option) end
                    end
                end
                CloseList()
                if callback then callback(option) end
            end)

            optionBtn.MouseEnter:Connect(function()
                optionBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 65)
            end)
            optionBtn.MouseLeave:Connect(function()
                optionBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
            end)
        end
    end

    UpdateOptions(options)

    dropdownBtn.MouseButton1Click:Connect(function()
        if isOpen then CloseList() else OpenList() end
    end)

    -- Close dropdown when clicking elsewhere
    DropOverlay.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and isOpen then
            local pos = input.Position
            local lp = dropdownList.AbsolutePosition
            local ls = dropdownList.AbsoluteSize
            if pos.X < lp.X or pos.X > lp.X + ls.X or pos.Y < lp.Y or pos.Y > lp.Y + ls.Y then
                CloseList()
            end
        end
    end)

    return {
        GetValue = function() return currentValue end,
        SetValue = function(value)
            currentValue = value
            dropLabel.Text = value
        end,
        UpdateOptions = function(newOpts)
            UpdateOptions(newOpts)
            if isOpen then PositionList() end
        end
    }
end

local function CreateButton(text, parent, callback, color, order)
    local BTN_H = RS(38, 46)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, BTN_H)
    btn.BackgroundColor3 = color or Color3.fromRGB(70, 70, 200)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = RS(13, 15)
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.LayoutOrder = order or 99
    btn.Parent = parent
    ApplyCorner(btn, 8)

    local shadow = Instance.new("UIStroke")
    shadow.Color = Color3.fromRGB(0, 0, 0)
    shadow.Thickness = 0
    shadow.Parent = btn

    btn.MouseButton1Click:Connect(callback)

    local baseColor = color or Color3.fromRGB(70, 70, 200)
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(
            math.min(255, baseColor.R * 255 + 25),
            math.min(255, baseColor.G * 255 + 25),
            math.min(255, baseColor.B * 255 + 25)
        )
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = baseColor
    end)
    btn.MouseButton1Down:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(
            math.max(0, baseColor.R * 255 - 20),
            math.max(0, baseColor.G * 255 - 20),
            math.max(0, baseColor.B * 255 - 20)
        )
    end)
    btn.MouseButton1Up:Connect(function()
        btn.BackgroundColor3 = baseColor
    end)

    return btn
end

-- ============ TAB SYSTEM ============
local tabs = {}
local tabContents = {}
local activeTab = nil

local TAB_NAMES = {"⚙️ Setup", "🎭 Personality", "🎯 Triggers", "📊 Status"}

local function SwitchTab(name)
    activeTab = name
    for tName, btn in pairs(tabs) do
        if tName == name then
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 210)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
            btn.TextColor3 = Color3.fromRGB(140, 140, 170)
        end
    end
    for tName, frame in pairs(tabContents) do
        frame.Visible = (tName == name)
    end
end

-- Build tab buttons
local TAB_BTN_W = RS(88, 0) -- 0 = use equal fraction on mobile

for i, tabName in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    if IsMobile() then
        btn.Size = UDim2.new(0.23, -3, 0, TAB_H - 10)
    else
        btn.Size = UDim2.new(0, TAB_BTN_W, 0, TAB_H - 10)
    end
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(140, 140, 170)
    btn.TextSize = RS(11, 13)
    btn.Font = Enum.Font.GothamMedium
    btn.AutoButtonColor = false
    btn.Parent = TabBar
    ApplyCorner(btn, 6)
    tabs[tabName] = btn

    btn.MouseButton1Click:Connect(function()
        SwitchTab(tabName)
    end)
end

-- Tab content frames
for _, tabName in ipairs(TAB_NAMES) do
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 0)
    f.AutomaticSize = Enum.AutomaticSize.Y
    f.BackgroundTransparency = 1
    f.Visible = false
    f.Parent = ContentScroll

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = f

    tabContents[tabName] = f
end

-- ============ TAB 1: SETUP ============
local SetupTab = tabContents["⚙️ Setup"]

-- Master toggle section
local MasterSec = CreateSection("Master", SetupTab, 1)
CreateSectionHeader("🤖 AI Chatbot Control", MasterSec)
local MasterToggle = CreateToggle("Enable AI Auto-Responses", false, MasterSec, function(enabled)
    Config.Enabled = enabled
end, 2)

-- API section
local APISec = CreateSection("API", SetupTab, 2)
CreateSectionHeader("🔑 API Configuration", APISec)

local providerList = {"OpenAI", "Claude", "Gemini", "Groq", "Grok", "MetaAI", "OpenRouter", "Custom"}
local ModelDropdown

local APIProviderDropdown = CreateDropdown("Provider", providerList, "OpenAI", APISec, function(value)
    Config.APIProvider = value
    local providerData = ProviderConfig[value]
    if providerData and ModelDropdown then
        ModelDropdown.UpdateOptions(providerData.models)
        if #providerData.models > 0 then
            ModelDropdown.SetValue(providerData.defaultModel)
            Config.ModelOverride = ""
        end
    end
end, 2)

ModelDropdown = CreateDropdown("Model", ProviderConfig.OpenAI.models, ProviderConfig.OpenAI.defaultModel, APISec, function(value)
    Config.ModelOverride = value
end, 3)

CreateLabel("API Key", APISec, nil, 4)
local APIKeyBox = CreateTextBox("Enter your API key here...", APISec, false, 5)
APIKeyBox.FocusLost:Connect(function() Config.APIKey = APIKeyBox.Text end)

CreateLabel("Custom Endpoint (only for Custom provider)", APISec, nil, 6)
local CustomEndpointBox = CreateTextBox("https://your-api-endpoint.com/v1/chat/completions", APISec, false, 7)
CustomEndpointBox.FocusLost:Connect(function() Config.CustomEndpoint = CustomEndpointBox.Text end)

local InfoBox = Instance.new("TextLabel")
InfoBox.Size = UDim2.new(1, 0, 0, RS(36, 44))
InfoBox.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
InfoBox.Text = "📌 Get API keys from provider websites (openai.com, anthropic.com, etc.)"
InfoBox.TextColor3 = Color3.fromRGB(130, 130, 165)
InfoBox.TextSize = RS(11, 13)
InfoBox.Font = Enum.Font.Gotham
InfoBox.TextWrapped = true
InfoBox.LayoutOrder = 8
InfoBox.Parent = APISec
ApplyCorner(InfoBox, 6)

-- Advanced section
local AdvSec = CreateSection("Advanced", SetupTab, 3)
CreateSectionHeader("⚙️ Advanced Settings", AdvSec)

CreateLabel("Response Delay Min (seconds)", AdvSec, nil, 2)
local MinDelayBox = CreateTextBox("1", AdvSec, false, 3)
MinDelayBox.Text = "1"
MinDelayBox.FocusLost:Connect(function() Config.ResponseDelay.Min = tonumber(MinDelayBox.Text) or 1 end)

CreateLabel("Response Delay Max (seconds)", AdvSec, nil, 4)
local MaxDelayBox = CreateTextBox("3", AdvSec, false, 5)
MaxDelayBox.Text = "3"
MaxDelayBox.FocusLost:Connect(function() Config.ResponseDelay.Max = tonumber(MaxDelayBox.Text) or 3 end)

CreateLabel("Context Memory (messages)", AdvSec, nil, 6)
local MemoryBox = CreateTextBox("10", AdvSec, false, 7)
MemoryBox.Text = "10"
MemoryBox.FocusLost:Connect(function() Config.ContextMemory = tonumber(MemoryBox.Text) or 10 end)

CreateLabel("Max Response Tokens", AdvSec, nil, 8)
local TokensBox = CreateTextBox("100", AdvSec, false, 9)
TokensBox.Text = "100"
TokensBox.FocusLost:Connect(function() Config.MaxTokens = tonumber(TokensBox.Text) or 100 end)

CreateLabel("Temperature (0.0 – 2.0)", AdvSec, nil, 10)
local TempBox = CreateTextBox("0.8", AdvSec, false, 11)
TempBox.Text = "0.8"
TempBox.FocusLost:Connect(function() Config.Temperature = tonumber(TempBox.Text) or 0.8 end)

-- ============ TAB 2: PERSONALITY ============
local PersonTab = tabContents["🎭 Personality"]

local PersonSec = CreateSection("Personality", PersonTab, 1)
CreateSectionHeader("🎭 Personality Settings", PersonSec)
local PersonalityToggle = CreateToggle("Enable Custom Personality", true, PersonSec, function(enabled)
    Config.PersonalityEnabled = enabled
end, 2)
CreateLabel("System Prompt", PersonSec, nil, 3)
local PersonalityBox = CreateTextBox("Describe how the AI should act...", PersonSec, true, 4)
PersonalityBox.Text = Config.Personality
PersonalityBox.FocusLost:Connect(function() Config.Personality = PersonalityBox.Text end)

-- Presets
local PresetSec = CreateSection("Presets", PersonTab, 2)
CreateSectionHeader("📋 Personality Presets", PresetSec)
CreateLabel("Tap a preset to instantly apply it", PresetSec, nil, 2)

local presets = {
    {name = "🎮 Friendly Gamer", prompt = "You are a friendly gamer. Keep responses short (1-2 sentences), casual, and fun. Use gaming slang occasionally.", color = Color3.fromRGB(60, 170, 90)},
    {name = "😈 Toxic Player", prompt = "You respond sarcastically and competitively. Short roasts and trash talk, but nothing actually offensive.", color = Color3.fromRGB(190, 60, 60)},
    {name = "📚 Helpful Guide", prompt = "You're a helpful player who gives tips and encouragement. Keep responses brief and supportive.", color = Color3.fromRGB(60, 80, 190)},
    {name = "🤫 Silent Type", prompt = "You respond with very short answers (1-5 words max). Mysterious and cool.", color = Color3.fromRGB(80, 80, 100)},
    {name = "🔥 Hype Beast", prompt = "Everything is exciting! Use caps occasionally, lots of energy. LETS GO!", color = Color3.fromRGB(220, 120, 20)},
    {name = "🤖 Robot Mode", prompt = "You speak in a robotic manner. Use technical terms. Beep boop.", color = Color3.fromRGB(100, 120, 180)},
}
for idx, preset in ipairs(presets) do
    CreateButton(preset.name, PresetSec, function()
        Config.Personality = preset.prompt
        PersonalityBox.Text = preset.prompt
    end, preset.color, 3 + idx)
end

-- ============ TAB 3: TRIGGERS ============
local TrigTab = tabContents["🎯 Triggers"]

local TrigSec = CreateSection("Triggers", TrigTab, 1)
CreateSectionHeader("🎯 Response Triggers", TrigSec)

local TriggerDropdown = CreateDropdown("Trigger Mode", {"All Messages", "Mention Only", "Keywords"}, "Mention Only", TrigSec, function(value)
    local modeMap = {["All Messages"] = "All", ["Mention Only"] = "Mention", ["Keywords"] = "Keyword"}
    Config.TriggerMode = modeMap[value] or "Mention"
end, 2)

CreateLabel("Keywords (comma-separated, e.g.: hi, hello, hey)", TrigSec, nil, 3)
local KeywordsBox = CreateTextBox("hi, hello, hey, what's up", TrigSec, false, 4)
KeywordsBox.FocusLost:Connect(function()
    Config.TriggerKeywords = {}
    for word in string.gmatch(KeywordsBox.Text, "[^,]+") do
        table.insert(Config.TriggerKeywords, string.lower(string.match(word, "^%s*(.-)%s*$")))
    end
end)

local TrigInfoSec = CreateSection("TrigInfo", TrigTab, 2)
CreateSectionHeader("ℹ️ Mode Guide", TrigInfoSec)
CreateLabel("All Messages — respond to every chat message", TrigInfoSec, nil, 2)
CreateLabel("Mention Only — respond when your name is mentioned", TrigInfoSec, nil, 3)
CreateLabel("Keywords — respond only when listed words appear", TrigInfoSec, nil, 4)

-- ============ TAB 4: STATUS ============
local StatusTab = tabContents["📊 Status"]

local StatusSec = CreateSection("Status", StatusTab, 1)
CreateSectionHeader("📊 Live Status", StatusSec)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, RS(64, 80))
StatusLabel.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
StatusLabel.Text = "Status: Ready\nProvider: OpenAI\nMessages: 0"
StatusLabel.TextColor3 = Color3.fromRGB(130, 230, 150)
StatusLabel.TextSize = RS(12, 14)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextWrapped = true
StatusLabel.LayoutOrder = 2
StatusLabel.Parent = StatusSec
ApplyCorner(StatusLabel, 6)
local StatusPad = Instance.new("UIPadding")
StatusPad.PaddingLeft = UDim.new(0, 8)
StatusPad.PaddingTop = UDim.new(0, 6)
StatusPad.Parent = StatusLabel

local ActionSec = CreateSection("Actions", StatusTab, 2)
CreateSectionHeader("🛠️ Actions", ActionSec)

CreateButton("🧪 Test API Connection", ActionSec, function()
    StatusLabel.Text = "Status: Testing...\nProvider: " .. Config.APIProvider .. "\nMessages: " .. MessagesProcessed
    task.spawn(function()
        local success, result = pcall(GenerateResponse, "Say 'API working!' in 3 words or less.")
        if success and result then
            StatusLabel.Text = "Status: ✅ API Working!\nResponse: " .. result:sub(1, 40)
        else
            StatusLabel.Text = "Status: ❌ Error\n" .. tostring(result):sub(1, 50)
        end
    end)
end, Color3.fromRGB(60, 170, 90), 2)

CreateButton("🗑️ Clear Chat History", ActionSec, function()
    ChatHistory = {}
    StatusLabel.Text = "Status: ✅ History Cleared\nProvider: " .. Config.APIProvider .. "\nMessages: " .. MessagesProcessed
end, Color3.fromRGB(170, 60, 60), 3)

CreateButton("🔄 Reset Config", ActionSec, function()
    Config.APIKey = ""
    Config.Enabled = false
    APIKeyBox.Text = ""
    MasterToggle.SetEnabled(false)
    StatusLabel.Text = "Status: Config Reset\nProvider: " .. Config.APIProvider .. "\nMessages: " .. MessagesProcessed
end, Color3.fromRGB(100, 80, 160), 4)

-- ============ TOGGLE / FAB BUTTON ============
local FAB_SIZE = RS(52, 62)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0, FAB_SIZE, 0, FAB_SIZE)
ToggleButton.Position = UDim2.new(0, RS(14, 10), 0.5, -FAB_SIZE/2)
ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 200)
ToggleButton.Text = "🤖"
ToggleButton.TextSize = RS(24, 28)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.ZIndex = 10
ToggleButton.AutoButtonColor = false
ToggleButton.Parent = ScreenGui
ApplyCorner(ToggleButton, 99)

local FabStroke = Instance.new("UIStroke")
FabStroke.Color = Color3.fromRGB(120, 120, 255)
FabStroke.Thickness = 2
FabStroke.Parent = ToggleButton

ToggleButton.MouseEnter:Connect(function()
    ToggleButton.BackgroundColor3 = Color3.fromRGB(90, 90, 230)
end)
ToggleButton.MouseLeave:Connect(function()
    ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 200)
end)

-- ============ DRAGGING ============
local function MakeDraggable(frame, handle)
    local dragging = false
    local dragInput, dragStart, startPos
    handle = handle or frame

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

MakeDraggable(MainFrame, TitleBar)
MakeDraggable(ToggleButton)

-- ============ GUI CONTROLS ============
local minimized = false

MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    ContentScroll.Visible = not minimized
    TabBar.Visible = not minimized
    if minimized then
        MainFrame.Size = UDim2.new(FRAME_W_SCALE, FRAME_W, 0, TITLE_H)
        MinimizeBtn.Text = "+"
    else
        MainFrame.Size = UDim2.new(FRAME_W_SCALE, FRAME_W, FRAME_H_SCALE, FRAME_H)
        MinimizeBtn.Text = "−"
    end
    if ActiveDropdown then ActiveDropdown() end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    if ActiveDropdown then ActiveDropdown() end
end)

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    if not MainFrame.Visible and ActiveDropdown then ActiveDropdown() end
end)

-- Default to first tab
SwitchTab("⚙️ Setup")

-- ============ AI RESPONSE GENERATION ============
function GenerateResponse(userMessage)
    if Config.APIKey == "" then return nil, "No API key configured" end
    local providerData = ProviderConfig[Config.APIProvider]
    if not providerData then return nil, "Invalid provider" end

    local systemPrompt
    if Config.PersonalityEnabled and Config.Personality ~= "" then
        systemPrompt = Config.Personality .. "\n\nYou are responding in a Roblox game chat. Keep responses short and chat-appropriate. Your name is " .. LocalPlayer.Name .. "."
    else
        systemPrompt = "You are responding in a Roblox game chat as " .. LocalPlayer.Name .. ". Keep responses very short (1-2 sentences max)."
    end

    local messages = {}
    table.insert(messages, {role = "system", content = systemPrompt})

    local historyStart = math.max(1, #ChatHistory - Config.ContextMemory + 1)
    for i = historyStart, #ChatHistory do
        table.insert(messages, ChatHistory[i])
    end
    table.insert(messages, {role = "user", content = userMessage})

    local model = Config.ModelOverride ~= "" and Config.ModelOverride or providerData.defaultModel
    local endpoint = providerData.endpoint
    local headers = {["Content-Type"] = "application/json"}
    local body

    if providerData.authType == "query" then
        endpoint = endpoint:gsub("{model}", model) .. "?key=" .. Config.APIKey
    else
        headers[providerData.authHeader] = providerData.authPrefix .. Config.APIKey
    end

    if providerData.extraHeaders then
        for k, v in pairs(providerData.extraHeaders) do headers[k] = v end
    end

    if Config.APIProvider == "Custom" and Config.CustomEndpoint ~= "" then
        endpoint = Config.CustomEndpoint
    end

    if Config.APIProvider == "Claude" then
        body = HttpService:JSONEncode({
            model = model,
            max_tokens = Config.MaxTokens,
            system = systemPrompt,
            messages = (function()
                local claudeMessages = {}
                for i = 2, #messages do
                    table.insert(claudeMessages, {
                        role = messages[i].role == "assistant" and "assistant" or "user",
                        content = messages[i].content
                    })
                end
                return claudeMessages
            end)()
        })
    elseif Config.APIProvider == "Gemini" then
        local contents = {}
        for i = 2, #messages do
            table.insert(contents, {
                role = messages[i].role == "assistant" and "model" or "user",
                parts = {{text = messages[i].content}}
            })
        end
        body = HttpService:JSONEncode({
            contents = contents,
            systemInstruction = {parts = {{text = systemPrompt}}},
            generationConfig = {maxOutputTokens = Config.MaxTokens, temperature = Config.Temperature}
        })
    else
        body = HttpService:JSONEncode({
            model = model,
            messages = messages,
            max_tokens = Config.MaxTokens,
            temperature = Config.Temperature
        })
    end

    local response, err = HttpRequest(endpoint, "POST", headers, body)

    if response and response.Body then
        local success, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
        if success then
            local reply
            if Config.APIProvider == "Claude" then
                if data.content and data.content[1] then reply = data.content[1].text end
            elseif Config.APIProvider == "Gemini" then
                if data.candidates and data.candidates[1] and data.candidates[1].content then
                    reply = data.candidates[1].content.parts[1].text
                end
            else
                if data.choices and data.choices[1] and data.choices[1].message then
                    reply = data.choices[1].message.content
                end
            end

            if reply then
                table.insert(ChatHistory, {role = "user", content = userMessage})
                table.insert(ChatHistory, {role = "assistant", content = reply})
                while #ChatHistory > Config.ContextMemory * 2 do
                    table.remove(ChatHistory, 1)
                end
                return reply
            else
                return nil, "Failed to parse: " .. tostring(data.error and data.error.message or HttpService:JSONEncode(data):sub(1, 100))
            end
        else
            return nil, "JSON decode failed: " .. tostring(data)
        end
    else
        return nil, "HTTP request failed: " .. tostring(err)
    end
end

-- ============ CHAT HANDLING ============
local function ShouldRespond(playerName, message)
    if playerName == LocalPlayer.Name then return false end
    if not Config.Enabled then return false end
    local lowerMsg = string.lower(message)
    local myName = string.lower(LocalPlayer.Name)
    if Config.TriggerMode == "All" then
        return true
    elseif Config.TriggerMode == "Mention" then
        return string.find(lowerMsg, myName) or string.find(lowerMsg, string.lower(LocalPlayer.DisplayName))
    elseif Config.TriggerMode == "Keyword" then
        for _, keyword in ipairs(Config.TriggerKeywords) do
            if string.find(lowerMsg, keyword) then return true end
        end
        return false
    end
    return false
end

local function SendChatMessage(message)
    local success = false
    local TextChatService = game:GetService("TextChatService")
    local channels = TextChatService:FindFirstChild("TextChannels")
    if channels then
        local rbxGeneral = channels:FindFirstChild("RBXGeneral")
        if rbxGeneral then
            pcall(function() rbxGeneral:SendAsync(message); success = true end)
        end
    end
    if not success then
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local chatRemote = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if chatRemote then
            local sayEvent = chatRemote:FindFirstChild("SayMessageRequest")
            if sayEvent then
                pcall(function() sayEvent:FireServer(message, "All"); success = true end)
            end
        end
    end
    if not success then
        pcall(function() game:GetService("Chat"):Chat(LocalPlayer.Character, message) end)
    end
end

local function ProcessChat(playerName, message)
    if ProcessingMessage then return end
    if not ShouldRespond(playerName, message) then return end
    ProcessingMessage = true
    StatusLabel.Text = "Status: ⏳ Processing...\nFrom: " .. playerName .. "\nProvider: " .. Config.APIProvider
    task.spawn(function()
        local delay = Config.ResponseDelay.Min + math.random() * (Config.ResponseDelay.Max - Config.ResponseDelay.Min)
        task.wait(delay)
        local contextMessage = playerName .. " said: " .. message
        local response, err = GenerateResponse(contextMessage)
        if response then
            response = response:gsub("\n", " "):gsub("%s+", " "):sub(1, 200)
            SendChatMessage(response)
            MessagesProcessed = MessagesProcessed + 1
            StatusLabel.Text = "Status: ✅ Responded!\nProvider: " .. Config.APIProvider .. "\nMessages: " .. MessagesProcessed
        else
            StatusLabel.Text = "Status: ❌ Error\n" .. tostring(err):sub(1, 60)
        end
        ProcessingMessage = false
    end)
end

-- ============ CONNECT CHAT LISTENERS ============
local TextChatService = game:GetService("TextChatService")
if TextChatService then
    TextChatService.MessageReceived:Connect(function(textChatMessage)
        if textChatMessage.TextSource then
            local player = Players:GetPlayerByUserId(textChatMessage.TextSource.UserId)
            if player then ProcessChat(player.Name, textChatMessage.Text) end
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(message) ProcessChat(player.Name, message) end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message) ProcessChat(player.Name, message) end)
end)

-- ============ INIT ============
print("═══════════════════════════════════════")
print("🤖 AI Chatbot Multi-Provider (Improved UI) loaded!")
print("Platform: " .. (IsMobile() and "Mobile" or "PC"))
print("═══════════════════════════════════════")

StatusLabel.Text = "Status: Ready\nProvider: " .. Config.APIProvider .. "\nEnter API key in Setup tab"
