-- Mod: Camera Done Right
-- Overrides min and max zoom for tactical and overview cameras, prevents clamping,
-- prevents forced zoom due to combat actions, and allows overriding the camera pitch angle.

-- Persist camera zoom values in savegame
GameVar("gv_CDR_ZoomTactical", false)
GameVar("gv_CDR_ZoomOverview", false)

local cache_Tactical = false
local cache_Overview = false

local mode_Default = "Default"
local mode_Never = "Never"
local mode_AlwaysPlayer = "Always for Player"
local mode_AlwaysAI = "Always for Player and AI"

local function ApplyCameraSettings(forced_overview)
    local options = CurrentModOptions
    if not options or not options.GetProperty then return end

	-- Migrate old boolean option if present
	local old_toggle = rawget(options, "cdr_toggle_CinematicCamera")
	if old_toggle ~= nil then
		local current_mode = options:GetProperty("cdr_CinematicCameraMode")
		if current_mode == mode_Default then
			local new_mode = old_toggle and mode_Never or mode_Default
			options:SetProperty("cdr_CinematicCameraMode", new_mode)
		end
		-- Clear the old property from raw table so we don't migrate again
		rawset(options, "cdr_toggle_CinematicCamera", nil)
	end

    local tactical_min = tonumber(options:GetProperty("cdr_tactical_min")) or 100
    local tactical_max = tonumber(options:GetProperty("cdr_tactical_max")) or 1100
    
    local overview_min = tonumber(options:GetProperty("cdr_overview_min")) or 100
    local overview_max = tonumber(options:GetProperty("cdr_overview_max")) or 1100

    local zoom_min_tactical = (tactical_min * 220) / tactical_max
    local zoom_min_overview = (overview_min * 220) / overview_max
    local zoom_max = 220
    local zoom_step = tonumber(options:GetProperty("cdr_zoom_step")) or 15

    local pitch_angle = tonumber(options:GetProperty("cdr_pitch_angle")) or 55

    local is_overview = forced_overview
    if is_overview == nil then
        is_overview = cameraTac.GetIsInOverview()
    end
    
    local settings = {
        CameraTacMinZoom = cameraTac.GetIsInOverview() and zoom_min_overview or zoom_min_tactical,
        CameraTacMaxZoom = zoom_max,
        CameraTacZoomStep = zoom_step,
        CameraTacClampToTerrain = true,
        CameraTacHeight = cameraTac.GetIsInOverview() and overview_max or tactical_max,
        CameraTacLookAtAngle = pitch_angle * 60,
    }
    
    -- Apply to hr table
    for k, v in pairs(settings) do
        hr[k] = v
    end

    UnlockCameraMovement(nil, "unlock_all")
    cameraTac.SetForceMaxZoom(false)
end

-- Hook AdjustCombatCamera to prevent the game from overriding our camera settings during the enemy turn
local cdr_old_AdjustCombatCamera = AdjustCombatCamera
function AdjustCombatCamera(state, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_AdjustCombatCamera") then
        if state == "set" then
            local instant, target, floor, sleepTime, noFitCheck = ...
            if target then
                if not floor then floor = GetStepFloor(target) end
                SnapCameraToObj(target, "force", floor, sleepTime or 1000)
            end
            return
        end
        local res = cdr_old_AdjustCombatCamera(state, ...)
        ApplyCameraSettings()
        return res
    else
        return cdr_old_AdjustCombatCamera(state, ...)
    end
end

local cdr_old_StartCinematicCombatCamera = StartCinematicCombatCamera
function StartCinematicCombatCamera(attacker, target, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_CombatCamera") then
        return
    end
    return cdr_old_StartCinematicCombatCamera(attacker, target, ...)
end

local cdr_old_CombatCam_ShowAttack = CombatCam_ShowAttack
function CombatCam_ShowAttack(attacker, target, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_CombatCamera") then
        return
    end
    return cdr_old_CombatCam_ShowAttack(attacker, target, ...)
end

local cdr_old_CombatCam_ShowAttackNew = CombatCam_ShowAttackNew
function CombatCam_ShowAttackNew(attacker, target, willBeinterrupted, results, freezeCamPos, changeFloorOnly, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_CombatCamera") then
        return
    end
    return cdr_old_CombatCam_ShowAttackNew(attacker, target, willBeinterrupted, results, freezeCamPos, changeFloorOnly, ...)
end

local cdr_old_SetActionCameraDirect = SetActionCameraDirect
function SetActionCameraDirect(...)
	local options = CurrentModOptions
	local mode = options and options:GetProperty("cdr_CinematicCameraMode")
	if mode == mode_Never then
		return
	end
	return cdr_old_SetActionCameraDirect(...)
end

local cdr_old_SetActionCamera = SetActionCamera
function SetActionCamera(...)
	local options = CurrentModOptions
	local mode = options and options:GetProperty("cdr_CinematicCameraMode")
	if mode == mode_Never then
		return
	end
	return cdr_old_SetActionCamera(...)
end

local cdr_old_CalcActionCamera = CalcActionCamera
function CalcActionCamera(...)
	local options = CurrentModOptions
	local mode = options and options:GetProperty("cdr_CinematicCameraMode")
	if mode == mode_Never then
		return false, false, false, true
	end
	return cdr_old_CalcActionCamera(...)
end

local function ShouldForceCinematic(attacker)
	local options = CurrentModOptions
	local mode = options and options:GetProperty("cdr_CinematicCameraMode")
	if mode == mode_AlwaysAI then
		return true
	elseif mode == mode_AlwaysPlayer then
		return attacker and attacker:IsLocalPlayerTeam()
	end
	return false
end

local cdr_old_IsEnemyKillCinematic = IsEnemyKillCinematic
function IsEnemyKillCinematic(attacker, results, attack_args, ...)
	if ShouldForceCinematic(attacker) then
		return "forced", false
	end
	return cdr_old_IsEnemyKillCinematic(attacker, results, attack_args, ...)
end

local cdr_old_IsCinematicAttack = IsCinematicAttack
function IsCinematicAttack(attacker, results, attack_args, action, ...)
	if ShouldForceCinematic(attacker) then
		return "forced", true
	end
	return cdr_old_IsCinematicAttack(attacker, results, attack_args, action, ...)
end

local cdr_old_IsCinematicTargeting = IsCinematicTargeting
function IsCinematicTargeting(attacker, target, action, ...)
	if ShouldForceCinematic(attacker) then
		return true
	end
	return cdr_old_IsCinematicTargeting(attacker, target, action, ...)
end

local cdr_old_LockCameraMovement = LockCameraMovement
function LockCameraMovement(reason, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_LockCameraMovement") then
        -- We want to prevent tactical camera movement locking during combat
        return
    end
    return cdr_old_LockCameraMovement(reason, ...)
end


local cdr_old_SnapCameraToObj = SnapCameraToObj
function SnapCameraToObj(obj, mode, floor, time, easing, ...)
    local options = CurrentModOptions
    if options then
        if options:GetProperty("cdr_toggle_SnapCameraEnemyTurn") and g_AIExecutionController then
            return
        end
        
        if options:GetProperty("cdr_toggle_SnapCameraPlayerActions") then
            local igiModeDlg = GetInGameInterfaceModeDlg()
            if igiModeDlg then
                local modeClass = igiModeDlg.class
                if modeClass:find("Attack") or      
                   modeClass:find("Moving") or      
                   modeClass:find("Aim") or         
                   modeClass:find("AreaAim") then  
                    return
                 end
             end
        end
    end
    return cdr_old_SnapCameraToObj(obj, mode, floor, time, easing, ...)
end

local cdr_old_SetForceMaxZoom = cameraTac.SetForceMaxZoom
function cameraTac.SetForceMaxZoom(force, ...)
    local options = CurrentModOptions
    if options and options:GetProperty("cdr_toggle_SetForceMaxZoom") then
        if force then
            -- Do nothing to prevent the game from forcing a zoom level/locking zoom
            return
        end
    end
    return cdr_old_SetForceMaxZoom(force, ...)
end

local cdr_old_SetOverview = cameraTac.SetOverview
function cameraTac.SetOverview(set, ...)
    local options = CurrentModOptions
    if not options or not options:GetProperty("cdr_toggle_SetOverview") then
        local res = cdr_old_SetOverview(set, ...)
        ApplyCameraSettings(set)
        return res
    end

    -- Cache current state BEFORE switching
    local zoom = cameraTac.GetZoom()
    local pos, lookAt = cameraTac.GetPosLookAt()
    local floor = cameraTac.GetFloor()
    local state = { pos = pos, lookAt = lookAt, floor = floor }

    if cameraTac.GetIsInOverview() then
        cache_Overview = state
        gv_CDR_ZoomOverview = zoom
    else
        cache_Tactical = state
        gv_CDR_ZoomTactical = zoom
    end

    -- Perform the actual mode switch (engine call)
    local res = cdr_old_SetOverview(set, ...)

    -- Trigger hr settings update for the new mode
    ApplyCameraSettings(set)

    -- Restore destination state AFTER switching
    local restore = set and cache_Overview or cache_Tactical
    local restoreZoom = set and gv_CDR_ZoomOverview or gv_CDR_ZoomTactical

    if restore then cameraTac.SetPosLookAtAndFloor(restore.pos, restore.lookAt, restore.floor, 0) end
    if restoreZoom then cameraTac.SetZoom(restoreZoom, 0) end

    cameraTac.SetLookAtAngle(not cameraTac.GetIsInOverview() and hr.CameraTacLookAtAngle or hr.CameraTacLookAtAngleInOverview)

    return res
end

-- Initializes attack state for a brand new campaign.
function OnMsg.InitSessionCampaignObjects()
    cache_Tactical = false
    cache_Overview = false
    ApplyCameraSettings()
end

-- Hook into messages to ensure settings are applied
function OnMsg.LoadSessionData()
    cache_Tactical = false
    cache_Overview = false
    ApplyCameraSettings()
end

-- Clear the cache when loading a new map to prevent jumping to old coordinates
function OnMsg.NewMapLoaded()
    cache_Tactical = false
    cache_Overview = false
    ApplyCameraSettings()
end

-- Re-apply settings when options are changed in the menu
function OnMsg.ApplyModOptions(id)
    if id == CurrentModId then
        ApplyCameraSettings()
    end
end
