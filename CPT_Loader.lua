local BASE = "https://raw.githubusercontent.com/Neosq/CPT/main/"
local pg   = game:GetService("Players").LocalPlayer.PlayerGui

local function cleanup(name)
    local g = pg:FindFirstChild(name); if g then g:Destroy() end
end
cleanup("CopyPasteTool"); cleanup("CPHud"); cleanup("CPPreviewGui")
_G.CPT_Utils=nil; _G.CPT_State=nil; _G.CPT_Preview=nil
_G.CPT_Collect=nil; _G.CPT_3DPreview=nil; _G.CopyPasteTool=nil

loadstring(game:HttpGet(BASE.."CPT_State.lua"))()
loadstring(game:HttpGet(BASE.."CPT_Utils.lua"))()
loadstring(game:HttpGet(BASE.."CPT_Preview.lua"))()
loadstring(game:HttpGet(BASE.."CPT_Collect.lua"))()
loadstring(game:HttpGet(BASE.."CPT_3DPreview.lua"))()
loadstring(game:HttpGet(BASE.."CPT_UI.lua"))()
