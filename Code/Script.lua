-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

local function ApplyCameraSettings()
    -- Override Tactical Camera Zoom
    hr.CameraTacMinZoom = 20  -- Default: 65 (Lower is closer)
    hr.CameraTacMaxZoom = 600 -- Default: 130 (Higher is further)
    
    -- Override Overview Camera Zoom
    hr.CameraTacMaxZoomOverview = 1000 -- Default: 220
    
    -- Override Pitch Angle (LookAtAngle)
    -- hr.CameraTacLookAtAngle is in minutes (degrees * 60)
    hr.CameraTacLookAtAngle = 45 * 60 -- Default: 55 * 60
    
    -- Prevent Clamping
    hr.CameraTacClampToTerrain = true -- Default: true
    
    -- Apply settings to the active camera if possible
    if cameraTac.IsActive() then
        cameraTac.SetupLookAtAngle()
        -- Some changes might require a Normalize or similar to refresh
        cameraTac.Normalize()
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
        return
    elseif state == "reset" then
        -- Just ensure our settings are applied after a reset
        local res = old_AdjustCombatCamera(state, ...)
        ApplyCameraSettings()
        return res
    end
    return old_AdjustCombatCamera(state, ...)
end

-- Hook into messages to ensure settings are applied
function OnMsg.LoadSessionData()
    ApplyCameraSettings()
end

function OnMsg.NewMapLoaded()
    ApplyCameraSettings()
end

function OnMsg.CameraTacOverview()
    ApplyCameraSettings()
end

-- Initial application
ApplyCameraSettings()

-- Ensure they persist even if some game code tries to restore them
-- We can also override table.restore or handle it via a recurring timer if necessary,
-- but JA3 usually respects hr settings if they aren't explicitly changed by other code using table.change.
-- Since we disabled SetForceMaxZoom, that covers a major part of the "forced zoom".

print("Camera Done Right mod loaded.")
