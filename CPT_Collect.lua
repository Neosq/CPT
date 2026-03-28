local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player     = Players.LocalPlayer
local camera     = workspace.CurrentCamera
local mouse      = player:GetMouse()
local U          = _G.CPT_Utils
local S          = _G.CPT_State

local C = {}

local regionParts          = {}
local cpPos1Box, cpPos2Box = nil, nil

local function clearRegionBox()
    for _,p in pairs(regionParts) do if typeof(p)=="Instance" and p.Parent then p:Destroy() end end
    regionParts={}
end

local function updateRegionBox(c1, c2)
    clearRegionBox(); if not c1 or not c2 then return end
    local cen=(c1+c2)/2
    local sz=Vector3.new(math.abs(c2.X-c1.X)+4.5, math.abs(c2.Y-c1.Y)+4.5, math.abs(c2.Z-c1.Z)+4.5)
    local rp=Instance.new("Part"); rp.Size=sz; rp.CFrame=CFrame.new(cen)
    rp.Anchored=true; rp.CanCollide=false; rp.Transparency=1; rp.Parent=workspace
    local rb=Instance.new("SelectionBox"); rb.Color3=Color3.fromRGB(100,140,255)
    rb.LineThickness=0.05; rb.Adornee=rp; rb.Parent=workspace
    table.insert(regionParts,rp); table.insert(regionParts,rb)
end

local hoverBox, hoverBlock = nil, nil

RunService.Heartbeat:Connect(function()
    if S.cpSelectingCorner==0 then
        if hoverBox then hoverBox:Destroy(); hoverBox=nil end; hoverBlock=nil; return
    end
    local model=U.getBlockUnderMouse()
    if model and model~=hoverBlock then
        if hoverBox then hoverBox:Destroy() end; hoverBlock=model
        hoverBox=Instance.new("SelectionBox"); hoverBox.Color3=Color3.fromRGB(255,255,255); hoverBox.LineThickness=0.03
        local adorn=model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart") or model
        hoverBox.Adornee=adorn; hoverBox.Parent=workspace
    elseif not model then
        if hoverBox then hoverBox:Destroy(); hoverBox=nil end; hoverBlock=nil
    end
end)

local cpPos1Marker, cpPos2Marker = nil, nil
local function makeMarker(pos, color)
    local p = Instance.new("Part")
    p.Size=Vector3.new(1,1,1); p.CFrame=CFrame.new(pos)
    p.Anchored=true; p.CanCollide=false; p.CastShadow=false
    p.BrickColor=BrickColor.new(color); p.Material=Enum.Material.Neon
    p.Transparency=0.3; p.Shape=Enum.PartType.Ball; p.Parent=workspace
    return p
end

UIS.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and
       input.UserInputType~=Enum.UserInputType.Touch then return end
    if S.cpSelectingCorner==0 then return end
    local model, snappedPos = U.getHitPosSnapped(input.Position.X, input.Position.Y)
    if not model or not snappedPos then return end
    local adorn=model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart") or model
    if S.cpSelectingCorner==1 then
        S.cpCorner1=snappedPos; if cpPos1Box then cpPos1Box:Destroy() end
        if cpPos1Marker then cpPos1Marker:Destroy() end
        cpPos1Box=Instance.new("SelectionBox"); cpPos1Box.Color3=Color3.fromRGB(55,185,100)
        cpPos1Box.LineThickness=0.07; cpPos1Box.Adornee=adorn; cpPos1Box.Parent=workspace
        cpPos1Marker=makeMarker(snappedPos,"Bright green")
        S.cpSelectingCorner=0; updateRegionBox(S.cpCorner1, S.cpCorner2)
    elseif S.cpSelectingCorner==2 then
        S.cpCorner2=snappedPos; if cpPos2Box then cpPos2Box:Destroy() end
        if cpPos2Marker then cpPos2Marker:Destroy() end
        cpPos2Box=Instance.new("SelectionBox"); cpPos2Box.Color3=Color3.fromRGB(200,55,55)
        cpPos2Box.LineThickness=0.07; cpPos2Box.Adornee=adorn; cpPos2Box.Parent=workspace
        cpPos2Marker=makeMarker(snappedPos,"Bright red")
        S.cpSelectingCorner=0; updateRegionBox(S.cpCorner1, S.cpCorner2)
    end
end)

function C.clearRegionBox() clearRegionBox() end
function C.clearPos1Box()
    if cpPos1Box then cpPos1Box:Destroy(); cpPos1Box=nil end
    if cpPos1Marker then cpPos1Marker:Destroy(); cpPos1Marker=nil end
end
function C.clearPos2Box()
    if cpPos2Box then cpPos2Box:Destroy(); cpPos2Box=nil end
    if cpPos2Marker then cpPos2Marker:Destroy(); cpPos2Marker=nil end
end

function C.collectCP()
    S.cpCopiedBlocks={}; S.cpAnchorCF=nil
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm or not S.cpCorner1 or not S.cpCorner2 then return 0 end
    local c1,c2=S.cpCorner1,S.cpCorner2
    local minB=Vector3.new(math.min(c1.X,c2.X)-2.4, math.min(c1.Y,c2.Y)-2.4, math.min(c1.Z,c2.Z)-2.4)
    local maxB=Vector3.new(math.max(c1.X,c2.X)+2.4, math.max(c1.Y,c2.Y)+2.4, math.max(c1.Z,c2.Z)+2.4)
    -- Check if block's AABB overlaps with zone (handles resized blocks)
    local function blockOverlapsZone(block)
        local zp = U.getZonePos(block)
        if not zp then return false end
        -- First try center point check
        if U.blockInZone(zp, minB, maxB) then return true end
        -- For resized blocks - check if any part of AABB overlaps zone
        local sz = U.getBlockSize(block)
        local bMin = zp - sz*0.5
        local bMax = zp + sz*0.5
        return bMin.X<=maxB.X and bMax.X>=minB.X
           and bMin.Y<=maxB.Y and bMax.Y>=minB.Y
           and bMin.Z<=maxB.Z and bMax.Z>=minB.Z
    end
    local raw={}
    for _, block in pairs(bm:GetChildren()) do
        if blockOverlapsZone(block) then
            local pv=U.getModelPivot(block); if pv then table.insert(raw,{block=block,pivotCF=pv}) end
        end
    end
    if #raw==0 then return 0 end
    table.sort(raw,function(a,b)
        local pa,pb=a.pivotCF.Position,b.pivotCF.Position
        if math.abs(pa.X-pb.X)>0.01 then return pa.X<pb.X end
        if math.abs(pa.Y-pb.Y)>0.01 then return pa.Y<pb.Y end
        return pa.Z<pb.Z
    end)
    local anchorRef = U.getRefPart(raw[1].block)
    S.cpAnchorCF = anchorRef and anchorRef.CFrame or raw[1].pivotCF
    for _,e in ipairs(raw) do
        local pv  = U.getModelPivot(e.block)
        local relCF = S.cpAnchorCF:ToObjectSpace(pv)
        local sz  = U.getBlockSize(e.block)
        local isr = math.abs(sz.X-4.5)>0.1 or math.abs(sz.Y-4.5)>0.1 or math.abs(sz.Z-4.5)>0.1
        local resizeParts = nil
        if isr then
            resizeParts = {}
            for _, part in ipairs(e.block:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "MouseFilterPart" then
                    table.insert(resizeParts, {
                        name  = part.Name,
                        relCF = S.cpAnchorCF:ToObjectSpace(part.CFrame),
                        size  = part.Size,
                    })
                end
            end
        end
        table.insert(S.cpCopiedBlocks,{
            name=e.block.Name, relCF=relCF, cpSize=sz,
            brickColor=U.getModelBrickColor(e.block), material=U.getModelMaterial(e.block),
            isResized=isr, resizeParts=resizeParts, config=U.getConfiguration(e.block),
        })
    end
    return #S.cpCopiedBlocks
end

function C.collectCS(c1, c2)
    local blocks={}
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm or not c1 or not c2 then return blocks,nil end
    local minB=Vector3.new(math.min(c1.X,c2.X)-2.4, math.min(c1.Y,c2.Y)-2.4, math.min(c1.Z,c2.Z)-2.4)
    local maxB=Vector3.new(math.max(c1.X,c2.X)+2.4, math.max(c1.Y,c2.Y)+2.4, math.max(c1.Z,c2.Z)+2.4)
    local function blockOverlapsZone(block)
        local zp = U.getZonePos(block); if not zp then return false end
        if U.blockInZone(zp, minB, maxB) then return true end
        local sz = U.getBlockSize(block)
        local bMin = zp - sz*0.5; local bMax = zp + sz*0.5
        return bMin.X<=maxB.X and bMax.X>=minB.X
           and bMin.Y<=maxB.Y and bMax.Y>=minB.Y
           and bMin.Z<=maxB.Z and bMax.Z>=minB.Z
    end
    local raw={}
    for _,block in pairs(bm:GetChildren()) do
        if blockOverlapsZone(block) then
            local pv=U.getModelPivot(block); if pv then table.insert(raw,{block=block,pivotCF=pv}) end
        end
    end
    if #raw==0 then return blocks,nil end
    table.sort(raw,function(a,b)
        local pa,pb=a.pivotCF.Position,b.pivotCF.Position
        if math.abs(pa.X-pb.X)>0.01 then return pa.X<pb.X end
        if math.abs(pa.Y-pb.Y)>0.01 then return pa.Y<pb.Y end
        return pa.Z<pb.Z
    end)
    local anchorCF = raw[1].pivotCF
    for _,e in ipairs(raw) do
        local relCF = anchorCF:ToObjectSpace(e.pivotCF)
        local sz    = U.getBlockSize(e.block)
        local isr   = math.abs(sz.X-4.5)>0.1 or math.abs(sz.Y-4.5)>0.1 or math.abs(sz.Z-4.5)>0.1
        local bc    = U.getModelBrickColor(e.block); local mat=U.getModelMaterial(e.block)
        table.insert(blocks,{
            name=e.block.Name, relCF=U.cfToTable(relCF),
            cpSize={sz.X,sz.Y,sz.Z}, brickColor=tostring(bc), material=tostring(mat),
            isResized=isr, config=U.getConfiguration(e.block),
            category=U.getCategoryOfBlock(e.block.Name),
        })
    end
    return blocks, U.cfToTable(anchorCF)
end

_G.CPT_Collect = C
