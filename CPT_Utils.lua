local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local player      = Players.LocalPlayer
local camera      = workspace.CurrentCamera
local mouse       = player:GetMouse()
local SAVE_FILE   = "pbm_builds.json"

local U = {}

function U.loadBuilds()
    local ok, data = pcall(function() return readfile(SAVE_FILE) end)
    if not ok or not data or data=="" then return {} end
    local ok2, t = pcall(function() return HttpService:JSONDecode(data) end)
    return (ok2 and t) or {}
end

function U.saveBuilds(builds)
    pcall(function() writefile(SAVE_FILE, HttpService:JSONEncode(builds)) end)
end

function U.getDefaultName(builds)
    return "Build_"..#builds+1
end

function U.getCategoryOfBlock(blockName)
    local cats = {"Basic","Decoration","Events","Items","Lights","Links"}
    for _, cat in ipairs(cats) do
        local f = RS:FindFirstChild("Blocks") and RS.Blocks:FindFirstChild(cat)
        if f and f:FindFirstChild(blockName) then return cat end
    end
    local npcs = RS:FindFirstChild("BlocksCutscene") and RS.BlocksCutscene:FindFirstChild("NPCs")
    if npcs and npcs:FindFirstChild(blockName) then return "NPCs" end
    return "Basic"
end

function U.findBlockInRS(blockName)
    local cats = {"Basic","Decoration","Events","Items","Lights","Links"}
    for _, cat in ipairs(cats) do
        local f = RS:FindFirstChild("Blocks") and RS.Blocks:FindFirstChild(cat)
        if f then
            local b = f:FindFirstChild(blockName)
            if b then return b:FindFirstChild(blockName) or b end
        end
    end
    local npcs = RS:FindFirstChild("BlocksCutscene") and RS.BlocksCutscene:FindFirstChild("NPCs")
    if npcs then
        local b = npcs:FindFirstChild(blockName)
        if b then return b:FindFirstChild(blockName) or b end
    end
    return nil
end

function U.getModelBrickColor(model)
    local cp = model:FindFirstChild("ColorPart")
    return cp and cp.BrickColor or BrickColor.new(1001)
end

function U.getModelMaterial(model)
    local cp = model:FindFirstChild("ColorPart")
    return cp and cp.Material or Enum.Material.SmoothPlastic
end

function U.getConfiguration(model)
    local cfg = model:FindFirstChild("Configuration"); if not cfg then return {} end
    local t = {}
    for _, v in ipairs(cfg:GetChildren()) do
        if v:IsA("StringValue") or v:IsA("NumberValue") or v:IsA("BoolValue") then
            t[v.Name] = v.Value
        end
    end
    return t
end

function U.getModelPivot(model)
    local ok, pv = pcall(function() return model:GetPivot() end)
    if ok and pv then return pv end
    local cp = model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart")
    return cp and cp.CFrame or nil
end

function U.getRefPart(model)
    return model:FindFirstChild("ColorPart")
        or model:FindFirstChild("MouseFilterPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

function U.getBlockSize(model)
    local cp = model:FindFirstChild("ColorPart")
    if cp then return cp.Size end
    local mfp = model:FindFirstChild("MouseFilterPart")
    if mfp then return mfp.Size end
    local base = model:FindFirstChild("Base")
    if base then return base.Size end
    return Vector3.new(4.5, 4.5, 4.5)
end

function U.getBlockUnderMouse()
    local ur = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local p  = RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Include
    local bm = workspace:FindFirstChild("BuildModel"); if not bm then return nil end
    p.FilterDescendantsInstances={bm}
    local r = workspace:Raycast(ur.Origin, ur.Direction*500, p); if not r then return nil end
    local part = r.Instance
    while part and part.Parent ~= bm do part = part.Parent end
    return part
end

function U.getHitPosSnapped(x, y)
    x = x or mouse.X; y = y or mouse.Y
    local ur = camera:ScreenPointToRay(x, y)
    local p  = RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Include
    local bm = workspace:FindFirstChild("BuildModel"); if not bm then return nil,nil end
    p.FilterDescendantsInstances={bm}
    local r = workspace:Raycast(ur.Origin, ur.Direction*500, p)
    if not r then return nil,nil end
    local part = r.Instance
    while part and part.Parent ~= bm do part = part.Parent end
    if not part then return nil,nil end
    -- Get the model's pivot position to use as grid reference
    local ref = part:FindFirstChild("ColorPart")
             or part:FindFirstChild("MouseFilterPart")
             or part:FindFirstChildWhichIsA("BasePart")
    local GRID = 4.5
    local hp = r.Position
    local snapped
    if ref then
        -- Snap relative to block's own position so grid aligns with block edges
        local origin = ref.Position
        local rel = hp - origin
        local snappedRel = Vector3.new(
            math.round(rel.X/GRID)*GRID,
            math.round(rel.Y/GRID)*GRID,
            math.round(rel.Z/GRID)*GRID
        )
        snapped = origin + snappedRel
    else
        snapped = Vector3.new(
            math.round(hp.X/GRID)*GRID,
            math.round(hp.Y/GRID)*GRID,
            math.round(hp.Z/GRID)*GRID
        )
    end
    return part, snapped
end

function U.blockInZone(pos, minB, maxB)
    return pos.X>=minB.X-0.1 and pos.X<=maxB.X+0.1
       and pos.Y>=minB.Y-0.1 and pos.Y<=maxB.Y+0.1
       and pos.Z>=minB.Z-0.1 and pos.Z<=maxB.Z+0.1
end

function U.getZonePos(block)
    local mfp = block:FindFirstChild("MouseFilterPart")
    if mfp then return mfp.Position end
    local cp = block:FindFirstChild("ColorPart")
    if cp then return cp.Position end
    local ok, pv = pcall(function() return block:GetPivot() end)
    return ok and pv and pv.Position or nil
end

function U.cfToTable(cf)  return {cf:GetComponents()} end
function U.tableToCF(t)   return CFrame.new(table.unpack(t)) end

function U.spawnPosInFrontOfCamera()
    local cf = camera.CFrame
    return CFrame.new(cf.Position + cf.LookVector * 20)
end

function U.findNewBlock(name, pos)
    local bm = workspace:FindFirstChild("BuildModel"); if not bm then return nil end
    local best, bd = nil, 999
    for _, b in pairs(bm:GetChildren()) do
        if b.Name == name then
            local ok, pv = pcall(function() return b:GetPivot() end)
            if ok and pv then local d=(pv.Position-pos).Magnitude; if d<bd then bd=d; best=b end end
        end
    end
    return bd < 10 and best or nil
end

local SAFE_SPAWN = CFrame.new(0, 10000, 0)
local safeOffset = 0

function U.resetSafeOffset() safeOffset = 0 end

function U.placeOneCP(data, nA)
    local t = U.findBlockInRS(data.name); if not t then return end
    local tCF = nA * data.relCF
    safeOffset = safeOffset + 6
    local spawnCF = SAFE_SPAWN * CFrame.new(safeOffset, 0, 0)
    local nb
    pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF, data.brickColor, data.material) end)
    if not nb then pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF) end) end
    if not nb then task.wait(0.3); nb = U.findNewBlock(data.name, spawnCF.Position) end
    if not nb then return end
    pcall(function() RS.Functions.CommitMove:InvokeServer(nb, tCF) end)
    pcall(function() RS.Functions.PaintBlock:InvokeServer(nb, data.brickColor, data.material) end)
    if data.isResized and data.resizeParts then
        local nbPivot = U.getModelPivot(nb)
        local nbParts = {}
        for _, desc in ipairs(nb:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                local relY = nbPivot and (desc.CFrame.Position.Y - nbPivot.Position.Y) or 0
                local relZ = nbPivot and (desc.CFrame.Position.Z - nbPivot.Position.Z) or 0
                table.insert(nbParts, {part=desc, relY=relY, relZ=relZ})
            end
        end
        table.sort(nbParts, function(a, b)
            if a.part.Name ~= b.part.Name then return a.part.Name < b.part.Name end
            if math.abs(a.relY - b.relY) > 0.01 then return a.relY < b.relY end
            return a.relZ < b.relZ
        end)
        local savedParts = {}
        local savedPivotPos = data.relCF.Position
        for _, rp in ipairs(data.resizeParts) do
            local relY = rp.relCF.Position.Y - savedPivotPos.Y
            local relZ = rp.relCF.Position.Z - savedPivotPos.Z
            table.insert(savedParts, {rp=rp, relY=relY, relZ=relZ})
        end
        table.sort(savedParts, function(a, b)
            if a.rp.name ~= b.rp.name then return a.rp.name < b.rp.name end
            if math.abs(a.relY - b.relY) > 0.01 then return a.relY < b.relY end
            return a.relZ < b.relZ
        end)
        local args = {}
        for i, sp in ipairs(savedParts) do
            local np = nbParts[i]
            if np then
                table.insert(args, np.part)
                table.insert(args, nA * sp.rp.relCF)
                table.insert(args, sp.rp.size)
            end
        end
        if #args > 0 then
            pcall(function() RS.Functions.CommitResize:InvokeServer(nb, args) end)
        end
    end
    if data.config then pcall(function() RS.Functions.UpdateBlockSettings:InvokeServer(nb, data.config) end) end
end

function U.placeOneCS(data, nA)
    local t = U.findBlockInRS(data.name); if not t then return end
    local relCF = U.tableToCF(data.relCF); local tCF = nA * relCF
    local ok,  bc  = pcall(function() return BrickColor.new(data.brickColor) end)
    local ok2, mat = pcall(function() return Enum.Material[data.material] end)
    local brickColor = ok  and bc  or BrickColor.new(1001)
    local material   = ok2 and mat or Enum.Material.Plastic
    safeOffset = safeOffset + 6
    local spawnCF = SAFE_SPAWN * CFrame.new(safeOffset, 0, 0)
    local nb
    pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF, brickColor, material) end)
    if not nb then pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF) end) end
    if not nb then task.wait(0.25); nb = U.findNewBlock(data.name, spawnCF.Position) end
    if not nb then return end
    pcall(function() RS.Functions.CommitMove:InvokeServer(nb, tCF) end)
    pcall(function() RS.Functions.PaintBlock:InvokeServer(nb, brickColor, material) end)
    if data.isResized then
        task.wait(0.05)
        local cp = nb:FindFirstChild("ColorPart")
        if cp then
            pcall(function() RS.Functions.CommitResize:InvokeServer(nb, {cp, cp.CFrame, Vector3.new(table.unpack(data.cpSize))}) end)
        end
    end
    if data.config and next(data.config) then
        pcall(function() RS.Functions.UpdateBlockSettings:InvokeServer(nb, data.config) end)
    end
end

_G.CPT_Utils = U

function U.placeOneScaled(data, nA, sc)
    local t = U.findBlockInRS(data.name); if not t then return end
    local relCF = type(data.relCF)=="table" and U.tableToCF(data.relCF) or data.relCF
    local scaledCF = CFrame.new(relCF.Position * sc) * (relCF - relCF.Position)
    local tCF = nA * scaledCF
    local ok1, bc  = pcall(function() return BrickColor.new(data.brickColor) end)
    local ok2, mat = pcall(function() return Enum.Material[data.material] end)
    local brickColor = ok1 and bc  or BrickColor.new(1001)
    local material   = ok2 and mat or Enum.Material.Plastic
    safeOffset = safeOffset + 6
    local spawnCF = SAFE_SPAWN * CFrame.new(safeOffset, 0, 0)
    local nb
    pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF, brickColor, material) end)
    if not nb then pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF) end) end
    if not nb then task.wait(0.3); nb = U.findNewBlock(data.name, spawnCF.Position) end
    if not nb then return end
    pcall(function() RS.Functions.CommitMove:InvokeServer(nb, tCF) end)
    pcall(function() RS.Functions.PaintBlock:InvokeServer(nb, brickColor, material) end)
    task.wait(0.05)
    if data.isResized and data.resizeParts and #data.resizeParts > 0 then
        local nbPivot = U.getModelPivot(nb)
        local nbParts = {}
        for _, desc in ipairs(nb:GetDescendants()) do
            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                local relY = nbPivot and (desc.CFrame.Position.Y - nbPivot.Position.Y) or 0
                local relZ = nbPivot and (desc.CFrame.Position.Z - nbPivot.Position.Z) or 0
                table.insert(nbParts, {part=desc, relY=relY, relZ=relZ})
            end
        end
        table.sort(nbParts, function(a, b)
            if a.part.Name ~= b.part.Name then return a.part.Name < b.part.Name end
            if math.abs(a.relY - b.relY) > 0.01 then return a.relY < b.relY end
            return a.relZ < b.relZ
        end)
        local savedPivotPos = relCF.Position
        local savedParts = {}
        for _, rp in ipairs(data.resizeParts) do
            local rpCF = type(rp.relCF)=="table" and U.tableToCF(rp.relCF) or rp.relCF
            local relY = rpCF.Position.Y - savedPivotPos.Y
            local relZ = rpCF.Position.Z - savedPivotPos.Z
            table.insert(savedParts, {rp=rp, rpCF=rpCF, relY=relY, relZ=relZ})
        end
        table.sort(savedParts, function(a, b)
            if a.rp.name ~= b.rp.name then return a.rp.name < b.rp.name end
            if math.abs(a.relY - b.relY) > 0.01 then return a.relY < b.relY end
            return a.relZ < b.relZ
        end)
        local args = {}
        for i, sp in ipairs(savedParts) do
            local np = nbParts[i]; if not np then continue end
            local scaledPartCF = CFrame.new(sp.rpCF.Position * sc) * (sp.rpCF - sp.rpCF.Position)
            local rpSize = type(sp.rp.size)=="table"
                and Vector3.new(sp.rp.size[1], sp.rp.size[2], sp.rp.size[3])
                or sp.rp.size
            table.insert(args, np.part)
            table.insert(args, nA * scaledPartCF)
            table.insert(args, rpSize * sc)
        end
        if #args > 0 then
            pcall(function() RS.Functions.CommitResize:InvokeServer(nb, args) end)
        end
    else
        if math.abs(sc - 1.0) > 0.01 then
            local cp = nb:FindFirstChild("ColorPart")
            if cp then
                local baseSize = type(data.cpSize)=="table"
                    and Vector3.new(data.cpSize[1], data.cpSize[2], data.cpSize[3])
                    or (data.cpSize or cp.Size)
                pcall(function() RS.Functions.CommitResize:InvokeServer(nb, {cp, tCF, baseSize * sc}) end)
            else
                -- Multi-part block without ColorPart (e.g. WindowBlockThin)
                -- Scale each visible part relative to pivot
                local nbPivot = U.getModelPivot(nb)
                local args = {}
                for _, desc in ipairs(nb:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                        local relCFpart = nbPivot and CFrame.new(
                            (desc.CFrame.Position - nbPivot.Position) * sc + nbPivot.Position
                        ) * (desc.CFrame - desc.CFrame.Position) or desc.CFrame
                        table.insert(args, desc)
                        table.insert(args, relCFpart)
                        table.insert(args, desc.Size * sc)
                    end
                end
                if #args > 0 then
                    pcall(function() RS.Functions.CommitResize:InvokeServer(nb, args) end)
                end
            end
        end
    end
end
