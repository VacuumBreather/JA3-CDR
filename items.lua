return {
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_tactical_min",
		'DisplayName', "Min Zoom Height (Tactical)",
		'DefaultValue', "100",
		'ChoiceList', {"10", "20", "50", "100", "150", "200", "300", "400", "500", "600", "700", "800", "900", "1000"},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_tactical_max",
		'DisplayName', "Max Zoom Height (Tactical)",
		'DefaultValue', "1100",
		'ChoiceList', {"1000", "1100", "1250", "1500", "1750", "2000", "2250", "2500", "2750", "3000"},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_overview_min",
		'DisplayName', "Min Zoom Height (Overview)",
		'DefaultValue', "100",
		'ChoiceList', {"10", "20", "50", "100", "150", "200", "300", "400", "500", "600", "700", "800", "900", "1000"},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_overview_max",
		'DisplayName', "Max Zoom Height (Overview)",
		'DefaultValue', "1100",
		'ChoiceList', {"1000", "1100", "1250", "1500", "1750", "2000", "2250", "2500", "2750", "3000", "3500", "4000", "4500", "5000"},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_zoom_step",
		'DisplayName', "Zoom Step",
		'DefaultValue', "15",
		'ChoiceList', {"5", "10", "15", "20", "25", "30", "35", "40", "45", "50"},
	}),
	PlaceObj('ModItemOptionChoice', {
		'name', "cdr_pitch_angle",
		'DisplayName', "Pitch Angle",
		'DefaultValue', "60",
		'ChoiceList', {"45", "50", "55", "60", "65", "70", "75"},
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_AdjustCombatCamera",
		'DisplayName', "Maintain Custom Zoom During Combat",
		'Help', "Prevents the game from overriding custom zoom levels and camera settings during the enemy turn.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_CinematicCamera",
		'DisplayName', "Disable Cinematic Kill-Cams",
		'Help', "Specifically disables close-up cinematic shots (kill-cams) during attacks.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_CombatCamera",
		'DisplayName', "Disable Tactical Zoom during Attacks",
		'Help', "Prevents the tactical camera from zooming in and following attacker/target during combat actions.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_LockCameraMovement",
		'DisplayName', "Free Camera Movement in Combat",
		'Help', "Allows you to move and rotate the camera freely during combat, even when the game tries to lock it.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_SetForceMaxZoom",
		'DisplayName', "Allow Zooming During Actions",
		'Help', "Prevents the game from forcing a specific zoom level during certain actions.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_SetOverview",
		'DisplayName', "Remember Zoom/Pos Between Modes",
		'Help', "Caches and restores camera position and zoom when switching between Tactical and Overview modes.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_SnapCameraEnemyTurn",
		'DisplayName', "Disable Camera Snapping (Enemy Turn)",
		'Help', "Prevents the camera from automatically jumping to enemies when they move or act during their turn.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemOptionToggle', {
		'name', "cdr_toggle_SnapCameraPlayerActions",
		'DisplayName', "Disable Camera Snapping (Player Actions)",
		'Help', "Prevents the camera from jumping while you are aiming, moving, or preparing attacks.",
		'DefaultValue', true,
	}),
	PlaceObj('ModItemCode', {
		'CodeFileName', "Code/Script.lua",
	}),
	PlaceObj('ModItemLocTable', {
		'language', "English",
		'filename', "Languages/en.csv",
	}),
}