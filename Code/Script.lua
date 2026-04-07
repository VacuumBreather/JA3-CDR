-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

-- Local variables for camera state caching
local cachedTactical = false
local cachedZoomTactical = false
local cachedOverview = false
local cachedZoomOverview = false

local function ApplyCameraSettings(forced_overview)
    local options = CurrentModOptions
    if not options or not options.GetProperty then return end

    local zoom_min = options:GetProperty("cdr_zoom_min") or 65
    local zoom_max = options:GetProperty("cdr_zoom_max") or 200
    local zoom_step = options:GetProperty("cdr_zoom_step") or 15
    local pitch_angle = options:GetProperty("cdr_pitch_angle") or 60

    local is_overview = forced_overview
    if is_overview == nil then
        is_overview = cameraTac.GetIsInOverview()
    end
    
    -- In overview, zoom limits are ignored by the engine's C++ input path.
    -- The only way to move the 2200 plateau is to change the base Height.
    local settings = {
        CameraTacMinZoom = 22, -- 5000 in overview to break the 2.0x height clamp
        CameraTacMaxZoom = 220,
        CameraTacZoomStep = 22,
        CameraTacClampToTerrain = true,
        CameraTacHeight = not cameraTac.GetIsInOverview() and 220 or 220, -- 5000 in overview to break the 2.0x height clamp
    }

    --cameraTac.SetLookAtAngle(not cameraTac.GetIsInOverview() and hr.CameraTacLookAtAngle or hr.CameraTacLookAtAngleInOverview)
    
    -- Apply to hr table
    for k, v in pairs(settings) do
        hr[k] = v
    end
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
    if state == "set" then
        local instant, target, floor, sleepTime, noFitCheck = ...
        if target then
            if not floor then floor = GetStepFloor(target) end
            SnapCameraToObj(target, "force", floor, sleepTime or 1000)
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
        return
    end
    return old_SetForceMaxZoom(force, ...)
end

-- Hook into messages to ensure settings are applied
function OnMsg.LoadSessionData()
    ApplyCameraSettings()
    UnlockCameraMovement(nil, "unlock_all")
end

-- Clear the cache when loading a new map to prevent jumping to old coordinates
function OnMsg.NewMapLoaded()
    cachedTactical = false
    cachedOverview = false
    ApplyCameraSettings()
    UnlockCameraMovement(nil, "unlock_all")
end

-- Cache state and perform switch in a single message-driven flow
local old_SetOverview = cameraTac.SetOverview
function cameraTac.SetOverview(set, ...)

    -- Cache current state BEFORE switching
    local zoom = cameraTac.GetZoom()
    local pos, lookAt = cameraTac.GetPosLookAt()
    local floor = cameraTac.GetFloor()
    local state = { pos = pos, lookAt = lookAt, floor = floor }

    if cameraTac.GetIsInOverview() then
        cachedOverview = state
        cachedZoomOverview = zoom
    else
        cachedTactical = state
        cachedZoomTactical = zoom
    end

    -- Perform the actual mode switch (engine call)
    local res = old_SetOverview(set, ...)

    -- Trigger hr settings update for the new mode
    ApplyCameraSettings(set)

    -- Restore destination state AFTER switching
    local restore = set and cachedOverview or cachedTactical
    local restoreZoom = set and cachedZoomOverview or cachedZoomTactical

    if restore then cameraTac.SetPosLookAtAndFloor(restore.pos, restore.lookAt, restore.floor, 0) end
    if restoreZoom then cameraTac.SetZoom(restoreZoom, 0) end

    cameraTac.SetLookAtAngle(not cameraTac.GetIsInOverview() and hr.CameraTacLookAtAngle or hr.CameraTacLookAtAngleInOverview)

    return res
end

local old_OnMouseWheelForward = IModeCommonUnitControl.OnMouseWheelForward
function IModeCommonUnitControl:OnMouseWheelForward(...)
    print(string.format("Zoom: %s - InOverview: %s", tostring(cameraTac.GetZoom()), tostring(cameraTac.GetIsInOverview())))
    return old_OnMouseWheelForward(self, ...)
end

local old_OnMouseWheelBack = IModeCommonUnitControl.OnMouseWheelBack
function IModeCommonUnitControl:OnMouseWheelBack(...)    
    print(string.format("Zoom: %s - InOverview: %s", tostring(cameraTac.GetZoom()), tostring(cameraTac.GetIsInOverview())))
    return old_OnMouseWheelBack(self, ...)
end

-- Initial application
ApplyCameraSettings()
UnlockCameraMovement(nil, "unlock_all")
cameraTac.SetForceMaxZoom(false)

print("Camera Done Right mod loaded.")
