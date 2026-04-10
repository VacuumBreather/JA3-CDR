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
	if not g_Combat then
		return false, false
	end

	if ShouldForceCinematic(attacker) then
		if attacker:IsLocalPlayerTeam() then
			return "forced", true
		else
			local target = attack_args.target
			if IsKindOf(target, "Unit") and target:IsLocalPlayerTeam() then
				return "forced", true
			end
			-- For AI on AI, trigger it manually here and return false to avoid vanilla skipping it
			SetAutoRemoveActionCamera(attacker, target, false, false, 0, 0)
			return false, false
		end
	end

    return cdr_old_IsCinematicAttack(attacker, results, attack_args, action, ...)
end

local cdr_old_CalcActionCamera = CalcActionCamera
function CalcActionCamera(attacker, target, cam_positioning, force_fp, no_rotate)
	local options = CurrentModOptions
	local mode = options and options:GetProperty("cdr_CinematicCameraMode")

	if mode == mode_Never then
		return false, false, false, true
	end

    return cdr_CalcActionCamera(attacker, target, cam_positioning, force_fp, false)
end

local hide_nearby_objs = {"Shrub", "SlabWallObject"}
local buffer = point(guim, guim, guim)

local function cdr_lIsActionCameraHideableObject(cam_pos, o)
	if IsKindOf(o, "SlabWallObject") then
		if o:IsDoor() or not ActionCameraShouldHideWindow(cam_pos, o) then
			return false
		end
	end

	return IsKindOfClasses(o, hide_nearby_objs)
end

local cdr_isAiming = false
local cdr_old_SetActionCameraNoFallback = SetActionCameraNoFallback
function SetActionCameraNoFallback(...)
	local old_isAiming = cdr_isAiming
	cdr_isAiming = true
	local res = cdr_old_SetActionCameraNoFallback(...)
	cdr_isAiming = old_isAiming
	return res
end

function cdr_CalcActionCamera(attacker, target, cam_positioning, force_fp, no_rotate)
	no_rotate = no_rotate or false
	local fp_cam

	if force_fp then
		fp_cam = GetFPCameraFromPreset(attacker, target, Presets.ActionCameraDef.Default.FirstPerson_Cam, no_rotate)
		return fp_cam[1], fp_cam[2], fp_cam[3]
	end

	local valid_cameras = {}
	local output = {
		sources = {},
		dests = {}, --target pt
		targets = {}, --target obj
		cameras = {},
		test_to_cam = {},
	}

	local sources = output.sources
	local dests = output.dests
	local test_to_cam = output.test_to_cam
	local targets = output.targets
	local cameras = output.cameras
	local stance = attacker.stance

	if #(stance or "") == 0 then
		stance = "Crouch" -- attacker.species ~= "Human"
	end

	for _, preset in ipairs(Presets.ActionCameraDef.Default) do
		local isHigherCam = preset.id == "Z_HigherCamera"
		assert(preset:HasMember(stance), "Invalid stance in ActionCameraDef properties")

		if preset[stance] and not preset.SetPieceOnly and not isHigherCam then
			if preset.id == "FirstPerson_Cam" then
				fp_cam = GetFPCameraFromPreset(attacker, target, preset, no_rotate)
			else
				GetACamsForPreset(attacker, target, preset, cam_positioning, no_rotate, output)
				
				if not cdr_isAiming then
					GetACamsForPreset(target, attacker, preset, cam_positioning, no_rotate, output)
				end
			end
		end
	end

	if #sources > 0 then
		ACVisibilityBatchTest(sources, dests,
			function(obj, idx, pos, dist)
				local src = sources[idx]

				if VisionCollisionFilter(obj) and not cdr_lIsActionCameraHideableObject(src, obj) and obj ~= target then
					local cam = test_to_cam[idx]
					local obstacles = cam[4]
					obstacles[#obstacles + 1] = obj
					obstacles.min_dist = Min(obstacles.min_dist, dist)

					if targets[idx] == target then
						obstacles.target_visible = false
					end
				end
			end)

		for i, cam in ipairs(cameras) do
			if cam[3].id ~= "Z_HigherCamera" then
				local obstacles = cam[4]

				if #obstacles <= 0 then
					--test for units blocking view
					local j = cam.begin_idx + 1
					while test_to_cam[j] == cam do
						local s, d = sources[j], dests[j]
						local min = point(Min(s:x(), d:x()), Min(s:y(), d:y()), Min(s:z(), d:z())) - buffer
						local max = point(Max(s:x(), d:x()), Max(s:y(), d:y()), Max(s:z(), d:z())) + buffer
						local b = box(min, max)
						MapForEach(b, "Unit", function(unit)
							if unit ~= target and unit ~= attacker and ClipSegmentWithBox3D(sources[j], dests[j], unit) then
								obstacles[#obstacles + 1] = unit
								obstacles.target_visible = false

								return "break"
							end
						end)

						if not obstacles.target_visible then
							break
						end

						j = j + 1
					end

					if #obstacles <= 0 then
						valid_cameras[#valid_cameras + 1] = cam
					end
				end
			end
		end
	end

	if #valid_cameras > 0 then
		local seed = xxhash(IsPoint(attacker) and attacker or attacker:GetPos(), GetActionCameraTargetPos(target))
		local rand = BraidRandom(seed, #valid_cameras)
		local camera = valid_cameras[1 + rand]

		return camera[1], camera[2], camera[3]
	end

	local tie
	local best_match

	for i = 1, #cameras do
		local cam = cameras[i]
		if cam[4].target_visible then
			if not best_match then
				best_match = cam
			elseif #cam[4] < #best_match[4] then
				best_match = cam
				tie = false
			elseif #cam[4] == #best_match[4] then
				tie = #cam[4]
			end
		end
	end

	if tie then
		for i = 1, #cameras do
			local cam = cameras[i]
			local col_cam = cam[4]
			if #col_cam == tie then
				local col_best_match = best_match[4]
				if col_cam.min_dist > col_best_match.min_dist then
					best_match = cam
				end
			end
		end
	end

    assert(fp_cam)

    local fallback = not best_match
	best_match = best_match or fp_cam

	return best_match[1], best_match[2], best_match[3], fallback
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


local cdr_old_ExecFirearmAttacks = Unit.ExecFirearmAttacks
function Unit:ExecFirearmAttacks(...)
	self:PushDestructor(function(self)
		if ActionCameraPlaying then
			-- Capture the current camera session to avoid race conditions.
			-- This ensures that a delayed signal from this attack won't 
			-- accidentally close a new camera from a subsequent attack.
			local session = CurrentActionCamera
			CreateGameTimeThread(function()
				Sleep(1000)
				if CurrentActionCamera == session then
					Msg("ActionCameraWaitSignalEnd")
				end
			end)
		end
	end)
	local res = cdr_old_ExecFirearmAttacks(self, ...)
	self:PopAndCallDestructor()
	return res
end

local cdr_old_SnapCameraToObj = SnapCameraToObj
function SnapCameraToObj(obj, mode, floor, time, easing, ...)
    local options = CurrentModOptions
    if options then
        if options:GetProperty("cdr_toggle_SnapCameraEnemyTurn") and g_AIExecutionController then
            return
        end

        if options:GetProperty("cdr_toggle_SnapCameraPlayerActions") then
            local igiMode = GetInGameInterfaceMode() or ""
            if igiMode == "IModeCombatAttack" or
               igiMode == "IModeCombatMovement" or
               igiMode == "IModeCombatAreaAim" then
                return
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