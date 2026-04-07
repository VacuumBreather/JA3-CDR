-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

local function ApplyCameraSettings()
    local options = CurrentModOptions
    -- Ensure CurrentModOptions is available and initialized
    if not options or not options.GetProperty then return end

    local zoom_min = options:GetProperty("cdr_zoom_min") or 65
    local zoom_max = options:GetProperty("cdr_zoom_max") or 200
    local zoom_step = options:GetProperty("cdr_zoom_step") or 15
    local pitch_angle = options:GetProperty("cdr_pitch_angle") or 60

    -- Override Tactical Camera Zoom
    hr.CameraTacMinZoom = zoom_min
    hr.CameraTacMaxZoom = zoom_max
    hr.CameraTacZoomStep = zoom_step
    
    -- Override Overview Camera Zoom
    -- We'll scale the overview zoom with the max zoom if not explicitly in options
    -- Use a 1.7x multiplier for overview mode, which is the original game's ratio (220 / 130)
    local zoom_max_overview = zoom_max * 170 / 100
    hr.CameraTacMaxZoomOverview = zoom_max_overview
    
    -- Ensure min zoom in overview is also reasonable, though the engine usually 
    -- uses CameraTacMinZoom. Some versions of the engine might use a separate variable.
    hr.CameraTacMinZoomOverview = zoom_min
    
    -- Override Pitch Angle (LookAtAngle)
    -- hr.CameraTacLookAtAngle is in minutes (degrees * 60)
    hr.CameraTacLookAtAngle = pitch_angle * 60
    
    -- Prevent Clamping
    hr.CameraTacClampToTerrain = true -- Default: true
    
    -- Apply settings to the active camera if possible
    if cameraTac.IsActive() then
        cameraTac.SetupLookAtAngle()
        -- Some changes might require a Normalize or similar to refresh
        cameraTac.Normalize()
    end
end

-- Re-apply settings when options are changed in the menu
function OnMsg.ApplyModOptions(id)
    if id == "Yb7PXyK" then -- Mod ID from metadata.lua
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
        -- Original AdjustCombatCamera calls table.change(hr, ...) and cameraTac.SetForceMaxZoom(true)
        -- We only want the SnapCameraToObj part if a target is provided, so we'll call the original with modified logic
        -- But since we can't easily skip just parts of the original without copying it,
        -- we'll just handle the snap ourselves if needed and skip the rest.
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
        
        -- The original function might have locked the camera or set ForceMaxZoom before this point
        -- depending on how it's called. To be safe, we ensure it's NOT locked so mouse wheel stays active.
        UnlockCameraMovement("CombatCamera")
        cameraTac.SetForceMaxZoom(false)
        
        return
    elseif state == "reset" then
        -- Just ensure our settings are applied after a reset
        local res = old_AdjustCombatCamera(state, ...)
        ApplyCameraSettings()
        return res
    end
    return old_AdjustCombatCamera(state, ...)
end

-- Globally override LockCameraMovement to prevent camera locking during combat
local old_LockCameraMovement = LockCameraMovement
function LockCameraMovement(reason)
    -- We want to prevent any tactical camera movement locking during combat
    -- print("Prevented LockCameraMovement(" .. tostring(reason) .. ")")
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

function OnMsg.CameraTacOverview()
    ApplyCameraSettings()
end

-- Initial application
ApplyCameraSettings()
UnlockCameraMovement(nil, "unlock_all")
cameraTac.SetForceMaxZoom(false)

-- Ensure they persist even if some game code tries to restore them
-- We can also override table.restore or handle it via a recurring timer if necessary,
-- but JA3 usually respects hr settings if they aren't explicitly changed by other code using table.change.
-- Since we disabled SetForceMaxZoom, that covers a major part of the "forced zoom".

print("Camera Done Right mod loaded.")
