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
local VP = _G.CPT_3DPreview
local updateHudMode = function() if P.updateHudMode then P.updateHudMode() end end
local buildPreview  = function() if P.buildPreview  then P.buildPreview()  end end

local Window=WindUI:CreateWindow({
    Title="Copy & Paste", Author="PBM Tools", Folder="PBM",
    Size=UDim2.fromOffset(560,500), Icon="copy",
    ModernLayout=true, BottomDragBarEnabled=true,
})
local CPTab=Window:Tab({Title="Build",          Icon="clipboard"})
local SLTab=Window:Tab({Title="Structure Loader",Icon="database"})
local TLTab=Window:Tab({Title="Tools",           Icon="settings"})
local cpStatusPara=nil; local csStatusPara=nil
local buildsDropdown=nil; local buildsCache={}
local function cpStatus(txt)
    if cpStatusPara then pcall(function() cpStatusPara:Set({Title="Status",Content=txt}) end) end
end
local function csStatus(txt)
    if csStatusPara then pcall(function() csStatusPara:Set({Title="Status",Content=txt}) end) end
end
CPTab:Section({Title="Build"})
cpStatusPara=CPTab:Paragraph({Title="Status",Content="Pick Pos 1"})
CPTab:Button({Title="Set Pos 1", Callback=function()
    S.cpSelectingCorner=1; cpStatus("Click Pos 1 block...")
end})
CPTab:Button({Title="Set Pos 2", Callback=function()
    if not S.cpCorner1 then cpStatus("Pick Pos 1 first!"); return end
    S.cpSelectingCorner=2; cpStatus("Click Pos 2 block...")
end})
CPTab:Button({Title="Copy Zone", Callback=function()
    if not S.cpCorner1 or not S.cpCorner2 then cpStatus("Pick both positions!"); return end
    local count=C.collectCP()
    if count==0 then cpStatus("No blocks in zone!"); return end
    cpStatus("Copied "..count.." blocks")
    P.activatePaste(S.cpCopiedBlocks, S.cpAnchorCF, false)
end})
CPTab:Button({Title="Reset", Callback=function()
    S.cpCorner1=nil; S.cpCorner2=nil; S.cpCopiedBlocks={}; S.cpSelectingCorner=0; S.cpAnchorCF=nil
    C.clearRegionBox(); C.clearPos1Box(); C.clearPos2Box()
    P.deactivatePaste()
    cpStatus("Pick Pos 1")
end})
CPTab:Button({Title="Delete Zone", Callback=function()
    if not S.cpCorner1 or not S.cpCorner2 then cpStatus("Pick both positions first!"); return end
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm then cpStatus("No BuildModel!"); return end
    local c1,c2=S.cpCorner1,S.cpCorner2
    local minB=Vector3.new(math.min(c1.X,c2.X)-2.4, math.min(c1.Y,c2.Y)-2.4, math.min(c1.Z,c2.Z)-2.4)
    local maxB=Vector3.new(math.max(c1.X,c2.X)+2.4, math.max(c1.Y,c2.Y)+2.4, math.max(c1.Z,c2.Z)+2.4)
    local toDelete={}
    for _,block in pairs(bm:GetChildren()) do
        local zp=U.getZonePos(block)
        if zp and U.blockInZone(zp,minB,maxB) then
            table.insert(toDelete,block)
        end
    end
    if #toDelete==0 then cpStatus("No blocks in zone!"); return end
    cpStatus("Deleting "..#toDelete.." blocks...")
    task.spawn(function()
        for _,block in ipairs(toDelete) do
            pcall(function() RS.Functions.DestroyBlock:InvokeServer(block) end)
            task.wait(0.05)
        end
        cpStatus("Deleted "..#toDelete.." blocks")
    end)
end})
CPTab:Section({Title="Save Build"})
CPTab:Input({Title="Build Name", Placeholder="Auto if empty", Callback=function(text)
    S.pendingName=text
end})
CPTab:Button({Title="Save to File", Callback=function()
    if not S.cpCorner1 or not S.cpCorner2 then cpStatus("Copy zone first!"); return end
    local blocks,anchor=C.collectCS(S.cpCorner1,S.cpCorner2)
    if #blocks==0 then cpStatus("No blocks in zone!"); return end
    local builds=U.loadBuilds()
    local name=(S.pendingName~="" and S.pendingName) or U.getDefaultName(builds)
    table.insert(builds,{name=name, blocks=blocks, anchor=anchor, date=os.date("%d.%m %H:%M")})
    U.saveBuilds(builds); cpStatus("Saved: "..name.." ("..#blocks.." blocks)")
    S.pendingName=""
end})
CPTab:Section({Title="Other"})
CPTab:Dropdown({Title="Handle Mode", Values={"Move","Rotate"}, Default="Move", Callback=function(v)
    S.rotateMode=v=="Rotate"
    updateHudMode()
end})
CPTab:Toggle({Title="Transparent Preview", State=false, Callback=function(s)
    S.previewTransparent=s; buildPreview()
end})
CPTab:Toggle({Title="Relative Paste", State=false, Callback=function(s)
    S.relativePaste=s
end})
CPTab:Slider({Title="Value", Value={Min=0.1,Max=13.5,Default=4.5}, Callback=function(v)
    S.pasteStep = math.max(v, 0.1)
end})
SLTab:Section({Title="Structure Loader"})
csStatusPara=SLTab:Paragraph({Title="Status",Content="Select a build"})
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
    Title="Select Build", Values=getBuildsForDropdown(), Default=nil,
    Callback=function(val)
        for _,b in ipairs(buildsCache) do
            if b.name.." | "..#b.blocks.." blks"==val then
                S.selectedBuild=b
                csStatus("Selected: "..b.name)
                break
            end
        end
    end,
})
SLTab:Button({Title="Refresh", Callback=refreshDropdown})
SLTab:Button({Title="Open 3D Preview", Icon="eye", Callback=function()
    if not S.selectedBuild then csStatus("Select a build first!"); return end
    VP.openPreviewGui(S.selectedBuild)
end})
SLTab:Button({Title="Delete Selected", Callback=function()
    if not S.selectedBuild then return end
    local builds=U.loadBuilds()
    for i,b in ipairs(builds) do
        if b.name==S.selectedBuild.name then table.remove(builds,i); break end
    end
    U.saveBuilds(builds); S.selectedBuild=nil
    csStatus("Deleted"); refreshDropdown()
end})
SLTab:Section({Title="Other"})
SLTab:Dropdown({Title="Handle Mode", Values={"Move","Rotate"}, Default="Move", Callback=function(v)
    S.rotateMode=v=="Rotate"
    updateHudMode()
end})
SLTab:Toggle({Title="Transparent Preview", State=false, Callback=function(s)
    S.previewTransparent=s; buildPreview()
end})
SLTab:Toggle({Title="Relative Paste", State=false, Callback=function(s)
    S.relativePaste=s
end})
SLTab:Slider({Title="Value", Value={Min=0.1,Max=13.5,Default=4.5}, Callback=function(v)
    S.pasteStep = math.max(v, 0.1)
end})
refreshDropdown()

-- Tools tab
TLTab:Section({Title="General"})
TLTab:Toggle({Title="Multi Select (max 5)", State=false, Callback=function(s)
    if _G.PBM then _G.PBM.setMultiSelect(s) end
end})

_G.CopyPasteTool={
    deactivate=P.deactivatePaste,
    openPreview=VP.openPreviewGui,
}
