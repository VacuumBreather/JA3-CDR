return {
	PlaceObj('ModItemOptionNumber', {
		'name', "cdr_zoom_min",
		'DisplayName', "Min Zoom",
		'DefaultValue', 65,
		'MinValue', 10,
		'StepSize', 5,
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "cdr_zoom_max",
		'DisplayName', "Max Zoom",
		'DefaultValue', 200,
		'MinValue', 100,
		'MaxValue', 400,
		'StepSize', 5,
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "cdr_zoom_step",
		'DefaultValue', 15,
		'MinValue', 5,
		'MaxValue', 50,
		'StepSize', 5,
	}),
	PlaceObj('ModItemOptionNumber', {
		'name', "cdr_pitch_angle",
		'DisplayName', "Pitch Angle",
		'DefaultValue', 60,
		'MinValue', 45,
		'MaxValue', 75,
		'StepSize', 5,
	}),
	PlaceObj('ModItemCode', {
		'CodeFileName', "Code/Script.lua",
	}),
}