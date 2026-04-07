-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

local function ApplyCameraSettings()
    local options = CurrentModOptions
    if not options or not options.GetProperty then return end

    local zoom_min = options:GetProperty("cdr_zoom_min") or 65
    local zoom_max = options:GetProperty("cdr_zoom_max") or 200
    local zoom_step = options:GetProperty("cdr_zoom_step") or 15
    local pitch_angle = options:GetProperty("cdr_pitch_angle") or 60

    local is_overview = cameraTac.GetIsInOverview()
    
    -- In overview, zoom limits are ignored by the engine's C++ input path.
    -- The only way to move the 2200 plateau is to change the base Height.
    local settings = {
        CameraTacMinZoom = zoom_min,
        CameraTacMaxZoom = zoom_max,
        CameraTacZoomStep = zoom_step,
        CameraTacLookAtAngle = is_overview and hr.CameraTacLookAtAngleInOverview or (pitch_angle * 60),
        CameraTacClampToTerrain = true,
        CameraTacHeight = is_overview and 5000 or 1100, -- 5000 in overview to break the 2.0x height clamp
    }
    
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
        cameraTac.SetZoom(1000)
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

-- Clear the cache when loading a new map to prevent jumping to old coordinates
function OnMsg.NewMapLoaded()
    cachedTacticalPos = false
    cachedTacticalZoom = false
    cachedTacticalFloor = false
    cachedOverviewPos = false
    cachedOverviewZoom = false
    cachedOverviewFloor = false
    ApplyCameraSettings()
    UnlockCameraMovement(nil, "unlock_all")
end


-- Local variables to cache camera states
local cachedTacticalPos = false
local cachedTacticalZoom = false
local cachedTacticalFloor = false
local cachedOverviewPos = false
local cachedOverviewZoom = false
local cachedOverviewFloor = false

-- Use a hook on the engine's SetOverview to capture position BEFORE the switch happens
local old_SetOverview = cameraTac.SetOverview
local in_set_overview = false
function cameraTac.SetOverview(set, ...)
    if in_set_overview then return old_SetOverview(set, ...) end
    in_set_overview = true
    
    if set then
        -- ENTERING Overview: Capture current Tactical state (Pos and Zoom)
        local pos, lookAt = cameraTac.GetPosLookAt()
        cachedTacticalPos = { pos, lookAt }
        cachedTacticalZoom = cameraTac.GetZoom()
        cachedTacticalFloor = cameraTac.GetFloor()
    else
        -- LEAVING Overview: Capture current Overview state (Pos and Zoom)
        local pos, lookAt = cameraTac.GetPosLookAt()
        cachedOverviewPos = { pos, lookAt }
        cachedOverviewZoom = cameraTac.GetZoom()
        cachedOverviewFloor = cameraTac.GetFloor()
    end
    
    local res = old_SetOverview(set, ...)
    
    -- After the engine switches, apply our mod's limits (height 5000, etc.)
    ApplyCameraSettings()
    
    -- Now restore only the position and zoom for the destination state
    if set and cachedOverviewPos then
        local pos, lookAt = cachedOverviewPos[1], cachedOverviewPos[2]
        cameraTac.SetPosLookAtAndFloor(pos, lookAt, cachedOverviewFloor or 0, 0)
        if cachedOverviewZoom then cameraTac.SetZoom(cachedOverviewZoom) end
    elseif not set and cachedTacticalPos then
        local pos, lookAt = cachedTacticalPos[1], cachedTacticalPos[2]
        cameraTac.SetPosLookAtAndFloor(pos, lookAt, cachedTacticalFloor or 0, 0)
        if cachedTacticalZoom then cameraTac.SetZoom(cachedTacticalZoom) end
    end
    
    in_set_overview = false
    return res
end

function OnMsg.CameraTacOverview(set)
    -- This message is now just a backup to ensure settings are applied
    ApplyCameraSettings()
end

-- Initial application
ApplyCameraSettings()
UnlockCameraMovement(nil, "unlock_all")
cameraTac.SetForceMaxZoom(false)

print("Camera Done Right mod loaded.")
