local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player       = Players.LocalPlayer
local camera       = workspace.CurrentCamera
local WindUI       = loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal"))()
local U  = _G.CPT_Utils
local S  = _G.CPT_State
local P  = _G.CPT_Preview
local C  = _G.CPT_Collect
local updateHudMode = function() if P.updateHudMode then P.updateHudMode() end end
local buildPreview  = function() if P.buildPreview  then P.buildPreview()  end end

local Window = WindUI:CreateWindow({
    Title  = "Copy & Paste",
    Author = "PBM Tools",
    Folder = "PBM",
    Size   = UDim2.fromOffset(560, 520),
    Icon   = "copy",
    ModernLayout        = true,
    BottomDragBarEnabled= true,
    Color               = Color3.fromRGB(100, 60, 180),
})

local CPTab = Window:Tab({Title="Build",           Icon="clipboard",  Desc="Copy and paste blocks"})
local SLTab = Window:Tab({Title="Structure Loader", Icon="database",   Desc="Load saved structures"})
local TLTab = Window:Tab({Title="Tools",            Icon="settings",   Desc="Global settings"})

local buildsDropdown = nil
local buildsCache    = {}

-- ─── BUILD TAB ─────────────────────────────────────────────────────────────
CPTab:Section({Title="Selection"})

CPTab:Button({
    Title="Place Marker",
    Desc ="Place a 4.5 block marker in front of you (max 2, moveable)",
    Icon ="map-pin",
    Callback=function() C.placeMarker() end,
})
CPTab:Button({
    Title="Set Pos 1",
    Desc ="Tap a block to set the first corner of the copy zone",
    Icon ="corner-down-right",
    Callback=function() S.cpSelectingCorner=1 end,
})
CPTab:Button({
    Title="Set Pos 2",
    Desc ="Tap a block to set the second corner of the copy zone",
    Icon ="corner-up-left",
    Callback=function()
        if not S.cpCorner1 then return end
        S.cpSelectingCorner=2
    end,
})

CPTab:Space({})

CPTab:Button({
    Title="Copy Zone",
    Desc ="Collect all blocks inside the selected zone",
    Icon ="copy",
    Callback=function()
        if not S.cpCorner1 or not S.cpCorner2 then return end
        local count=C.collectCP()
        if count==0 then return end
        if S.pasteInPlace then
            P.activatePasteInPlace(S.cpCopiedBlocks, S.cpAnchorCF, false)
        else
            P.activatePaste(S.cpCopiedBlocks, S.cpAnchorCF, false)
        end
    end,
})
CPTab:Button({
    Title="Reset",
    Desc ="Clear all selections, markers and preview",
    Icon ="rotate-ccw",
    Callback=function()
        S.cpCorner1=nil; S.cpCorner2=nil; S.cpCopiedBlocks={}
        S.cpSelectingCorner=0; S.cpAnchorCF=nil
        C.clearRegionBox(); C.clearPos1Box(); C.clearPos2Box(); C.clearMarkers()
        P.deactivatePaste()
    end,
})
CPTab:Button({
    Title="Delete Zone",
    Desc ="Destroy all blocks inside the selected zone",
    Icon ="trash-2",
    Callback=function()
        if not S.cpCorner1 or not S.cpCorner2 then return end
        local bm=workspace:FindFirstChild("BuildModel"); if not bm then return end
        local c1,c2=S.cpCorner1,S.cpCorner2
        local minB=Vector3.new(math.min(c1.X,c2.X)-2.4, math.min(c1.Y,c2.Y)-2.4, math.min(c1.Z,c2.Z)-2.4)
        local maxB=Vector3.new(math.max(c1.X,c2.X)+2.4, math.max(c1.Y,c2.Y)+2.4, math.max(c1.Z,c2.Z)+2.4)
        local toDelete={}
        for _,block in pairs(bm:GetChildren()) do
            local zp=U.getZonePos(block)
            if zp and U.blockInZone(zp,minB,maxB) then table.insert(toDelete,block) end
        end
        if #toDelete==0 then return end
        task.spawn(function()
            for _,block in ipairs(toDelete) do
                pcall(function() RS.Functions.DestroyBlock:InvokeServer(block) end)
                task.wait(0.05)
            end
        end)
    end,
})

CPTab:Space({})
CPTab:Section({Title="Save Build"})

CPTab:Input({
    Title="Build Name",
    Desc ="Leave empty for auto name",
    Placeholder="Auto if empty",
    Callback=function(text) S.pendingName=text end,
})
CPTab:Button({
    Title="Save to File",
    Desc ="Save the selected zone as a structure file",
    Icon ="save",
    Callback=function()
        if not S.cpCorner1 or not S.cpCorner2 then return end
        local blocks,anchor=C.collectCS(S.cpCorner1,S.cpCorner2)
        if #blocks==0 then return end
        local builds=U.loadBuilds()
        local name=(S.pendingName~="" and S.pendingName) or U.getDefaultName(builds)
        table.insert(builds,{name=name,blocks=blocks,anchor=anchor,date=os.date("%d.%m %H:%M")})
        U.saveBuilds(builds)
        S.pendingName=""
    end,
})

CPTab:Space({})
CPTab:Section({Title="Options"})

CPTab:Toggle({
    Title="Old Paste (In-Place)",
    Desc ="Preview spawns at the copied location instead of in front of you",
    Icon ="anchor",
    State=false,
    Callback=function(s) S.pasteInPlace=s end,
})
CPTab:Dropdown({
    Title="Handle Mode",
    Desc ="Move: drag handles  •  Relative: tap a block to snap",
    Icon ="mouse-pointer",
    Values={"Move", "Relative"},
    Default="Move",
    Callback=function(v)
        local isRelative = v=="Relative"
        S.rotateMode    = false
        S.relativePaste = isRelative
        if S.pasteVisible then
            if isRelative then
                P.clearHandles(); P.startRelPasteListen()
            else
                P.stopRelPasteListen(); P.spawnHandles()
            end
            updateHudMode()
        end
    end,
})
CPTab:Toggle({
    Title="Transparent Preview",
    Desc ="Show ghost blocks semi-transparent",
    Icon ="eye-off",
    State=false,
    Callback=function(s) S.previewTransparent=s; buildPreview() end,
})
CPTab:Slider({
    Title="Paste Scale %",
    Desc ="Scale the structure on paste (100 = original size)",
    Value={Min=10,Max=400,Default=100},
    Callback=function(v) S.scalePct=math.floor(v); buildPreview() end,
})
CPTab:Slider({
    Title="Move Step",
    Desc ="Distance per handle drag step",
    Value={Min=0.1,Max=13.5,Default=4.5},
    Callback=function(v) S.pasteStep=math.max(v,0.1) end,
})
CPTab:Slider({
    Title="Drag Speed",
    Desc ="How fast handles move (1 = default, 10 = fastest)",
    Value={Min=1,Max=10,Default=1},
    Callback=function(v) S.dragSens=0.08*v end,
})

CPTab:Space({})
CPTab:Section({Title="History"})
CPTab:Button({
    Title="Undo History",
    Desc ="View and undo previously pasted structures",
    Icon ="clock",
    Callback=function()
        if _G.CPT_Undo then _G.CPT_Undo.openGui() end
    end,
})

-- ─── STRUCTURE LOADER TAB ──────────────────────────────────────────────────
SLTab:Section({Title="Saved Structures"})

local function getBuildsForDropdown()
    local builds=U.loadBuilds(); buildsCache=builds
    local names={}
    for _,b in ipairs(builds) do
        table.insert(names, b.name.." | "..#b.blocks.." blks")
    end
    return names
end
local function refreshDropdown()
    local names=getBuildsForDropdown()
    if buildsDropdown then
        pcall(function() buildsDropdown:Refresh(names,true) end)
    end
end

buildsDropdown=SLTab:Dropdown({
    Title="Select Build",
    Desc ="Choose a saved structure to load",
    Values=getBuildsForDropdown(),
    Default=nil,
    Callback=function(val)
        for _,b in ipairs(buildsCache) do
            if b.name.." | "..#b.blocks.." blks"==val then
                S.selectedBuild=b; break
            end
        end
    end,
})

SLTab:Space({})

SLTab:Button({
    Title="Open 3D Preview",
    Desc ="Preview and load the selected structure",
    Icon ="box",
    Callback=function()
        if not S.selectedBuild then return end
        local vp=_G.CPT_3DPreview
        if vp and vp.openPreviewGui then vp.openPreviewGui(S.selectedBuild) end
    end,
})
SLTab:Button({
    Title="Refresh",
    Desc ="Reload the list of saved structures",
    Icon ="refresh-cw",
    Callback=refreshDropdown,
})
SLTab:Button({
    Title="Delete Selected",
    Desc ="Permanently delete the selected structure",
    Icon ="trash-2",
    Callback=function()
        if not S.selectedBuild then return end
        local builds=U.loadBuilds()
        for i,b in ipairs(builds) do
            if b.name==S.selectedBuild.name then table.remove(builds,i); break end
        end
        U.saveBuilds(builds); S.selectedBuild=nil; refreshDropdown()
    end,
})

SLTab:Space({})
SLTab:Section({Title="Options"})

SLTab:Dropdown({
    Title="Handle Mode",
    Desc ="Move: drag handles  •  Relative: tap a block to snap",
    Icon ="mouse-pointer",
    Values={"Move", "Relative"},
    Default="Move",
    Callback=function(v)
        local isRelative = v=="Relative"
        S.relativePaste = isRelative
        if S.pasteVisible then
            if isRelative then
                P.clearHandles(); P.startRelPasteListen()
            else
                P.stopRelPasteListen(); P.spawnHandles()
            end
            updateHudMode()
        end
    end,
})
SLTab:Toggle({
    Title="Transparent Preview",
    Desc ="Show ghost blocks semi-transparent",
    Icon ="eye-off",
    State=false,
    Callback=function(s) S.previewTransparent=s; buildPreview() end,
})
SLTab:Slider({
    Title="Paste Scale %",
    Desc ="Scale the structure on paste",
    Value={Min=10,Max=400,Default=100},
    Callback=function(v) S.scalePct=math.floor(v); buildPreview() end,
})
SLTab:Slider({
    Title="Move Step",
    Desc ="Distance per handle drag step",
    Value={Min=0.1,Max=13.5,Default=4.5},
    Callback=function(v) S.pasteStep=math.max(v,0.1) end,
})
SLTab:Slider({
    Title="Drag Speed",
    Desc ="How fast handles move",
    Value={Min=1,Max=10,Default=1},
    Callback=function(v) S.dragSens=0.08*v end,
})

SLTab:Space({})
SLTab:Section({Title="History"})
SLTab:Button({
    Title="Undo History",
    Desc ="View and undo previously pasted structures",
    Icon ="clock",
    Callback=function()
        if _G.CPT_Undo then _G.CPT_Undo.openGui() end
    end,
})

-- ─── TOOLS TAB ─────────────────────────────────────────────────────────────
TLTab:Section({Title="General"})
TLTab:Toggle({
    Title="Multi Select",
    Desc ="Select up to 5 blocks at once (Move/Resize/Rotate)",
    Icon ="layers",
    State=false,
    Callback=function(s)
        if _G.PBM then _G.PBM.setMultiSelect(s) end
    end,
})

refreshDropdown()

_G.CopyPasteTool={
    deactivate  = P.deactivatePaste,
    openPreview = _G.CPT_3DPreview and _G.CPT_3DPreview.openPreviewGui,
}
