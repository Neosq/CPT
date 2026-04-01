local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player       = Players.LocalPlayer

local MAX_HISTORY  = 50
local history      = {}

local function getTimestamp()
    local t = os.date("*t")
    return string.format("%02d.%02d.%02d | %02d:%02d",
        t.month, t.day, t.year % 100, t.hour, t.min)
end

local function getAnchorPos(blocks)
    for _, b in ipairs(blocks) do
        if b and b.Parent then
            local ok, pv = pcall(function() return b:GetPivot() end)
            if ok and pv then return pv.Position end
        end
    end
    return nil
end

local W = {}

-- Register a paste into history
function W.register(blocks)
    if not blocks or #blocks == 0 then return end
    local name = "Build_"..#history+1
    table.insert(history, {
        name   = name,
        time   = getTimestamp(),
        blocks = blocks,
    })
    -- Keep max history
    if #history > MAX_HISTORY then table.remove(history, 1) end
end

-- GUI
local guiOpen = false
local undoGui = nil

local function uiCorner(p, r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p
end
local function mkStroke(p, col, th)
    local s=Instance.new("UIStroke"); s.Color=col or Color3.fromRGB(55,40,90)
    s.Thickness=th or 1.5; s.Parent=p; return s
end

local function closeGui()
    if undoGui and undoGui.Parent then undoGui:Destroy() end
    undoGui=nil; guiOpen=false
end

local function openGui()
    if guiOpen then closeGui(); return end
    guiOpen=true

    undoGui = Instance.new("ScreenGui")
    undoGui.Name="CPTUndo"; undoGui.ResetOnSpawn=false
    undoGui.DisplayOrder=80; undoGui.Parent=player.PlayerGui

    -- Backdrop
    local bg = Instance.new("Frame")
    bg.Size=UDim2.new(0,340,0,420)
    bg.AnchorPoint=Vector2.new(0.5,0.5)
    bg.Position=UDim2.new(0.5,0,0.5,0)
    bg.BackgroundColor3=Color3.fromRGB(14,9,26)
    bg.BackgroundTransparency=0.05
    bg.BorderSizePixel=0; bg.ZIndex=10; bg.Parent=undoGui
    uiCorner(bg,14); mkStroke(bg,Color3.fromRGB(80,50,130),1.5)

    -- Title
    local title=Instance.new("TextLabel")
    title.Size=UDim2.new(1,-40,0,36)
    title.Position=UDim2.new(0,12,0,8)
    title.BackgroundTransparency=1
    title.Text="Undo History"
    title.TextColor3=Color3.fromRGB(210,180,255)
    title.Font=Enum.Font.GothamBold; title.TextSize=18
    title.TextXAlignment=Enum.TextXAlignment.Left
    title.ZIndex=11; title.Parent=bg

    -- Close btn
    local closeBtn=Instance.new("TextButton")
    closeBtn.Size=UDim2.new(0,28,0,28)
    closeBtn.AnchorPoint=Vector2.new(1,0)
    closeBtn.Position=UDim2.new(1,-8,0,8)
    closeBtn.BackgroundColor3=Color3.fromRGB(120,40,60)
    closeBtn.Text="X"; closeBtn.TextColor3=Color3.fromRGB(255,200,210)
    closeBtn.Font=Enum.Font.GothamBold; closeBtn.TextSize=13
    closeBtn.BorderSizePixel=0; closeBtn.ZIndex=12; closeBtn.Parent=bg
    uiCorner(closeBtn,6)
    closeBtn.MouseButton1Click:Connect(closeGui)

    -- Divider
    local div=Instance.new("Frame")
    div.Size=UDim2.new(1,-20,0,1); div.Position=UDim2.new(0,10,0,50)
    div.BackgroundColor3=Color3.fromRGB(70,45,110); div.BorderSizePixel=0
    div.ZIndex=11; div.Parent=bg

    -- Scroll frame
    local scroll=Instance.new("ScrollingFrame")
    scroll.Size=UDim2.new(1,-16,1,-62)
    scroll.Position=UDim2.new(0,8,0,56)
    scroll.BackgroundTransparency=1
    scroll.BorderSizePixel=0
    scroll.ScrollBarThickness=4
    scroll.ScrollBarImageColor3=Color3.fromRGB(120,80,200)
    scroll.CanvasSize=UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
    scroll.ZIndex=11; scroll.Parent=bg

    local listLayout=Instance.new("UIListLayout")
    listLayout.FillDirection=Enum.FillDirection.Vertical
    listLayout.Padding=UDim.new(0,6)
    listLayout.Parent=scroll
    local pad=Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4)
    pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4)
    pad.Parent=scroll

    if #history == 0 then
        local empty=Instance.new("TextLabel")
        empty.Size=UDim2.new(1,0,0,40)
        empty.BackgroundTransparency=1
        empty.Text="No history yet"
        empty.TextColor3=Color3.fromRGB(140,120,170)
        empty.Font=Enum.Font.Gotham; empty.TextSize=14
        empty.ZIndex=12; empty.Parent=scroll
        return
    end

    -- List entries (newest first)
    for i = #history, 1, -1 do
        local entry = history[i]

        local row=Instance.new("Frame")
        row.Size=UDim2.new(1,0,0,54)
        row.BackgroundColor3=Color3.fromRGB(28,18,50)
        row.BackgroundTransparency=0.1
        row.BorderSizePixel=0; row.ZIndex=12; row.Parent=scroll
        uiCorner(row,8); mkStroke(row,Color3.fromRGB(55,35,88),1)

        -- Name
        local nameLabel=Instance.new("TextLabel")
        nameLabel.Size=UDim2.new(1,-160,0,24)
        nameLabel.Position=UDim2.new(0,10,0,4)
        nameLabel.BackgroundTransparency=1
        nameLabel.Text=entry.name
        nameLabel.TextColor3=Color3.fromRGB(220,200,255)
        nameLabel.Font=Enum.Font.GothamBold; nameLabel.TextSize=14
        nameLabel.TextXAlignment=Enum.TextXAlignment.Left
        nameLabel.ZIndex=13; nameLabel.Parent=row

        -- Block count
        local countLabel=Instance.new("TextLabel")
        countLabel.Size=UDim2.new(1,-160,0,18)
        countLabel.Position=UDim2.new(0,10,0,28)
        countLabel.BackgroundTransparency=1
        countLabel.Text=entry.time.." | "..#entry.blocks.." blks"
        countLabel.TextColor3=Color3.fromRGB(150,130,190)
        countLabel.Font=Enum.Font.Gotham; countLabel.TextSize=12
        countLabel.TextXAlignment=Enum.TextXAlignment.Left
        countLabel.ZIndex=13; countLabel.Parent=row

        local function mkActionBtn(text, color, xOffset)
            local b=Instance.new("TextButton")
            b.Size=UDim2.new(0,68,0,34)
            b.AnchorPoint=Vector2.new(1,0.5)
            b.Position=UDim2.new(1,xOffset,0.5,0)
            b.BackgroundColor3=color
            b.BorderSizePixel=0
            b.Text=text; b.TextColor3=Color3.fromRGB(255,255,255)
            b.Font=Enum.Font.GothamBold; b.TextSize=13
            b.ZIndex=13; b.Parent=row
            uiCorner(b,7); return b
        end

        local undoBtn = mkActionBtn("Undo", Color3.fromRGB(180,50,70), -8)
        local tpBtn   = mkActionBtn("TP",   Color3.fromRGB(50,130,180), -82)

        local capturedEntry = entry
        local capturedIdx   = i

        tpBtn.MouseButton1Click:Connect(function()
            local pos = getAnchorPos(capturedEntry.blocks)
            if pos then
                local char = player.Character
                local hrp  = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = CFrame.new(pos + Vector3.new(0,5,0)) end
            end
        end)

        undoBtn.MouseButton1Click:Connect(function()
            -- Destroy all blocks in this entry
            local destroyed = 0
            for _, b in ipairs(capturedEntry.blocks) do
                if b and b.Parent then
                    pcall(function() RS.Functions.DestroyBlock:InvokeServer(b) end)
                    destroyed = destroyed + 1
                end
            end
            -- Remove from history
            table.remove(history, capturedIdx)
            -- Refresh GUI
            closeGui(); openGui()
        end)
    end
end

-- Export
_G.CPT_Undo = {
    register = W.register,
    openGui  = openGui,
    closeGui = closeGui,
}
