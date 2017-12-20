--local _ENV = mkmodule('dorf_tables')
local O = 0
job_distributions = {
	Thresholds		= {	7,	14,	21,	28,	35,	42,	49,	56,	63,	70,	77,	138	}, --Don't touch unless you wanna recalculate the distributions
	Miner			= {	2,	1,	O,	1,	O,	2,	O,	O,	O,	1,	O,	3; cur = 0; max = nil }, --10
	_Grunt			= {	O,	1,	1,	O,	O,	1,	O,	2,	O,	2,	O,	7; cur = 0; max = nil }, --14
	Smelter			= {	O,	O,	1,	O,	1,	1,	O,	1,	O,	O,	O,	3; cur = 0; max = nil }, --7
	Blacksmith		= {	O,	O,	O,	1,	O,	1,	O,	1,	O,	O,	1,	2; cur = 0; max = nil }, --6

	Stoneworker		= {	1,	1,	1,	O,	1,	O,	1,	O,	O,	2,	O,	3; cur = 0; max = nil }, --10
	Woodworker		= {	1,	O,	O,	1,	O,	O,	1,	O,	O,	O,	O,	4; cur = 0; max = nil }, --7
	Architect		= {	O,	1,	O,	O,	1,	O,	1,	O,	1,	1,	O,	5; cur = 0; max = nil }, --10

	Farmer			= {	1,	O,	1,	1,	O,	O,	O,	1,	O,	O,	O,	5; cur = 0; max = nil }, --10
	Clothier		= {	O,	1,	O,	O,	1,	1,	O,	1,	O,	O,	O,	4; cur = 0; max = nil }, --8
	Warden			= {	1,	O,	O,	1,	O,	O,	O,	O,	1,	O,	O,	2; cur = 0; max = nil }, --5
	Hunter			= {	O,	O,	O,	1,	O,	O,	O,	1,	O,	O,	O,	2; cur = 0; max = nil }, --4
	Butcher			= {	O,	O,	O,	1,	O,	O,	1,	O,	O,	O,	O,	2; cur = 0; max = nil }, --4

	Artison			= {	O,	1,	1,	O,	O,	1,	2,	O,	O,	O,	6,	3; cur = 0; max = nil }, --14
	Doctor			= {	O,	O,	1,	O,	1,	O,	O,	O,	2,	O,	O,	4; cur = 0; max = nil }, --8
	Leader			= {	1,	O,	O,	O,	1,	O,	O,	O,	1,	O,	O,	4; cur = 0; max = nil }, --7
	Trader			= {	O,	1,	O,	O,	O,	O,	1,	O,	O,	O,	O,	2; cur = 0; max = nil }, --4
	Engineer		= {	O,	O,	1,	O,	1,	O,	O,	O,	2,	O,	O,	6; cur = 0; max = nil }  --10
}

attrib_levels = {
	incompetent =	{p=0.02,	100,	20},
	verybad =		{p=0.04,	250,	25},
	bad =			{p=0.08,	450,	30},
	average =		{p=0.18,	810,	60},
	good =			{p=0.24,	1350,   75},
	verygood =		{p=0.22,	1700,   42},
	superb =		{p=0.12,	1900,   88},
	amazing =		{p=0.06,	2900,   188},
	incredible =	{p=0.03,	3800,   242},
	unbelievable =	{p=0.01,	4829,   42}
}

dorf_jobs = {
	Miner = {
		req={'MINER'},
		types={'adaptable','fighter','strong','strong','agile','aware','resilient'}},
	_Grunt = {
		req={'RECRUIT'},
		types={'adaptable','fighter','soldier','strong','agile','aware','resilient','strong','agile','aware','resilient','strong','agile','aware','resilient'}},
	Smelter = {
		req={'FURNACE_OPERATOR','WOOD_BURNER'},
		types={'fighter','agile','buff','aware','resilient','resilient','resilient'}},
	Blacksmith = {
		req={'BLACKSMITH'},
		WEAPONSMITH=0.75, ARMORER=0.7, METALSMITH=0.66, BOWYER=0.33,
		types={'buff','buff','intuitive','aware'}},

	Stoneworker = {
		req={'STONEWORKER'},
		ENGRAVER=0.75, MASON=0.66, MECHANIC=0.6,
		types={'buff','speedy','aware','resilient'}},
	Woodworker = {
		req={'WOODWORKER'},
		WOODCUTTER=0.8, CARPENTER=0.7, BOWYER=0.6,
		types={'agile','agile','social','smart','creative'}},
	Architect = {
		req={'ARCHITECT'},
		MASON=0.75, CARPENTER=0.75, MECHANIC=0.66,
		types={'genius','creative','speedy'}},

	Farmer = {
		req={'PLANTER'},
		BREWER=0.65, FARMER=0.51, POTASH_MAKER=0.45, MILLER=0.25, MILKER=0.25, CHEESE_MAKER=0.25, SHEARER=0.15,
		types={'speedy','aware','intuitive'}},
	Clothier = {
		req={'CLOTHIER'},
		THRESHER=0.75, WEAVER=0.66, SPINNER=0.66, LEATHERWORKER=0.5, DYER=0.25,
		types={'speedy','speedy','social'}},
	Warden = {
		req={'ANIMAL_CARETAKER'},
		SHEARER=0.88, ANIMAL_TRAINER=0.8, MILKER=0.75, CHEESE_MAKER=0.41, TANNER=0.38, BUTCHER=0.25, BONE_CARVER=0.28,
		types={'aware','social','speedy','buff'}},		
	Hunter = {
		req={'HUNTER','RANGER'},
		TANNER=0.88, HERBALIST=0.75, BUTCHER=0.66, TRAPPER=0.55,
		types={'buff','agile','agile','agile','aware','intuitive','smart'}},
	Butcher = {
		req={'BUTCHER'},
		TANNER=0.75, COOK=0.66, BONE_CARVER=0.55,
		types={'buff','speedy','aware'}},

	Artison = {
		req={'CRAFTSMAN'},
		ENGRAVER=0.8, WOODCRAFTER=0.6, STONECRAFTER=0.4, JEWELER=0.4, GEM_CUTTER=0.4, GEM_SETTER=0.4, BONE_CARVER=0.2, POTTER=0.2,
		types={'agile','agile','smart','creative','social','resilient'}},
	Doctor = {
		req={'DOCTOR'},
		SUTURER=0.8, SURGEON=0.66, BONE_SETTER=0.42, DIAGNOSER=0.42,
		types={'smart','aware','agile','social','resilient'}},
	Leader = {
		req={'ADMINISTRATOR'},
		FARMER=0.38, BREWER=0.51, CLERK=0.33, ENGRAVER=0.51, MERCHANT=0.33, SIEGE_OPERATOR=0.66, PUMP_OPERATOR=0.33, FURNACE_OPERATOR=0.33, WOOD_BURNER=0.47,
		types={'leader','smart','social','fighter'}},
	Trader = {
		req={'TRADER'},
		CLERK=0.75, MERCHANT=0.75, ADMINISTRATOR=0.42, JEWELER=0.51, CRAFTSMAN=0.33,
		types={'smart','social'}},
	Engineer = {
		req={'ENGINEER'},
		SIEGE_ENGINEER=0.88, MECHANIC=0.88, METALSMITH=0.33,
		types={'genius','intuitive'}}
}

professions = {
	MINER = 			{ skills = {MINING=3} },
	RECRUIT = 			{ skills = {KNOWLEDGE_ACQUISITION=2, INTIMIDATION=1, DISCIPLINE=3} },
	FURNACE_OPERATOR = 	{ skills = {SMELT=3} },
	WOOD_BURNER = 		{ skills = {WOOD_BURNING=2} },
	BLACKSMITH = 		{ skills = {FORGE_WEAPON=4, FORGE_ARMOR=3} },

	STONEWORKER = 		{ skills = {MASONRY=3, STONECRAFT=2} },
	WOODWORKER = 		{ skills = {CARPENTRY=3, WOODCRAFT=1} },
	ARCHITECT = 		{ skills = {DESIGNBUILDING=3, MASONRY=2, CARPENTRY=1} },

	PLANTER = 			{ skills = {PLANT=3, POTASH_MAKING=2} },
	CLOTHIER = 			{ skills = {CLOTHESMAKING=2, WEAVING=1, PROCESSPLANTS=1} },
	ANIMAL_CARETAKER = 	{ skills = {ANIMALCARE=3, SHEARING=2, MILK=1, ANIMALTRAIN=1} },
	HUNTER = 			{ skills = {SNEAK=3, TRACKING=4, RANGED_COMBAT=2, CROSSBOW=1} },
	RANGER = 			{ skills = {ANIMALCARE=3, ANIMALTRAIN=3, CROSSBOW=2, SNEAK=2, TRAPPING=2} },
	BUTCHER = 			{ skills = {BUTCHER=3, TANNER=2, COOK=1, GELD=-3} },

	CRAFTSMAN = 		{ skills = {WOODCRAFT=1, STONECRAFT=1, METALCRAFT=1} },
	DOCTOR = 			{ skills = {DRESS_WOUNDS=3, SUTURE=2, CRUTCH_WALK=1} },
	ADMINISTRATOR = 	{ skills = {RECORD_KEEPING=3, ORGANIZATION=2, APPRAISAL=1} },
	TRADER = 			{ skills = {APPRAISAL=3, NEGOTIATION=2, JUDGING_INTENT=1} },
	ENGINEER = 			{ skills = {OPTICS_ENGINEER=3, FLUID_ENGINEER=3, MATHEMATICS=2, CRITICAL_THINKING=2, LOGIC=2, CHEMISTRY=1} },

	METALSMITH = 		{ skills = {FORGE_FURNITURE=3, METALCRAFT=2} },
	ARMORER = 			{ skills = {FORGE_ARMOR=3} },
	WEAPONSMITH = 		{ skills = {FORGE_WEAPON=3} },

	BOWYER = 			{ skills = {BOWYER=3} },
	CARPENTER = 		{ skills = {CARPENTRY=3, DESIGNBUILDING=2} },
	WOODCUTTER = 		{ skills = {WOODCUTTING=3} },
	WOODCRAFTER = 		{ skills = {WOODCRAFT=3} },

	MASON = 			{ skills = {MASONRY=3, DESIGNBUILDING=2} },
	ENGRAVER = 			{ skills = {DETAILSTONE=5} },
	MECHANIC = 			{ skills = {MECHANICS=5} },
	STONECRAFTER = 		{ skills = {STONECRAFT=3} },

	JEWELER = 			{ skills = {APPRAISAL=3, ENCRUSTGEM=2, CUTGEM=1} },
	GEM_CUTTER = 		{ skills = {CUTGEM=3} },
	GEM_SETTER = 		{ skills = {ENCRUSTGEM=3} },

	FARMER = 			{ skills = {GELD=4, BUTCHER=2, PLANT=2, MILLING=1, SHEARING=1, BREWING=1, MILK=1, HERBALISM=1, TANNER=1} },
	POTASH_MAKER = 		{ skills = {POTASH_MAKING=3} },
	BREWER = 			{ skills = {BREWING=3} },
	MILLER = 			{ skills = {MILLING=3} },
	MILKER = 			{ skills = {MILK=3} },
	CHEESE_MAKER = 		{ skills = {CHEESEMAKING=3} },
	COOK = 				{ skills = {COOK=3} },

	ANIMAL_TRAINER = 	{ skills = {ANIMALTRAIN=3} },
	TRAPPER = 			{ skills = {TRAPPING=3} },
	HERBALIST = 		{ skills = {HERBALISM=3} },
	FISHERMAN = 		{ skills = {FISH=3, DISSECT_FISH=2, PROCESSFISH=2} },

	LEATHERWORKER = 	{ skills = {LEATHERWORK=3, TANNER=2} },
	TANNER = 			{ skills = {TANNER=3} },
	SPINNER = 			{ skills = {SPINNING=3} },
	WEAVER = 			{ skills = {WEAVING=3} },
	SHEARER = 			{ skills = {SHEARING=3} },
	THRESHER = 			{ skills = {PROCESSPLANTS=3} },

	DIAGNOSER = 		{ skills = {DIAGNOSE=3} },
	BONE_SETTER = 		{ skills = {SET_BONE=3} },
	SUTURER = 			{ skills = {SUTURE=3} },
	SURGEON = 			{ skills = {SURGERY=3, GELD=2} },

	BONE_CARVER = 		{ skills = {BONECARVE=3} },
	POTTER = 			{ skills = {POTTERY=3} },
	GLAZER = 			{ skills = {GLAZING=3} },
	DYER = 				{ skills = {DYER=3} },

	SIEGE_ENGINEER = 	{ skills = {SIEGECRAFT=3, SIEGEOPERATE=1} },
	SIEGE_OPERATOR = 	{ skills = {SIEGEOPERATE=3} },
	PUMP_OPERATOR = 	{ skills = {OPERATE_PUMP=3} },

	CLERK = 			{ skills = {RECORD_KEEPING=3, ORGANIZATION=2} },
	MERCHANT = 			{ skills = {NEGOTIATION=3, APPRAISAL=2, LYING=1} }

--[[
	(not used)
	METALCRAFTER
	HAMMERMAN
	SPEARMAN
	CROSSBOWMAN
	WRESTLER
	AXEMAN
	SWORDSMAN
	MACEMAN
--]]
}

--[[
Stat Rolling:
	->Loop dorf attributes (physical/mental)
		->Loop attrib_levels randomly selecting elements
			-Roll(p) to apply the element
			 *Apply element to attribute,
			 *or don't.
		<-End Loop
	<-End Loop
	
	->Loop dorf_profs.<prof>.types{}
		-Apply attribs{}
		-Apply skills{}
	<-End Loop

	->Loop dorf_types
		-Roll(p) to apply type
		 *Apply type,
		 *or don't.
	<-End Loop

	This procedure allows low rolls to be improved. High rolls cannot be replaced, except by even higher rolls.
--]]
dorf_types = {
	resilient = {
		p = 0.0,
		attribs = {ENDURANCE={'verygood'},RECUPERATION={'verygood'},DISEASE_RESISTANCE={'superb'}}},
	smart = {
		p = 0.0,
		attribs = {ANALYTICAL_ABILITY={'superb'},FOCUS={'verygood'},INTUITION={'good'}}},
	genius = {
		p = 0.0,
		attribs = {ANALYTICAL_ABILITY={'incredible'},FOCUS={'verygood'},INTUITION={'good'}}},
	buff = {
		p = 0.0,
		attribs = {STRENGTH={'good'},TOUGHNESS={'good'},WILLPOWER={'average'}}},
	strong = {
		p = 0.0,
		attribs = {STRENGTH={'verygood'},TOUGHNESS={'good'},WILLPOWER={'good'}}},
	creative = {
		p = 0.0,
		attribs = {CREATIVITY={'amazing'}}},
	intuitive = {
		p = 0.0,
		attribs = {INTUITION={'amazing'}}},

--Chance to proc Non-Zero
	speedy = {
		p = 0.1667,
		attribs = {AGILITY={'good'}},
		skills  = {DODGING={3,9}}},
	agile = {
		p = 0.1111,
		attribs = {AGILITY={'superb'}},
		skills  = {DODGING={7,14}}},
	aware = {
		p = 0.21,
		attribs = {SOCIAL_AWARENESS={'verygood'},KINESTHETIC_SENSE={'superb'},SPATIAL_SENSE={'amazing'}},
		skills  = {SITUATIONAL_AWARENESS={4,16},CONCENTRATION={5,10},MILITARY_TACTICS={3,11},DODGING={2,5}}},
	social = {
		p = 0.1888,
		attribs = {LINGUISTIC_ABILITY={'amazing'},SOCIAL_AWARENESS={'superb'},EMPATHY={'good'}},
		skills  = {JUDGING_INTENT={8,12},PACIFY={4,16},CONSOLE={4,16},PERSUASION={2,8},CONVERSATION={2,8},FLATTERY={2,8},COMEDY={3,9},SPEAKING={4,10},PROSE={3,6}}},
	artistic = {
		p = 0.0311,
		attribs = {CREATIVITY={'incredible'},MUSICALITY={'amazing'},EMPATHY={'superb'}},
		skills  = {POETRY={0,4},DANCE={0,4},MAKE_MUSIC={0,4},WRITING={0,4},PROSE={2,5},SING_MUSIC={2,5},PLAY_KEYBOARD_INSTRUMENT={2,5},PLAY_STRINGED_INSTRUMENT={2,5},PLAY_WIND_INSTRUMENT={2,5},PLAY_PERCUSSION_INSTRUMENT={2,5}}},
	leader = {
		p=0.14,
		attribs = {FOCUS={'superb'},ANALYTICAL_ABILITY={'amazing'},LINGUISTIC_ABILITY={'superb'},PATIENCE={'incredible'},MEMORY={'verygood'},INTUITION={'amazing'},SOCIAL_AWARENESS={'incredible'},RECUPERATION={'verygood'},DISEASE_RESISTANCE={'good'},CREATIVITY={'superb'}},
		skills  = {LEADERSHIP={7,19},ORGANIZATION={7,17},TEACHING={12,18}}},
	adaptable = {
		p = 0.6666,
		attribs = {STRENGTH={'average'},AGILITY={'average'},ENDURANCE={'average'},RECUPERATION={'average'},FOCUS={'average'}},
		skills  = {DODGING={4,16},CLIMBING={4,16},SWIMMING={4,16},KNOWLEDGE_ACQUISITION={4,16}}},
	fighter = {
		p = 0.4242,
		attribs = {STRENGTH={'good'},AGILITY={'average'},ENDURANCE={'good'},RECUPERATION={'average'},FOCUS={'verygood'}},
		skills  = {DODGING={5,10},GRASP_STRIKE={5,10},STANCE_STRIKE={5,10},WRESTLING={5,10},SITUATIONAL_AWARENESS={5,10}}},
	soldier = {
		p = 0.3333,
		attribs = {STRENGTH={'verygood'},AGILITY={'verygood'},ENDURANCE={'verygood'},RECUPERATION={'verygood'},FOCUS={'superb'}},
		skills  = {DISCIPLINE={7,14},SITUATIONAL_AWARENESS={5,10},MELEE_COMBAT={4,6},RANGED_COMBAT={4,6},ARMOR={4,6},HAMMER={4,6},CROSSBOW={4,6},COORDINATION={4,6},BALANCE={4,6},MILITARY_TACTICS={5,8}}}
}

--return _ENV