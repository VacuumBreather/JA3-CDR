-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

local function ApplyCameraSettings()
    local options = CurrentModOptions
    if not options or not options.GetProperty then return end

    local zoom_min = options:GetProperty("cdr_zoom_min") or 65
    local zoom_max = options:GetProperty("cdr_zoom_max") or 200
    local zoom_step = options:GetProperty("cdr_zoom_step") or 25
    local pitch_angle = options:GetProperty("cdr_pitch_angle") or 60

    local is_overview = cameraTac.GetIsInOverview()
    
    local settings = {
        CameraTacMinZoom = zoom_min,
        CameraTacMaxZoom = zoom_max,
        CameraTacZoomStep = zoom_step,
        CameraTacMaxZoomOverview = zoom_max * 170 / 100,
        CameraTacLookAtAngle = (is_overview and hr.CameraTacLookAtAngleInOverview) or (pitch_angle * 60),
        CameraTacClampToTerrain = true,
        CameraTacHeight = 1100, -- Default
    }
    
    -- When in overview, the engine likely clamps distance to CameraTacHeight * some_multiplier.
    -- Default 1100 * 2.0 = 2200, which matches the hard plateau.
    -- We increase the base height in overview to push that plateau higher.
    if is_overview then
        local ov_max = settings.CameraTacMaxZoomOverview
        settings.CameraTacMaxZoom = ov_max
        settings.CameraTacMinZoom = 10
        -- Scale height drastically to see if the plateau shifts.
        settings.CameraTacHeight = 5000 
    end

    for k, v in pairs(settings) do
        hr[k] = v
    end
    
    if _G.table_change_stack and _G.table_change_stack[hr] then
        for _, entry in ipairs(_G.table_change_stack[hr]) do
            for k, v in pairs(settings) do
                if entry.old[k] ~= nil then entry.old[k] = v end
                if entry.new[k] ~= nil then entry.new[k] = v end
            end
        end
    end
end

-- Re-apply settings after any table.restore on hr
local old_table_restore = table.restore
function table.restore(t, ...)
    local res = old_table_restore(t, ...)
    if t == hr then
        ApplyCameraSettings()
    end
    return res
end

-- Re-apply settings when options are changed in the menu
function OnMsg.ApplyModOptions(id)
    if id == CurrentModId then
        ApplyCameraSettings()
    end
end


-- Hook AdjustCombatCamera to prevent the game from overriding our camera settings during the enemy turn
local old_AdjustCombatCamera = AdjustCombatCamera
function AdjustCombatCamera(state, ...)
    if not CanYield() then
        CreateGameTimeThread(AdjustCombatCamera, state, ...)
        return
    end

    if state == "set" then
        local instant, target, floor, sleepTime, noFitCheck = ...
        if target then
            if not floor then
                floor = GetStepFloor(target)
            end
            sleepTime = sleepTime or 1000
            if noFitCheck or not DoPointsFitScreen({IsPoint(target) and target or target:GetVisualPos()}, nil, const.Camera.BufferSizeNoCameraMov) then
                SnapCameraToObj(target, "force", floor, sleepTime)
            end
        end
        return
    end

    local res = old_AdjustCombatCamera(state, ...)
    ApplyCameraSettings()
    return res
end

-- Globally override LockCameraMovement to prevent camera locking during combat
function LockCameraMovement(reason)
    -- We want to prevent tactical camera movement locking during combat
end

-- Ensure cameraTac.SetForceMaxZoom doesn't lock zoom
local old_SetForceMaxZoom = cameraTac.SetForceMaxZoom
function cameraTac.SetForceMaxZoom(force, ...)
    if force then
        -- Do nothing to prevent the game from forcing a zoom level/locking zoom
        -- print("Prevented SetForceMaxZoom(true)")
        return
    end
    return old_SetForceMaxZoom(force, ...)
end

-- Hook into messages to ensure settings are applied
function OnMsg.LoadSessionData()
    ApplyCameraSettings()
    UnlockCameraMovement(nil, "unlock_all")
end

function OnMsg.NewMapLoaded()
    ApplyCameraSettings()
    UnlockCameraMovement(nil, "unlock_all")
end

local old_OnMouseWheelForward = IModeCommonUnitControl.OnMouseWheelForward
function IModeCommonUnitControl:OnMouseWheelForward(...)
    ApplyCameraSettings()
    return old_OnMouseWheelForward(self, ...)
end

local old_OnMouseWheelBack = IModeCommonUnitControl.OnMouseWheelBack
function IModeCommonUnitControl:OnMouseWheelBack(...)
    ApplyCameraSettings()
    return old_OnMouseWheelBack(self, ...)
end

function OnMsg.CameraTacOverview(set)
    ApplyCameraSettings()
end

function OnMsg.TacCamFloorChanged()
    ApplyCameraSettings()
end

local old_SetZoom = cameraTac.SetZoom
function cameraTac.SetZoom(zoom, ...)
    ApplyCameraSettings()
    return old_SetZoom(zoom, ...)
end

local old_Normalize = cameraTac.Normalize
function cameraTac.Normalize(...)
    -- print("Normalize called")
    ApplyCameraSettings()
    return old_Normalize(...)
end

local old_GetZoom = cameraTac.GetZoom
function cameraTac.GetZoom(...)
    local res = old_GetZoom(...)
    -- print("GetZoom: " .. tostring(res))
    return res
end

-- Initial application
ApplyCameraSettings()
UnlockCameraMovement(nil, "unlock_all")
cameraTac.SetForceMaxZoom(false)

print("Camera Done Right mod loaded.")
