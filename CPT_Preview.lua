local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local camera     = workspace.CurrentCamera
local U = _G.CPT_Utils
local S = _G.CPT_State

local PURPLE    = Color3.fromRGB(140, 90, 220)
local AXES = {
    {axis="X", dir=Vector3.new( 1,0,0)},
    {axis="X", dir=Vector3.new(-1,0,0)},
    {axis="Y", dir=Vector3.new( 0,1,0)},
    {axis="Y", dir=Vector3.new( 0,-1,0)},
    {axis="Z", dir=Vector3.new( 0,0, 1)},
    {axis="Z", dir=Vector3.new( 0,0,-1)},
}
local RING_DEFS = {
    {id="X",color=Color3.fromRGB(210,50,50), rotAxis=Vector3.new(1,0,0),ringU=Vector3.new(0,1,0),ringV=Vector3.new(0,0,1),dot1=Vector3.new(0,0,1), dot2=Vector3.new(0,0,-1)},
    {id="Y",color=Color3.fromRGB(50,210,60), rotAxis=Vector3.new(0,1,0),ringU=Vector3.new(1,0,0),ringV=Vector3.new(0,0,1),dot1=Vector3.new(1,0,0), dot2=Vector3.new(-1,0,0)},
    {id="Z",color=Color3.fromRGB(60,110,230),rotAxis=Vector3.new(0,0,1),ringU=Vector3.new(1,0,0),ringV=Vector3.new(0,1,0),dot1=Vector3.new(0,1,0), dot2=Vector3.new(0,-1,0)},
}
local RING_SEGS  = 48
local RING_THICK = 3
local DOT_SIZE   = 22

local screenGui = Instance.new("ScreenGui")
screenGui.Name="CopyPasteTool"; screenGui.ResetOnSpawn=false
screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset=true; screenGui.AutoLocalize=false
screenGui.Parent=player.PlayerGui

local function mkCorner(p,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p end

local P = {}

local function clearPreview()
    for _,p in pairs(S.previewParts) do
        if typeof(p)=="Instance" and p.Parent then p:Destroy() end
    end
    S.previewParts={}
end

local function buildPreview()
    clearPreview()
    if not S.activeBlocks or not S.activeAnchorCF then return end
    local nA = CFrame.new(S.activeAnchorCF.Position+S.pasteOffset)*(S.activeAnchorCF-S.activeAnchorCF.Position)
    local s  = Vector3.new(0,0,0)
    local tr = S.previewTransparent and 0.5 or 0
    local bm = workspace:FindFirstChild("BuildModel")
    for _, data in pairs(S.activeBlocks) do
        if not S.excludedBlocks[data.name] then
            local relCF = S.activeIsCS and U.tableToCF(data.relCF) or data.relCF
            local tCF   = nA * relCF
            if not S.activeIsCS and bm then
                local origCF = S.activeAnchorCF * (S.activeIsCS and U.tableToCF(data.relCF) or data.relCF)
                local bestModel, bestDist = nil, math.huge
                for _, child in pairs(bm:GetChildren()) do
                    if child.Name == data.name then
                        local pv = U.getModelPivot(child)
                        if pv then
                            local d = (pv.Position - origCF.Position).Magnitude
                            if d < bestDist then bestDist=d; bestModel=child end
                        end
                    end
                end
                if bestModel then
                    local modelCF = U.getModelPivot(bestModel)
                    if modelCF then
                        for _, desc in ipairs(bestModel:GetDescendants()) do
                            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                                if desc.Transparency >= 1 then continue end
                                local ghost = desc:Clone()
                                for _, child in ipairs(ghost:GetChildren()) do
                                    if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                        or child:IsA("Decal") or child:IsA("Texture")) then
                                        child:Destroy()
                                    end
                                end
                                ghost.Anchored=true; ghost.CanCollide=false
                                ghost.CastShadow=false; ghost.Transparency=tr
                                if desc.Name == "ColorPart" then
                                    ghost.BrickColor = data.brickColor
                                    ghost.Material   = data.material
                                    if data.isResized then ghost.Size = data.cpSize end
                                end
                                local relPart = modelCF:ToObjectSpace(desc.CFrame)
                                ghost.CFrame = tCF * relPart
                                ghost.Name="CPGhost"; ghost.Parent=workspace
                                table.insert(S.previewParts, ghost)
                                s = s + ghost.CFrame.Position
                            end
                        end
                        continue
                    end
                end
            end
            local sz = S.activeIsCS and Vector3.new(table.unpack(data.cpSize)) or data.cpSize
            local p  = Instance.new("Part")
            p.Size=sz; p.CFrame=tCF; p.Anchored=true
            p.CanCollide=false; p.CastShadow=false; p.Transparency=tr
            if S.activeIsCS then
                local ok,bc   = pcall(function() return BrickColor.new(data.brickColor) end)
                local ok2,mat = pcall(function() return Enum.Material[data.material] end)
                p.BrickColor=ok and bc or BrickColor.new(1001)
                p.Material=ok2 and mat or Enum.Material.Plastic
            else
                p.BrickColor=data.brickColor; p.Material=data.material
            end
            p.Name="CPGhost"; p.Parent=workspace
            table.insert(S.previewParts, p); s=s+tCF.Position
        end
    end
    S.previewCenter = s / math.max(#S.previewParts, 1)
end

local function clearHandlesFunc()
    S.isPressing=false; S.isDragging=false; S.holdTimer=0
    S.dragDir=nil; S.lastMoveSteps=0; S.cachedScreenDir=nil
    if S.activeHandleBtn and S.activeHandleBtn.Parent then
        S.activeHandleBtn.BackgroundTransparency=0.1
    end
    S.activeHandleBtn=nil; S.activeTouchId=nil
    for _, h in ipairs(S.handleButtons) do
        if h.button and h.button.Parent then h.button:Destroy() end
    end
    S.handleButtons={}
    for _, rc in ipairs(S.ringContainers) do
        if rc.container and rc.container.Parent then rc.container:Destroy() end
    end
    S.ringContainers={}
end

local function hideRing(rc)
    for _, seg in ipairs(rc.segs) do seg.Visible=false end
end

local function spawnHandlesFunc()
    clearHandlesFunc()
    for _, axDef in ipairs(AXES) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(0,DOT_SIZE,0,DOT_SIZE); btn.AnchorPoint=Vector2.new(0.5,0.5)
        btn.Position=UDim2.new(0,-300,0,-300)
        btn.BackgroundColor3=PURPLE; btn.BackgroundTransparency=0.1
        btn.Text=""; btn.BorderSizePixel=0; btn.ZIndex=12; btn.Visible=false
        btn.Parent=screenGui; mkCorner(btn,999)
        local st=Instance.new("UIStroke")
        st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.5; st.Thickness=1.5; st.Parent=btn
        local cd=axDef.dir
        btn.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.Touch and
               input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if S.activeHandleBtn~=nil then return end
            S.isPressing=true; S.isDragging=false; S.holdTimer=0
            S.lastMoveSteps=0; S.cachedScreenDir=nil
            S.dragDir=cd; S.dragStartScreen=Vector2.new(input.Position.X,input.Position.Y)
            S.activeHandleBtn=btn; S.activeTouchId=input; btn.BackgroundTransparency=0.0
        end)
        table.insert(S.handleButtons,{button=btn, dir=cd, axis=axDef.axis, isRotate=false})
    end
    for _, rd in ipairs(RING_DEFS) do
        local container=Instance.new("Frame")
        container.Size=UDim2.new(1,0,1,0); container.BackgroundTransparency=1
        container.BorderSizePixel=0; container.ZIndex=6; container.Parent=screenGui
        local segs={}
        for i=1,RING_SEGS do
            local seg=Instance.new("Frame")
            seg.BackgroundColor3=rd.color; seg.BackgroundTransparency=0.25
            seg.BorderSizePixel=0; seg.ZIndex=6; seg.Visible=false; seg.Parent=container
            table.insert(segs,seg)
        end
        for dotIdx=1,2 do
            local btn=Instance.new("TextButton")
            btn.Size=UDim2.new(0,DOT_SIZE,0,DOT_SIZE); btn.AnchorPoint=Vector2.new(0.5,0.5)
            btn.Position=UDim2.new(0,-300,0,-300)
            btn.BackgroundColor3=rd.color; btn.BackgroundTransparency=0.1
            btn.Text=""; btn.BorderSizePixel=0; btn.ZIndex=12; btn.Visible=false
            btn.Parent=screenGui; mkCorner(btn,999)
            local st=Instance.new("UIStroke")
            st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.5; st.Thickness=1.5; st.Parent=btn
            local capturedRd=rd
            btn.InputBegan:Connect(function(input)
                if input.UserInputType~=Enum.UserInputType.Touch and
                   input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                if S.activeHandleBtn~=nil then return end
                S.isPressing=true; S.isDragging=false; S.holdTimer=0
                S.lastMoveSteps=0; S.cachedScreenDir=nil
                S.dragDir=capturedRd.rotAxis
                S.dragStartScreen=Vector2.new(input.Position.X,input.Position.Y)
                S.activeHandleBtn=btn; S.activeTouchId=input; btn.BackgroundTransparency=0.0
            end)
            table.insert(S.handleButtons,{button=btn, dir=rd.rotAxis, axis=rd.id, isRotate=true, dotIdx=dotIdx, ringDef=rd})
        end
        table.insert(S.ringContainers,{ringDef=rd, container=container, segs=segs})
    end
end

-- HUD
local hudGui  = nil
local hudMode = nil
local relTapConn = nil

local function destroyHud()
    if hudGui and hudGui.Parent then hudGui:Destroy() end
    hudGui=nil; hudMode=nil
end

local function updateHudMode()
    if not hudMode then return end
    if S.relativePaste then
        hudMode.Text="Relative: tap block to move"
        hudMode.TextColor3=Color3.fromRGB(255,200,60)
    else
        hudMode.Text=S.rotateMode and "Mode: Rotate" or "Mode: Move"
        hudMode.TextColor3=Color3.fromRGB(160,155,195)
    end
end

local deactivatePaste  -- forward declaration

local function createHud(blockCount)
    destroyHud()
    hudGui=Instance.new("ScreenGui")
    hudGui.Name="CPHud"; hudGui.ResetOnSpawn=false
    hudGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    hudGui.IgnoreGuiInset=true; hudGui.AutoLocalize=false
    hudGui.Parent=player.PlayerGui
    local W=280; local H=56
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(0,W,0,H); bg.AnchorPoint=Vector2.new(0.5,1)
    bg.Position=UDim2.new(0.5,0,1,-90)
    bg.BackgroundColor3=Color3.fromRGB(14,14,20); bg.BorderSizePixel=0; bg.ZIndex=20
    bg.Parent=hudGui; mkCorner(bg,10)
    local bgS=Instance.new("UIStroke"); bgS.Color=Color3.fromRGB(55,55,75); bgS.Thickness=1; bgS.Parent=bg
    local countLbl=Instance.new("TextLabel")
    countLbl.Size=UDim2.new(0,90,0,22); countLbl.Position=UDim2.new(0,10,0,6)
    countLbl.BackgroundTransparency=1; countLbl.Text=blockCount.." blocks"
    countLbl.TextColor3=Color3.fromRGB(140,90,220); countLbl.Font=Enum.Font.GothamBold
    countLbl.TextSize=12; countLbl.TextXAlignment=Enum.TextXAlignment.Left; countLbl.ZIndex=21; countLbl.Parent=bg
    hudMode=Instance.new("TextLabel")
    hudMode.Size=UDim2.new(0,150,0,16); hudMode.Position=UDim2.new(0,10,0,30)
    hudMode.BackgroundTransparency=1; hudMode.Font=Enum.Font.Gotham
    hudMode.TextSize=10; hudMode.TextXAlignment=Enum.TextXAlignment.Left; hudMode.ZIndex=21; hudMode.Parent=bg
    local cancelBtn=Instance.new("TextButton")
    cancelBtn.Size=UDim2.new(0,72,0,38); cancelBtn.AnchorPoint=Vector2.new(1,0.5)
    cancelBtn.Position=UDim2.new(1,-8,0.5,0)
    cancelBtn.BackgroundColor3=Color3.fromRGB(100,28,28); cancelBtn.BorderSizePixel=0
    cancelBtn.Text="Cancel"; cancelBtn.TextColor3=Color3.fromRGB(255,255,255)
    cancelBtn.Font=Enum.Font.GothamBold; cancelBtn.TextSize=12; cancelBtn.ZIndex=22; cancelBtn.Parent=bg
    mkCorner(cancelBtn,7)
    local pasteBtn=Instance.new("TextButton")
    pasteBtn.Size=UDim2.new(0,72,0,38); pasteBtn.AnchorPoint=Vector2.new(1,0.5)
    pasteBtn.Position=UDim2.new(1,-88,0.5,0)
    pasteBtn.BackgroundColor3=Color3.fromRGB(50,170,90); pasteBtn.BorderSizePixel=0
    pasteBtn.Text="Paste"; pasteBtn.TextColor3=Color3.fromRGB(255,255,255)
    pasteBtn.Font=Enum.Font.GothamBold; pasteBtn.TextSize=12; pasteBtn.ZIndex=22; pasteBtn.Parent=bg
    mkCorner(pasteBtn,7)
    cancelBtn.MouseButton1Click:Connect(function()
        S.relPasteWaiting=false; deactivatePaste()
    end)
    pasteBtn.MouseButton1Click:Connect(function()
        if not S.activeBlocks or #S.activeBlocks==0 or not S.activeAnchorCF then return end
        local blocks=S.activeBlocks; local anchorCF=S.activeAnchorCF
        local offset=S.pasteOffset; local isCS=S.activeIsCS
        local excl={}; for k,v in pairs(S.excludedBlocks) do excl[k]=v end
        clearPreview(); clearHandlesFunc()
        S.activeBlocks=nil; S.activeAnchorCF=nil
        S.pasteOffset=Vector3.new(0,0,0); S.pasteVisible=false
        S.relPasteWaiting=false
        if relTapConn then relTapConn:Disconnect(); relTapConn=nil end
        task.delay(0.05, destroyHud)
        task.spawn(function()
            U.resetSafeOffset()
            local nA=CFrame.new(anchorCF.Position+offset)*(anchorCF-anchorCF.Position)
            for _,d in pairs(blocks) do
                if not excl[d.name] then
                    if isCS then U.placeOneCS(d,nA) else U.placeOneCP(d,nA) end
                    task.wait(0.05)
                end
            end
        end)
    end)
    updateHudMode()
end

-- Relative paste listener
local startRelPasteListen
startRelPasteListen = function()
    if relTapConn then relTapConn:Disconnect(); relTapConn=nil end
    -- Small delay so the InputBegan that triggered activatePaste doesn't fire listener
    task.wait(0.1)
    if not S.pasteVisible then return end
    relTapConn = UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end  -- ignore clicks on GUI (HUD paste/cancel buttons)
        if not S.relativePaste or not S.pasteVisible then return end
        if input.UserInputType~=Enum.UserInputType.Touch and
           input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local pos=input.Position
        local unitRay=camera:ScreenPointToRay(pos.X,pos.Y)
        local params=RaycastParams.new()
        params.FilterType=Enum.RaycastFilterType.Include
        local bm=workspace:FindFirstChild("BuildModel"); if not bm then return end
        params.FilterDescendantsInstances={bm}
        local res=workspace:Raycast(unitRay.Origin,unitRay.Direction*500,params)
        if not res then return end
        local part=res.Instance
        while part and part.Parent~=bm do part=part.Parent end
        if not part or part.Name=="CPGhost" then return end
        local mfp=part:FindFirstChild("MouseFilterPart")
        local cp=part:FindFirstChild("ColorPart")
        local ref=mfp or cp; if not ref then return end
        local refCF=ref.CFrame; local refSize=ref.Size
        local isResized=refSize.X>4.6 or refSize.Y>4.6 or refSize.Z>4.6
        local targetPos
        if isResized then
            local localHit=refCF:PointToObjectSpace(res.Position)
            local sx=math.clamp(math.round(localHit.X/4.5)*4.5, -(refSize.X/2-2.25), refSize.X/2-2.25)
            local sy=math.clamp(math.round(localHit.Y/4.5)*4.5, -(refSize.Y/2-2.25), refSize.Y/2-2.25)
            local sz=math.clamp(math.round(localHit.Z/4.5)*4.5, -(refSize.Z/2-2.25), refSize.Z/2-2.25)
            targetPos=(refCF*CFrame.new(sx,sy,sz)).Position
        else
            targetPos=refCF.Position
        end
        S.pasteOffset=targetPos-S.activeAnchorCF.Position
        buildPreview()
    end)
end

local function activatePaste(blocks, anchorCF, isCS)
    clearPreview(); clearHandlesFunc()
    S.activeBlocks=blocks; S.activeAnchorCF=anchorCF; S.activeIsCS=isCS
    S.excludedBlocks={}; S.relPasteWaiting=false
    S.pasteOffset=U.spawnPosInFrontOfCamera().Position-anchorCF.Position
    S.pasteVisible=true
    buildPreview()
    if not S.relativePaste then spawnHandlesFunc() else startRelPasteListen() end
    createHud(#blocks)
end

deactivatePaste = function()
    clearPreview(); clearHandlesFunc()
    S.activeBlocks=nil; S.activeAnchorCF=nil
    S.pasteOffset=Vector3.new(0,0,0); S.pasteVisible=false
    S.relPasteWaiting=false
    if relTapConn then relTapConn:Disconnect(); relTapConn=nil end
    destroyHud()
end

-- RenderStepped handle rendering
RunService.RenderStepped:Connect(function(dt)
    if S.isPressing and not S.isDragging then
        S.holdTimer=S.holdTimer+dt
        if S.holdTimer>=S.HOLD_TIME then
            S.isDragging=true; S.lastMoveSteps=0
            if S.dragDir then
                local s0=camera:WorldToScreenPoint(S.previewCenter)
                local s1=camera:WorldToScreenPoint(S.previewCenter+S.dragDir*10)
                local sd=Vector2.new(s1.X-s0.X,s1.Y-s0.Y)
                if sd.Magnitude>1 then S.cachedScreenDir=sd/sd.Magnitude end
            end
            if S.activeHandleBtn and S.activeHandleBtn.Parent then
                S.activeHandleBtn.BackgroundTransparency=0.45
            end
        end
    end
    local r=14
    if S.pasteVisible then
        if not S.rotateMode then
            for _,rc in ipairs(S.ringContainers) do hideRing(rc) end
            for _,h in ipairs(S.handleButtons) do
                if not h.isRotate then
                    local wp=S.previewCenter+h.dir*r
                    local sp,vis=camera:WorldToScreenPoint(wp)
                    h.button.Visible=vis and sp.Z>0
                    if h.button.Visible then h.button.Position=UDim2.new(0,sp.X,0,sp.Y) end
                else h.button.Visible=false end
            end
        else
            for _,h in ipairs(S.handleButtons) do
                if not h.isRotate then h.button.Visible=false end
            end
            local sp0=camera:WorldToScreenPoint(S.previewCenter)
            for _,rc in ipairs(S.ringContainers) do
                local rd=rc.ringDef
                if sp0.Z<=0 then hideRing(rc); continue end
                local n=#rc.segs; local pts={}
                for i=0,n do
                    local t=(i/n)*math.pi*2
                    local wp=S.previewCenter+rd.ringU*(math.cos(t)*r)+rd.ringV*(math.sin(t)*r)
                    local sp=camera:WorldToScreenPoint(wp)
                    table.insert(pts,{x=sp.X,y=sp.Y,vis=sp.Z>0})
                end
                local isActive=S.activeHandleBtn~=nil and S.dragDir==rd.rotAxis
                local transp=isActive and 0.05 or 0.25
                for i=1,n do
                    local p1=pts[i]; local p2=pts[i+1]; local seg=rc.segs[i]
                    if not p1.vis or not p2.vis then seg.Visible=false; continue end
                    local midX=(p1.x+p2.x)*0.5; local midY=(p1.y+p2.y)*0.5
                    local dx=p2.x-p1.x; local dy=p2.y-p1.y
                    local len=math.sqrt(dx*dx+dy*dy)
                    seg.Size=UDim2.new(0,len+1,0,RING_THICK)
                    seg.Position=UDim2.new(0,midX-(len+1)*0.5,0,midY-RING_THICK*0.5)
                    seg.Rotation=math.deg(math.atan2(dy,dx))
                    seg.BackgroundColor3=rd.color; seg.BackgroundTransparency=transp; seg.Visible=true
                end
            end
            for _,h in ipairs(S.handleButtons) do
                if h.isRotate then
                    local rd=h.ringDef
                    local dir=h.dotIdx==1 and rd.dot1 or rd.dot2
                    local wp=S.previewCenter+dir*r
                    local sp,vis=camera:WorldToScreenPoint(wp)
                    h.button.Visible=vis and sp.Z>0
                    if h.button.Visible then h.button.Position=UDim2.new(0,sp.X,0,sp.Y) end
                end
            end
        end
    else
        for _,h in ipairs(S.handleButtons) do h.button.Visible=false end
        for _,rc in ipairs(S.ringContainers) do hideRing(rc) end
    end
end)

UIS.InputChanged:Connect(function(input)
    if not S.isDragging or not S.dragDir or not S.cachedScreenDir then return end
    if S.activeTouchId and input~=S.activeTouchId then return end
    if input.UserInputType~=Enum.UserInputType.MouseMovement and
       input.UserInputType~=Enum.UserInputType.Touch then return end
    local delta=Vector2.new(input.Position.X,input.Position.Y)-S.dragStartScreen
    local proj=delta:Dot(S.cachedScreenDir)
    local total=math.floor(proj*S.DRAG_SENS/S.pasteStep)
    local diff=total-S.lastMoveSteps
    if diff~=0 then
        S.lastMoveSteps=total
        if S.rotateMode then
            local angle=math.rad(S.pasteStep*diff)
            local rotCF=CFrame.fromAxisAngle(S.dragDir,angle)
            local pos=S.activeAnchorCF.Position+S.pasteOffset
            S.activeAnchorCF=CFrame.new(pos)*rotCF*(S.activeAnchorCF-S.activeAnchorCF.Position)-S.pasteOffset
        else
            S.pasteOffset=S.pasteOffset+S.dragDir*(diff*S.pasteStep)
        end
        buildPreview()
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.Touch and
       input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    if S.activeTouchId~=nil and input~=S.activeTouchId then return end
    S.isPressing=false; S.isDragging=false; S.holdTimer=0
    S.cachedScreenDir=nil; S.lastMoveSteps=0; S.dragDir=nil
    if S.activeHandleBtn and S.activeHandleBtn.Parent then S.activeHandleBtn.BackgroundTransparency=0.1 end
    S.activeHandleBtn=nil; S.activeTouchId=nil
end)

P.screenGui       = screenGui
P.buildPreview    = buildPreview
P.clearPreview    = clearPreview
P.clearHandles    = clearHandlesFunc
P.activatePaste   = activatePaste
P.deactivatePaste = deactivatePaste
P.updateHudMode   = updateHudMode

_G.CPT_Preview = P
