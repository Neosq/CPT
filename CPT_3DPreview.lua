local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player       = Players.LocalPlayer
local camera       = workspace.CurrentCamera
local U = _G.CPT_Utils
local S = _G.CPT_State
local P = _G.CPT_Preview

if not U or not S or not P then
    warn("[CPT_3DPreview] Missing modules: U="..tostring(U).." S="..tostring(S).." P="..tostring(P))
    _G.CPT_3DPreview = {}
    return
end

-- Aliases for Utils functions
local tableToCF     = function(...) return U.tableToCF(...) end
local cfToTable     = function(...) return U.cfToTable(...) end
local findBlockInRS = function(...) return U.findBlockInRS(...) end
local getModelPivot = function(...) return U.getModelPivot(...) end
local loadBuilds    = function(...) return U.loadBuilds(...) end
local saveBuilds    = function(...) return U.saveBuilds(...) end
local activatePaste = function(...) return P.activatePaste(...) end
local excludedBlocks = nil  -- use S.excludedBlocks directly

local V = {}

local function mkCorner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 8); c.Parent = p
end
local function mkStroke(p, col, th)
    local s = Instance.new("UIStroke"); s.Color = col or Color3.fromRGB(55,55,75); s.Thickness = th or 1; s.Parent = p
end

local previewGui    = nil
local vpCamera      = nil
local vpWorld       = nil
local vpParts       = {}
local vpDragging    = false
local vpLastInput   = nil
local vpRotX        = 0
local vpRotY        = 0
local VP_DIST       = 25
local function destroyPreviewGui()
    if previewGui and previewGui.Parent then previewGui:Destroy() end
    previewGui=nil; vpCamera=nil; vpWorld=nil; vpParts={}
end
local function buildVPParts(build, isTransparent)
    if not vpWorld then return end
    for _, p in pairs(vpParts) do if p and p.Parent then p:Destroy() end end
    vpParts = {}
    if not build or not build.blocks or not build.anchor then return end
    local anchorCF = tableToCF(build.anchor)
    local tr = isTransparent and 0.5 or 0
    for _, data in ipairs(build.blocks) do
        local relCF = tableToCF(data.relCF)
        local tCF   = anchorCF * relCF
        local ok, bc   = pcall(function() return BrickColor.new(data.brickColor) end)
        local ok2, mat = pcall(function() return Enum.Material[data.material] end)
        local brickColor = ok  and bc  or BrickColor.new(1001)
        local material   = ok2 and mat or Enum.Material.Plastic
        local rsModel = findBlockInRS(data.name)
        local placed  = false
        if rsModel then
            local modelCF = getModelPivot(rsModel)
            if modelCF then
                for _, desc in ipairs(rsModel:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                        if desc.Transparency >= 1 then continue end
                        local ghost = desc:Clone()
                        for _, child in ipairs(ghost:GetChildren()) do
                            if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                or child:IsA("Decal") or child:IsA("Texture")) then
                                child:Destroy()
                            end
                        end
                        ghost.Anchored = true; ghost.CanCollide = false
                        ghost.CastShadow = false; ghost.Transparency = tr
                        if desc.Name == "ColorPart" then
                            ghost.BrickColor = brickColor
                            ghost.Material   = material
                            if data.isResized then
                                ghost.Size = Vector3.new(table.unpack(data.cpSize))
                            end
                        end
                        local relPart = modelCF:ToObjectSpace(desc.CFrame)
                        ghost.CFrame  = tCF * relPart
                        ghost.Name    = "VPGhost"
                        ghost.Parent  = vpWorld
                        table.insert(vpParts, ghost)
                        placed = true
                    end
                end
            end
        end
        if not placed then
            local sz = Vector3.new(table.unpack(data.cpSize))
            local p  = Instance.new("Part")
            p.Size = sz; p.CFrame = tCF; p.Anchored = true
            p.CanCollide = false; p.CastShadow = false; p.Transparency = tr
            p.BrickColor = brickColor; p.Material = material
            p.Name = "VPGhost"; p.Parent = vpWorld
            table.insert(vpParts, p)
        end
    end
    local s = Vector3.new(0, 0, 0)
    for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
    local center = s / math.max(#vpParts, 1)
    if vpCamera then
        vpCamera.CFrame = CFrame.new(center + Vector3.new(0, 0, VP_DIST), center)
    end
end
local function openPreviewGui(buildArg)
    destroyPreviewGui()
    if not buildArg then return end
    local build = buildArg
    previewGui = Instance.new("ScreenGui")
    previewGui.Name = "CPPreviewGui"
    previewGui.ResetOnSpawn = false
    previewGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    previewGui.IgnoreGuiInset = true
    previewGui.AutoLocalize = false
    previewGui.Parent = player.PlayerGui
    local W = 300
    local H = 300
    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.new(0, W, 0, H)
    bg.AnchorPoint = Vector2.new(0.5, 0.5)
    bg.Position = UDim2.new(0.5, 0, 0.5, 0)
    bg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    bg.BorderSizePixel = 0
    bg.ZIndex = 2
    bg.Parent = previewGui
    mkCorner(bg, 12)
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = Color3.fromRGB(55, 55, 75)
    bgStroke.Thickness = 1
    bgStroke.Parent = bg
    local SIDE_W = 150
    local sideOpen = false
    local sidePanel = Instance.new("Frame")
    sidePanel.Name = "SidePanel"
    sidePanel.Size = UDim2.new(0, SIDE_W, 0, H)
    sidePanel.AnchorPoint = Vector2.new(0, 0.5)
    sidePanel.Position = UDim2.new(0.5, W / 2 + 8, 0.5, 0)
    sidePanel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    sidePanel.BorderSizePixel = 0
    sidePanel.ZIndex = 2
    sidePanel.Visible = false
    sidePanel.Parent = previewGui
    mkCorner(sidePanel, 10)
    local sideStroke = Instance.new("UIStroke")
    sideStroke.Color = Color3.fromRGB(55, 55, 75)
    sideStroke.Thickness = 1
    sideStroke.Parent = sidePanel
    local sideTitleLbl = Instance.new("TextLabel")
    sideTitleLbl.Size = UDim2.new(1, 0, 0, 22)
    sideTitleLbl.Position = UDim2.new(0, 0, 0, 4)
    sideTitleLbl.BackgroundTransparency = 1
    sideTitleLbl.Text = "Categories"
    sideTitleLbl.TextColor3 = Color3.fromRGB(175, 165, 220)
    sideTitleLbl.Font = Enum.Font.GothamBold
    sideTitleLbl.TextSize = 11
    sideTitleLbl.ZIndex = 3
    sideTitleLbl.Parent = sidePanel
    local sideScroll = Instance.new("ScrollingFrame")
    sideScroll.Size = UDim2.new(1, -8, 1, -30)
    sideScroll.Position = UDim2.new(0, 4, 0, 28)
    sideScroll.BackgroundTransparency = 1
    sideScroll.BorderSizePixel = 0
    sideScroll.ScrollBarThickness = 3
    sideScroll.ZIndex = 3
    sideScroll.Parent = sidePanel
    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 2)
    sideLayout.Parent = sideScroll
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.ZIndex = 3
    header.Parent = bg
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = build.name
    titleLbl.TextColor3 = Color3.fromRGB(220, 215, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.ZIndex = 4
    titleLbl.Parent = header
    local catBtn = Instance.new("TextButton")
    catBtn.Size = UDim2.new(0, 28, 0, 20)
    catBtn.AnchorPoint = Vector2.new(0, 0.5)
    catBtn.Position = UDim2.new(1, -62, 0.5, 0)
    catBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 70)
    catBtn.BorderSizePixel = 0
    catBtn.Text = "Cat >"
    catBtn.TextColor3 = Color3.fromRGB(175, 165, 218)
    catBtn.Font = Enum.Font.Gotham
    catBtn.TextSize = 9
    catBtn.ZIndex = 4
    catBtn.Parent = header
    mkCorner(catBtn, 4)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 20)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.Position = UDim2.new(1, -30, 0.5, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(78, 24, 24)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.ZIndex = 4
    closeBtn.Parent = header
    mkCorner(closeBtn, 4)
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, -16, 0, 1)
    sep1.Position = UDim2.new(0, 8, 0, 36)
    sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep1.BorderSizePixel = 0
    sep1.ZIndex = 3
    sep1.Parent = bg
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1, -16, 0, 160)
    vp.Position = UDim2.new(0, 8, 0, 42)
    vp.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
    vp.BorderSizePixel = 0
    vp.ZIndex = 3
    vp.Parent = bg
    mkCorner(vp, 8)
    vpCamera = Instance.new("Camera")
    vpCamera.Parent = vp
    vp.CurrentCamera = vpCamera
    vpWorld = Instance.new("WorldModel")
    vpWorld.Parent = vp
    local lp = Instance.new("Part")
    lp.Anchored = true; lp.CanCollide = false; lp.Transparency = 1
    lp.Size = Vector3.new(1, 1, 1); lp.CFrame = CFrame.new(0, 50, 0)
    local li = Instance.new("PointLight"); li.Range = 200; li.Brightness = 2; li.Parent = lp
    lp.Parent = vpWorld
    local vpTransparent = false
    buildVPParts(build, vpTransparent)
    local ctrlRow = Instance.new("Frame")
    ctrlRow.Size = UDim2.new(1, -16, 0, 22)
    ctrlRow.Position = UDim2.new(0, 8, 0, 207)
    ctrlRow.BackgroundTransparency = 1
    ctrlRow.ZIndex = 3
    ctrlRow.Parent = bg
    local transpBtn = Instance.new("TextButton")
    transpBtn.Size = UDim2.new(0, 55, 1, 0)
    transpBtn.BackgroundColor3 = Color3.fromRGB(36, 34, 56)
    transpBtn.BorderSizePixel = 0
    transpBtn.Text = "Solid"
    transpBtn.TextColor3 = Color3.fromRGB(185, 178, 225)
    transpBtn.Font = Enum.Font.Gotham
    transpBtn.TextSize = 9
    transpBtn.ZIndex = 4
    transpBtn.Parent = ctrlRow
    mkCorner(transpBtn, 4)
    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(0, 55, 1, 0)
    countLbl.Position = UDim2.new(0, 59, 0, 0)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = #build.blocks .. " blks"
    countLbl.TextColor3 = Color3.fromRGB(105, 100, 135)
    countLbl.Font = Enum.Font.Gotham
    countLbl.TextSize = 9
    countLbl.ZIndex = 4
    countLbl.Parent = ctrlRow
    local otherBtn = Instance.new("TextButton")
    otherBtn.Size = UDim2.new(1, -118, 1, 0)
    otherBtn.Position = UDim2.new(0, 118, 0, 0)
    otherBtn.BackgroundColor3 = Color3.fromRGB(36, 34, 56)
    otherBtn.BorderSizePixel = 0
    otherBtn.Text = "Other builds v"
    otherBtn.TextColor3 = Color3.fromRGB(160, 152, 205)
    otherBtn.Font = Enum.Font.Gotham
    otherBtn.TextSize = 9
    otherBtn.ZIndex = 4
    otherBtn.Parent = ctrlRow
    mkCorner(otherBtn, 4)
    local otherPopup = Instance.new("Frame")
    otherPopup.Size = UDim2.new(1, -16, 0, 0)
    otherPopup.Position = UDim2.new(0, 8, 0, 232)
    otherPopup.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
    otherPopup.BorderSizePixel = 0
    otherPopup.ZIndex = 5
    otherPopup.Visible = false
    otherPopup.ClipsDescendants = true
    otherPopup.Parent = bg
    mkCorner(otherPopup, 6)
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = Color3.fromRGB(50, 50, 70); popupStroke.Thickness = 1; popupStroke.Parent = otherPopup
    local popupScroll = Instance.new("ScrollingFrame")
    popupScroll.Size = UDim2.new(1, 0, 1, 0)
    popupScroll.BackgroundTransparency = 1; popupScroll.BorderSizePixel = 0
    popupScroll.ScrollBarThickness = 3; popupScroll.ZIndex = 6; popupScroll.Parent = otherPopup
    local popupLayout = Instance.new("UIListLayout")
    popupLayout.Padding = UDim.new(0, 2); popupLayout.Parent = popupScroll
    local popupPad = Instance.new("UIPadding")
    popupPad.PaddingTop = UDim.new(0, 3); popupPad.PaddingLeft = UDim.new(0, 4)
    popupPad.PaddingRight = UDim.new(0, 4); popupPad.Parent = popupScroll
    local otherOpen = false
    local blockChecked = {}
    local function rebuildVP()
        if not vpWorld then return end
        for _, p in pairs(vpParts) do if p and p.Parent then p:Destroy() end end
        vpParts = {}
        if not build.anchor then return end
        local anchorCF = tableToCF(build.anchor)
        local tr = vpTransparent and 0.5 or 0
        for _, data in ipairs(build.blocks) do
            if not blockChecked[data.name] then
                local relCF = tableToCF(data.relCF)
                local tCF   = anchorCF * relCF
                local ok, bc   = pcall(function() return BrickColor.new(data.brickColor) end)
                local ok2, mat = pcall(function() return Enum.Material[data.material] end)
                local brickColor = ok  and bc  or BrickColor.new(1001)
                local material   = ok2 and mat or Enum.Material.Plastic
                local rsModel = findBlockInRS(data.name)
                local placed  = false
                if rsModel then
                    local modelCF = getModelPivot(rsModel)
                    if modelCF then
                        for _, desc in ipairs(rsModel:GetDescendants()) do
                            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                                if desc.Transparency >= 1 then continue end
                                local ghost = desc:Clone()
                                for _, child in ipairs(ghost:GetChildren()) do
                                    if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                        or child:IsA("Decal") or child:IsA("Texture")) then
                                        child:Destroy()
                                    end
                                end
                                ghost.Anchored = true; ghost.CanCollide = false
                                ghost.CastShadow = false; ghost.Transparency = tr
                                if desc.Name == "ColorPart" then
                                    ghost.BrickColor = brickColor
                                    ghost.Material   = material
                                    if data.isResized then
                                        ghost.Size = Vector3.new(table.unpack(data.cpSize))
                                    end
                                end
                                local relPart = modelCF:ToObjectSpace(desc.CFrame)
                                ghost.CFrame  = tCF * relPart
                                ghost.Name    = "VPGhost"
                                ghost.Parent  = vpWorld
                                table.insert(vpParts, ghost)
                                placed = true
                            end
                        end
                    end
                end
                if not placed then
                    local sz = Vector3.new(table.unpack(data.cpSize))
                    local p  = Instance.new("Part")
                    p.Size = sz; p.CFrame = tCF; p.Anchored = true
                    p.CanCollide = false; p.CastShadow = false; p.Transparency = tr
                    p.BrickColor = brickColor; p.Material = material
                    p.Name = "VPGhost"; p.Parent = vpWorld
                    table.insert(vpParts, p)
                end
            end
        end
        local s = Vector3.new(0, 0, 0)
        for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
        local center = s / math.max(#vpParts, 1)
        if vpCamera then
            local rot = CFrame.Angles(math.rad(vpRotX), math.rad(vpRotY), 0)
            vpCamera.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, VP_DIST)
        end
    end
    local function loadBuild(b)
        build = b
        titleLbl.Text = build.name
        countLbl.Text = #build.blocks .. " blks"
        blockChecked = {}
        vpTransparent = false; transpBtn.Text = "Solid"
        buildVPParts(build, false)
        populateSide()
    end
    local function populateOther()
        for _, c in pairs(popupScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local allBuilds = loadBuilds()
        local count = 0
        for _, b in ipairs(allBuilds) do
            if b.name ~= build.name then
                count = count + 1
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 22)
                btn.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
                btn.BorderSizePixel = 0
                btn.Text = b.name .. " (" .. #b.blocks .. ")"
                btn.TextColor3 = Color3.fromRGB(155, 148, 192)
                btn.Font = Enum.Font.Gotham; btn.TextSize = 9
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.ZIndex = 6; btn.Parent = popupScroll; mkCorner(btn, 3)
                local pp = Instance.new("UIPadding"); pp.PaddingLeft = UDim.new(0, 6); pp.Parent = btn
                local cap = b
                btn.MouseButton1Click:Connect(function()
                    otherOpen = false
                    TweenService:Create(otherPopup, TweenInfo.new(0.1), {Size=UDim2.new(1,-16,0,0)}):Play()
                    task.delay(0.1, function() otherPopup.Visible = false end)
                    otherBtn.Text = "Other builds v"
                    loadBuild(cap)
                end)
            end
        end
        popupScroll.CanvasSize = UDim2.new(0, 0, 0, popupLayout.AbsoluteContentSize.Y + 6)
        return count
    end
    otherBtn.MouseButton1Click:Connect(function()
        otherOpen = not otherOpen
        if otherOpen then
            local cnt = populateOther()
            if cnt == 0 then otherOpen = false; return end
            otherPopup.Visible = true
            local h = math.min(cnt * 24 + 8, 88)
            TweenService:Create(otherPopup, TweenInfo.new(0.15), {Size=UDim2.new(1,-16,0,h)}):Play()
            otherBtn.Text = "Other builds ^"
        else
            TweenService:Create(otherPopup, TweenInfo.new(0.1), {Size=UDim2.new(1,-16,0,0)}):Play()
            task.delay(0.1, function() otherPopup.Visible = false end)
            otherBtn.Text = "Other builds v"
        end
    end)
    transpBtn.MouseButton1Click:Connect(function()
        vpTransparent = not vpTransparent
        transpBtn.Text = vpTransparent and "Ghost" or "Solid"
        rebuildVP()
    end)
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, -16, 0, 1)
    sep2.Position = UDim2.new(0, 8, 0, 233)
    sep2.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep2.BorderSizePixel = 0; sep2.ZIndex = 3; sep2.Parent = bg
    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(0.5, -12, 0, 30)
    loadBtn.Position = UDim2.new(0, 8, 0, 240)
    loadBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 85)
    loadBtn.BorderSizePixel = 0
    loadBtn.Text = "Load"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.Font = Enum.Font.GothamBold; loadBtn.TextSize = 12
    loadBtn.ZIndex = 3; loadBtn.Parent = bg; mkCorner(loadBtn, 7)
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.5, -12, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 4, 0, 240)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(95, 26, 26)
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.Font = Enum.Font.GothamBold; cancelBtn.TextSize = 12
    cancelBtn.ZIndex = 3; cancelBtn.Parent = bg; mkCorner(cancelBtn, 7)
    function populateSide()
        for _, c in pairs(sideScroll:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
        end
        local catMap = {}
        for _, data in ipairs(build.blocks) do
            local cat = data.category or "Unknown"
            if not catMap[cat] then catMap[cat] = {} end
            local found = false
            for _, n in pairs(catMap[cat]) do if n == data.name then found = true; break end end
            if not found then table.insert(catMap[cat], data.name) end
        end
        local catOrder = {}
        for cat, _ in pairs(catMap) do table.insert(catOrder, cat) end
        table.sort(catOrder)
        local idx = 0
        for _, cat in ipairs(catOrder) do
            idx = idx + 1
            local catRow = Instance.new("Frame")
            catRow.Size = UDim2.new(1, 0, 0, 22)
            catRow.BackgroundColor3 = Color3.fromRGB(36, 32, 56)
            catRow.BorderSizePixel = 0; catRow.ZIndex = 4
            catRow.LayoutOrder = idx; catRow.Parent = sideScroll; mkCorner(catRow, 4)
            local catLbl = Instance.new("TextButton")
            catLbl.Size = UDim2.new(1, 0, 1, 0); catLbl.BackgroundTransparency = 1
            catLbl.Text = "+ " .. cat
            catLbl.TextColor3 = Color3.fromRGB(160, 152, 204)
            catLbl.Font = Enum.Font.GothamBold; catLbl.TextSize = 9
            catLbl.TextXAlignment = Enum.TextXAlignment.Left
            catLbl.ZIndex = 5; catLbl.Parent = catRow
            local catPad = Instance.new("UIPadding"); catPad.PaddingLeft = UDim.new(0, 6); catPad.Parent = catLbl
            local blockFrames = {}; local catOpen = false
            local names = catMap[cat]; table.sort(names)
            for _, blockName in ipairs(names) do
                idx = idx + 1
                local bRow = Instance.new("Frame")
                bRow.Size = UDim2.new(1, 0, 0, 18)
                bRow.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
                bRow.BorderSizePixel = 0; bRow.ZIndex = 4
                bRow.LayoutOrder = idx; bRow.Visible = false
                bRow.Parent = sideScroll; mkCorner(bRow, 3)
                local cb = Instance.new("TextButton")
                cb.Size = UDim2.new(0, 12, 0, 12); cb.AnchorPoint = Vector2.new(0, 0.5)
                cb.Position = UDim2.new(0, 5, 0.5, 0)
                cb.BackgroundColor3 = Color3.fromRGB(42, 158, 80)
                cb.BorderSizePixel = 0; cb.Text = "V"
                cb.TextColor3 = Color3.fromRGB(255, 255, 255)
                cb.Font = Enum.Font.GothamBold; cb.TextSize = 7
                cb.ZIndex = 5; cb.Parent = bRow; mkCorner(cb, 3)
                local bLbl = Instance.new("TextLabel")
                bLbl.Size = UDim2.new(1, -22, 1, 0); bLbl.Position = UDim2.new(0, 20, 0, 0)
                bLbl.BackgroundTransparency = 1; bLbl.Text = blockName
                bLbl.TextColor3 = Color3.fromRGB(130, 124, 165)
                bLbl.Font = Enum.Font.Gotham; bLbl.TextSize = 8
                bLbl.TextXAlignment = Enum.TextXAlignment.Left
                bLbl.TextTruncate = Enum.TextTruncate.AtEnd
                bLbl.ZIndex = 5; bLbl.Parent = bRow
                local n = blockName
                cb.MouseButton1Click:Connect(function()
                    if blockChecked[n] then
                        blockChecked[n] = nil
                        cb.BackgroundColor3 = Color3.fromRGB(42, 158, 80); cb.Text = "V"
                    else
                        blockChecked[n] = true
                        cb.BackgroundColor3 = Color3.fromRGB(85, 24, 24); cb.Text = "X"
                    end
                    rebuildVP()
                end)
                table.insert(blockFrames, bRow)
            end
            catLbl.MouseButton1Click:Connect(function()
                catOpen = not catOpen
                catLbl.Text = (catOpen and "- " or "+ ") .. cat
                for _, bf in pairs(blockFrames) do bf.Visible = catOpen end
                sideScroll.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 6)
            end)
        end
        sideScroll.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 6)
    end
    populateSide()
    catBtn.MouseButton1Click:Connect(function()
        sideOpen = not sideOpen
        sidePanel.Visible = sideOpen
        catBtn.Text = sideOpen and "Cat <" or "Cat >"
    end)
    local zoomRow = Instance.new("Frame")
    zoomRow.Size = UDim2.new(0, 52, 0, 22)
    zoomRow.Position = UDim2.new(1, -60, 0, 42)
    zoomRow.BackgroundTransparency = 1
    zoomRow.ZIndex = 4
    zoomRow.Parent = bg
    local zoomInBtn = Instance.new("TextButton")
    zoomInBtn.Size = UDim2.new(0, 24, 1, 0)
    zoomInBtn.BackgroundColor3 = Color3.fromRGB(38, 36, 58)
    zoomInBtn.BorderSizePixel = 0
    zoomInBtn.Text = "+"
    zoomInBtn.TextColor3 = Color3.fromRGB(200, 195, 240)
    zoomInBtn.Font = Enum.Font.GothamBold
    zoomInBtn.TextSize = 13
    zoomInBtn.ZIndex = 5
    zoomInBtn.Parent = zoomRow
    mkCorner(zoomInBtn, 4)
    local zoomOutBtn = Instance.new("TextButton")
    zoomOutBtn.Size = UDim2.new(0, 24, 1, 0)
    zoomOutBtn.Position = UDim2.new(0, 28, 0, 0)
    zoomOutBtn.BackgroundColor3 = Color3.fromRGB(38, 36, 58)
    zoomOutBtn.BorderSizePixel = 0
    zoomOutBtn.Text = "-"
    zoomOutBtn.TextColor3 = Color3.fromRGB(200, 195, 240)
    zoomOutBtn.Font = Enum.Font.GothamBold
    zoomOutBtn.TextSize = 13
    zoomOutBtn.ZIndex = 5
    zoomOutBtn.Parent = zoomRow
    mkCorner(zoomOutBtn, 4)
    local vpDist = VP_DIST
    local function updateVPCamera()
        local s = Vector3.new(0, 0, 0)
        for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
        local center = s / math.max(#vpParts, 1)
        if vpCamera then
            local rot = CFrame.Angles(math.rad(vpRotX), math.rad(vpRotY), 0)
            vpCamera.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, vpDist)
        end
    end
    zoomInBtn.MouseButton1Click:Connect(function()
        vpDist = math.max(vpDist - 3, 3)
        updateVPCamera()
    end)
    zoomOutBtn.MouseButton1Click:Connect(function()
        vpDist = math.min(vpDist + 3, 120)
        updateVPCamera()
    end)
    local savedCameraType = camera.CameraType
    camera.CameraType = Enum.CameraType.Scriptable
    local Players2 = game:GetService("Players")
    local char = Players2.LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = 0; humanoid.JumpPower = 0 end
    local vpTouchId   = nil
    local vpDragStart = nil
    local hdrTouchId  = nil
    local hdrDragStart = nil
    local hdrPosStart  = nil
    local dragConn    = nil
    local guiTouches = {}
    local blockConn = UIS.InputBegan:Connect(function(input, gpe)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        local bgPos = bg.AbsolutePosition
        local bgSz  = bg.AbsoluteSize
        local inBg  = pos.X >= bgPos.X and pos.X <= bgPos.X + bgSz.X
                   and pos.Y >= bgPos.Y and pos.Y <= bgPos.Y + bgSz.Y
        local inSide = false
        if sidePanel.Visible then
            local sp = sidePanel.AbsolutePosition
            local ss = sidePanel.AbsoluteSize
            inSide = pos.X >= sp.X and pos.X <= sp.X + ss.X
                  and pos.Y >= sp.Y and pos.Y <= sp.Y + ss.Y
        end
        if inBg or inSide then
            guiTouches[input] = true
        end
    end)
    local blockEndConn = UIS.InputEnded:Connect(function(input)
        guiTouches[input] = nil
    end)
    vp.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if vpTouchId ~= nil then return end
        vpTouchId   = input
        vpDragStart = Vector2.new(input.Position.X, input.Position.Y)
    end)
    vp.InputEnded:Connect(function(input)
        if input == vpTouchId then vpTouchId = nil; vpDragStart = nil end
    end)
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if vpTouchId ~= nil then return end
        if hdrTouchId ~= nil then return end
        hdrTouchId   = input
        hdrDragStart = Vector2.new(input.Position.X, input.Position.Y)
        hdrPosStart  = bg.Position
    end)
    header.InputEnded:Connect(function(input)
        if input == hdrTouchId then
            hdrTouchId = nil; hdrDragStart = nil; hdrPosStart = nil
        end
    end)
    dragConn = UIS.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if input == vpTouchId and vpDragStart then
            local cur = Vector2.new(input.Position.X, input.Position.Y)
            local delta = cur - vpDragStart; vpDragStart = cur
            vpRotY = vpRotY + delta.X * 0.5
            vpRotX = vpRotX + delta.Y * 0.5
            updateVPCamera()
        elseif input == hdrTouchId and hdrDragStart and hdrPosStart then
            local d = Vector2.new(input.Position.X, input.Position.Y) - hdrDragStart
            bg.Position = UDim2.new(
                hdrPosStart.X.Scale, hdrPosStart.X.Offset + d.X,
                hdrPosStart.Y.Scale, hdrPosStart.Y.Offset + d.Y
            )
            local bgAbs = bg.AbsolutePosition
            local bgW   = bg.AbsoluteSize.X
            sidePanel.Position = UDim2.new(0, bgAbs.X + bgW + 8, 0, bgAbs.Y)
            sidePanel.AnchorPoint = Vector2.new(0, 0)
        end
    end)
    local function cleanupAndClose()
        camera.CameraType = savedCameraType
        if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
        if dragConn    then dragConn:Disconnect();    dragConn    = nil end
        if blockConn   then blockConn:Disconnect();   blockConn   = nil end
        if blockEndConn then blockEndConn:Disconnect(); blockEndConn = nil end
        vpTouchId = nil; hdrTouchId = nil; guiTouches = {}
        destroyPreviewGui()
    end
    closeBtn.MouseButton1Click:Connect(cleanupAndClose)
    loadBtn.MouseButton1Click:Connect(function()
        if not build.anchor then return end
        S.excludedBlocks = {}
        for name, _ in pairs(blockChecked) do S.excludedBlocks[name] = true end
        activatePaste(build.blocks, tableToCF(build.anchor), true)
        cleanupAndClose()
    end)
    cancelBtn.MouseButton1Click:Connect(cleanupAndClose)
end

V.openPreviewGui = openPreviewGui
_G.CPT_3DPreview = V
