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

    local zoom_max_overview = zoom_max * 170 / 100
    
    local settings = {
        CameraTacMinZoom = zoom_min,
        CameraTacMaxZoom = zoom_max,
        CameraTacZoomStep = zoom_step,
        CameraTacMaxZoomOverview = zoom_max_overview,
        CameraTacMinZoomOverview = zoom_min,
        CameraTacLookAtAngle = pitch_angle * 60,
        CameraTacLookAtAngleInOverview = pitch_angle * 60,
        CameraTacClampToTerrain = true,
    }

    -- Apply directly to hr
    for k, v in pairs(settings) do
        hr[k] = v
    end
    
    -- Update all active table.change stacks for hr to ensure our values are treated as the "base" or "current" 
    -- and won't be restored to old defaults.
    -- (This part is safe as it doesn't override the table functions themselves)
    if _G.table_change_stack and _G.table_change_stack[hr] then
        for _, entry in ipairs(_G.table_change_stack[hr]) do
            for k, v in pairs(settings) do
                if entry.old[k] ~= nil then
                    entry.old[k] = v
                end
                if entry.new[k] ~= nil then
                    entry.new[k] = v
                end
            end
        end
    end

    -- Apply settings to the active camera if possible
    if cameraTac.IsActive() then
        cameraTac.SetupLookAtAngle()
        cameraTac.Normalize()
    end
end

-- Re-apply settings when options are changed in the menu
function OnMsg.ApplyModOptions(id)
    if id == CurrentModId then
        ApplyCameraSettings()
    end
end

-- Hook cameraTac functions to ensure our settings are persistent
local function HookCameraTac(func_name)
    local old_func = cameraTac[func_name]
    if old_func then
        cameraTac[func_name] = function(...)
            -- Apply BEFORE engine might read hr (e.g. for SetZoom bounds)
            ApplyCameraSettings() 
            local res = old_func(...)
            -- Re-apply to fix any clamping done by the engine
            ApplyCameraSettings()
            return res
        end
    end
end

-- Hook cameraTac.SetOverview specifically to handle hr.CameraTacLookAtAngleInOverview
local old_SetOverview = cameraTac.SetOverview
if old_SetOverview then
    cameraTac.SetOverview = function(overview, ...)
        ApplyCameraSettings() -- Apply BEFORE engine might read hr
        local res = old_SetOverview(overview, ...)
        -- SetOverview often triggers SetupLookAtAngle and Normalize internally
        ApplyCameraSettings() -- Apply AFTER engine might have changed something
        return res
    end
end

-- HookCameraTac("SetZoom")
-- HookCameraTac("Normalize")
-- HookCameraTac("SetupLookAtAngle")
-- HookCameraTac("SetFloor")

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
        
        UnlockCameraMovement("CombatCamera")
        cameraTac.SetForceMaxZoom(false)
        
        return
    elseif state == "reset" then
        local instant, target, floor, sleepTime, noFitCheck = ...
        -- We must keep the original reset logic for hr and cameraTac
        -- but immediately override it with our settings
        old_AdjustCombatCamera(state, ...)
        ApplyCameraSettings()
        return
    end
    return old_AdjustCombatCamera(state, ...)
end

-- Globally override LockCameraMovement to prevent camera locking during combat
local old_LockCameraMovement = LockCameraMovement
function LockCameraMovement(reason)
    if reason == "CombatCamera" or reason == "CivilianTurn" or reason == "pindown" or reason == "bombard" or reason == "grunty perk" or reason == "TimedExplosives" then
        -- We want to prevent these tactical camera movement locking during combat
        return
    end
    return old_LockCameraMovement(reason)
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

print("Camera Done Right mod loaded.")
