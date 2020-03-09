-- dorf_tables has job distribution configurations, random number information for attributes generation, job configurations, profession configurations, dwarf types(ie. attributes/characteristic) configurations
-- usage: loaded by pimp-it.lua
-- by josh cooper(cppcooper) [created: 12-2017 | last edited: 12-2018]
--@ module = true

local help = [====[

dorf_tables
===========
Data tables for pimp-it.lua.

Usage: load inside secondary script (pimp-it.lua)

]====]

if not moduleMode then
    print("scripts/dorf_tables.lua is a content library; calling it does nothing.")
    do return end
end
print("Loading data tables..")

-- p denotes probability, always.
local O = 0
--luacheck:global
job_distributions = {
    Thresholds      = { 7,  14, 21, 28, 30, 35, 42, 49, 56, 63, 70, 77, 80, 110, 1000 }, --Don't touch unless you wanna recalculate the distributions,
    _Grunt          = { O,  1,  2,  O,  O,  1,  2,  O,  4,  1,  1,  4,  O,  10,  880; cur = 0; max = nil },
    Miner           = { 2,  1,  O,  1,  O,  1,  O,  O,  O,  O,  2,  O,  O,  3,   O;   cur = 0; max = nil },
    Admin           = { 1,  1,  O,  O,  1,  O,  O,  O,  O,  O,  O,  O,  1,  1,   O;   cur = 0; max = nil },
    General         = { O,  O,  O,  1,  O,  O,  1,  O,  O,  1,  O,  O,  O,  2,   10;  cur = 0; max = nil },
    Doctor          = { O,  1,  O,  O,  1,  O,  O,  O,  O,  O,  O,  O,  1,  2,   O;   cur = 0; max = nil },
    Architect       = { 1,  O,  O,  1,  O,  O,  O,  1,  O,  1,  O,  O,  O,  2,   O;   cur = 0; max = nil },

    Farmer          = { 1,  O,  1,  O,  O,  O,  O,  O,  1,  1,  O,  O,  O,  2,   O;   cur = 0; max = nil },
    Rancher         = { O,  1,  O,  O,  O,  O,  1,  O,  O,  1,  O,  O,  O,  O,   O;   cur = 0; max = nil },
    Brewer          = { 1,  O,  O,  1,  O,  O,  O,  O,  O,  1,  O,  O,  O,  1,   O;   cur = 0; max = nil },
    Woodworker      = { 1,  O,  1,  O,  O,  O,  O,  1,  O,  O,  O,  O,  O,  O,   O;   cur = 0; max = nil },
    Stoneworker     = { O,  1,  O,  O,  O,  O,  1,  1,  O,  O,  2,  O,  O,  O,   O;   cur = 0; max = nil },
    Smelter         = { O,  1,  O,  1,  O,  O,  O,  O,  O,  O,  O,  O,  O,  1,   O;   cur = 0; max = nil },
    Blacksmith      = { O,  O,  1,  O,  O,  1,  O,  O,  O,  O,  O,  1,  O,  1,   O;   cur = 0; max = nil },

    Artison         = { O,  O,  1,  O,  O,  O,  1,  2,  O,  O,  2,  2,  O,  3,   O;   cur = 0; max = nil },
    Jeweler         = { O,  O,  O,  O,  O,  O,  O,  1,  O,  O,  O,  O,  O,  1,   O;   cur = 0; max = nil },
    Textileworker   = { O,  O,  O,  1,  O,  O,  1,  O,  O,  O,  O,  O,  O,  O,   O;   cur = 0; max = nil },

    Hunter          = { O,  O,  O,  1,  O,  O,  O,  O,  1,  O,  O,  O,  O,  O,   O;   cur = 0; max = nil },
    Fisher          = { O,  O,  1,  O,  O,  O,  O,  O,  1,  O,  O,  O,  O,  O,   O;   cur = 0; max = nil },
    Butcher         = { O,  O,  O,  O,  O,  1,  O,  O,  O,  O,  O,  O,  O,  O,   O;   cur = 0; max = nil },

    Engineer        = { O,  O,  O,  O,  O,  1,  O,  1,  O,  1,  O,  O,  1,  1,   O;   cur = 0; max = nil }
}
--[[
Stat Rolling:
    ->Loop dwarf attributes (physical/mental)
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


--probability is used for generating all dwarf stats, some jobs include dorf_types which will upgrade particular stats
--luacheck:global
attrib_levels = { -- prob,      avg,    std deviation
    incompetent =   {p=0.01,    100,    20},
    verybad =       {p=0.02,    250,    25},
    bad =           {p=0.04,    450,    30},
    average =       {p=0.21,    810,    60},
    good =          {p=0.28,    1350,   75},
    verygood =      {p=0.22,    1700,   42},
    superb =        {p=0.12,    1900,   88},
    amazing =       {p=0.06,    2900,   188},
    incredible =    {p=0.03,    3800,   242},
    unbelievable =  {p=0.01,    4829,   42}
}

--[[
dorf_jobs = {
    job = {
        required_professions, max_tertiary_professions,
        tertiary_professions,
        dorf_types
    }
    The value associated with the tertiary professions is both an enforced ratio maximum for a given job,
    and also the probability that the profession will be applied during the algorithm's execution.
}
--]]
--luacheck:global
jobs = {
    _Grunt = {
        req={'RECRUIT'}, max={1988},
        HERBALIST=0.4,
        types={'strong2','strong2','fast3','spaceaware3','soldier','fighter','social'}},
    Miner = {
        req={'MINER'}, max={1},
        BREWER=0.2, STONEWORKER=0.12, ENGRAVER=0.333,
        types={'spaceaware3','strong3','fast3','resilient2','social'}},
    Admin = {
        req={'ADMINISTRATOR'}, max={1},
        TRADER=0.5, CLERK=0.5,
        types={'genius3','intuitive3','resilient2','leader','adaptable','fighter','social'}},
    General = {
        req={'RECRUIT','SIEGE_OPERATOR','SIEGE_ENGINEER'}, max={2},
        COOK=0.3333, MILLER=0.3333,
        types={'fast2','genius2','spaceaware2','resilient2','leader','soldier','fighter'}},
    Doctor = {
        req={'DOCTOR'}, max={4},
        DIAGNOSER=0.6666, BONE_SETTER=0.6666, SUTURER=0.3333, SURGEON=0.3333,
        types={'genius3','resilient2','intuitive2','strong1','aware','agile'}},
    Architect = {
        req={'ARCHITECT','METALSMITH'}, max={2},
        ENGINEER=0.5, MECHANIC=0.5, MASON=0.5, CARPENTER=0.5,
        types={'genius3','creative2','fast1','strong1','spaceaware3'}},

    Farmer = {
        req={'PLANTER'}, max={3},
        POTASH_MAKER=0.3333, MILLER=0.3333, FARMER=0.5, BREWER=0.5,
        types={'fast3','strong1','spaceaware1','resilient1','intuitive1'}},
    Rancher = {
        req={'ANIMAL_CARETAKER'}, max={4},
        SHEARER=0.5, MILKER=0.5, CHEESE_MAKER=0.5, BUTCHER=0.5, TANNER=0.5, ANIMAL_TRAINER=0.5,
        types={'fast3','strong3','intuitive2','resilient2','spaceaware1'}},
    Brewer = {
        req={'BREWER'}, max={1},
        HERBALIST=0.3333, POTTER=0.1111, THRESHER=0.5,
        types={'fast2','buff','resilient1','genius1'}},
    Woodworker = {
        req={'WOODWORKER','WOODCUTTER'}, max={2},
        CARPENTER=0.7, BOWYER=0.6,
        types={'fast3','strong1','creative1','agile','fighter'}},
    Stoneworker = {
        req={'STONEWORKER'}, max={2},
        ENGRAVER=0.58, MASON=0.66, MECHANIC=0.66,
        types={'strong3','fast2','spaceaware1','creative1'}},
    Smelter = {
        req={'FURNACE_OPERATOR','WOOD_BURNER','POTASH_MAKER'}, max={1988},
        types={'fast2','strong1','resilient1'}},
    Blacksmith = {
        req={'BLACKSMITH'}, max={3},
        WEAPONSMITH=0.75, ARMORER=0.7, METALSMITH=0.66, BOWYER=0.33,
        types={'strong3','fast2','spaceaware1'}},

    Artison = {
        req={'CRAFTSMAN','ENGRAVER','WOODCRAFTER','STONECRAFTER'}, max={2},
        BONE_CARVER=0.66, POTTER=0.75,
        types={'fast3','buff','creative2','social','artistic'}},
    Jeweler = {
        req={'JEWELER','GEM_CUTTER','GEM_SETTER'}, max={1988},
        types={'creative2','intuitive2','spaceaware2','genius1','artistic'}},
    Textileworker = {
        req={'WEAVER','SPINNER','CLOTHIER'}, max={3},
        THRESHER=0.75, LEATHERWORKER=0.5, DYER=0.5,
        types={'fast1','creative1','social','artistic'}},

    Hunter = {
        req={'HUNTER','TRAPPER','RANGER'}, max={3},
        HERBALIST=0.66, TANNER=0.88, BUTCHER=0.77, COOK=0.5,
        types={'fast3','intuitive3','spaceaware3','resilient2','strong1'}},
    Fisher = {
        req={'FISHERMAN','COOK'}, max={1},
        HERBALIST=0.77,
        types={'fast2','intuitive2','spaceaware2','resilient2','buff'}},
    Butcher = {
        req={'BUTCHER'}, max={2},
        TRAPPER=0.5, TANNER=0.75, COOK=0.66, BONE_CARVER=0.55,
        types={'spaceaware1','buff','aware'}},

    Engineer = {
        req={'ENGINEER'}, max={7},
        SIEGE_ENGINEER=0.88, MECHANIC=0.88, CLERK=0.88, PUMP_OPERATOR=0.88, SIEGE_OPERATOR=0.88, FURNACE_OPERATOR=0.5, BREWER=0.5,
        types={'genius3','intuitive2','leader'}}
}

--luacheck:global
professions = {
--Basic Dwarfing
    MINER =             { skills = {MINING=3} },
    RECRUIT =           { skills = {KNOWLEDGE_ACQUISITION=2, INTIMIDATION=1, DISCIPLINE=3} },
    ADMINISTRATOR =     { skills = {RECORD_KEEPING=3, ORGANIZATION=2, APPRAISAL=1} },
    TRADER =            { skills = {APPRAISAL=3, NEGOTIATION=3, JUDGING_INTENT=2, LYING=2} },
    CLERK =             { skills = {RECORD_KEEPING=3, ORGANIZATION=3} },
    DOCTOR =            { skills = {DIAGNOSE=4, DRESS_WOUNDS=3, SET_BONE=2, SUTURE=1, CRUTCH_WALK=1} },
    ENGINEER =          { skills = {OPTICS_ENGINEER=3, FLUID_ENGINEER=3, MATHEMATICS=2, CRITICAL_THINKING=2, LOGIC=2, CHEMISTRY=1} },
    ARCHITECT =         { skills = {DESIGNBUILDING=3, MASONRY=2, CARPENTRY=1} },

--Resource Economy
    WOODCUTTER =        { skills = {WOODCUTTING=3} },
    WOOD_BURNER =       { skills = {WOOD_BURNING=2} },
    FURNACE_OPERATOR =  { skills = {SMELT=3} },
    --Wood
    CARPENTER =         { skills = {CARPENTRY=3, DESIGNBUILDING=2} },
    WOODWORKER =        { skills = {CARPENTRY=3} },
    WOODCRAFTER =       { skills = {WOODCRAFT=3} },
    --Stone
    MASON =             { skills = {MASONRY=3, DESIGNBUILDING=2} },
    STONEWORKER =       { skills = {MASONRY=3, STONECRAFT=2} },
    STONECRAFTER =      { skills = {STONECRAFT=3} },
    --Metal
    METALSMITH =        { skills = {FORGE_FURNITURE=3, METALCRAFT=2} },
    BLACKSMITH =        { skills = {FORGE_WEAPON=4, FORGE_ARMOR=3} },

--Armory
    BOWYER =            { skills = {BOWYER=3} },
    WEAPONSMITH =       { skills = {FORGE_WEAPON=3} },
    ARMORER =           { skills = {FORGE_ARMOR=3} },

--Arts & Crafts & Dwarfism
    CRAFTSMAN =         { skills = {WOODCRAFT=2, STONECRAFT=2, METALCRAFT=2} },
    ENGRAVER =          { skills = {DETAILSTONE=5} },
    MECHANIC =          { skills = {MECHANICS=5} },

--Plants & Animals
    --Agriculture
    POTASH_MAKER =      { skills = {POTASH_MAKING=3} },
    PLANTER =           { skills = {PLANT=4, POTASH_MAKING=2} },
    FARMER =            { skills = {PLANT=3, MILLING=3, HERBALISM=2, POTASH_MAKING=1} },
    MILLER =            { skills = {MILLING=3} },
    HERBALIST =         { skills = {HERBALISM=3} },
    THRESHER =          { skills = {PROCESSPLANTS=3} },
    --Ranching
    ANIMAL_CARETAKER =  { skills = {ANIMALCARE=3, SHEARING=2, MILK=1, ANIMALTRAIN=1} },
    ANIMAL_TRAINER =    { skills = {ANIMALTRAIN=3} },
    MILKER =            { skills = {MILK=3} },
    SHEARER =           { skills = {SHEARING=3} },
    CHEESE_MAKER =      { skills = {CHEESEMAKING=3} },
    --Hunting & Fishing
    HUNTER =            { skills = {SNEAK=3, TRACKING=4, RANGED_COMBAT=2, CROSSBOW=1} },
    TRAPPER =           { skills = {TRAPPING=3} },
    FISHERMAN =         { skills = {FISH=3, DISSECT_FISH=2, PROCESSFISH=2} },
    --Dead Thing Science
    BUTCHER =           { skills = {BUTCHER=3, TANNER=2, COOK=1, GELD=-3} }, --the '-3' is not a typo, it is just to populate the field [for DwarfTherapist auto-assigning]
    TANNER =            { skills = {TANNER=3} },

--Textile & Clothing & Leather Industry
    SPINNER =           { skills = {SPINNING=3} },
    WEAVER =            { skills = {WEAVING=3} },
    DYER =              { skills = {DYER=3} },
    CLOTHIER =          { skills = {CLOTHESMAKING=2, DYER=1} },
    LEATHERWORKER =     { skills = {LEATHERWORK=3, TANNER=2} },

--War
    SIEGE_ENGINEER =    { skills = {SIEGECRAFT=3, SIEGEOPERATE=1} },
    SIEGE_OPERATOR =    { skills = {SIEGEOPERATE=3} },
    PUMP_OPERATOR =     { skills = {OPERATE_PUMP=3} },

--Other
    BREWER =            { skills = {BREWING=3} },
    RANGER =            { skills = {ANIMALCARE=3, ANIMALTRAIN=3, CROSSBOW=2, SNEAK=2, TRAPPING=2} },
    COOK =              { skills = {COOK=3} },

    JEWELER =           { skills = {APPRAISAL=3, ENCRUSTGEM=2, CUTGEM=1} },
    GEM_CUTTER =        { skills = {CUTGEM=3} },
    GEM_SETTER =        { skills = {ENCRUSTGEM=3} },

    DIAGNOSER =         { skills = {DIAGNOSE=5} },
    BONE_SETTER =       { skills = {SET_BONE=5} },
    SUTURER =           { skills = {SUTURE=5} },
    SURGEON =           { skills = {SURGERY=5, GELD=2} },

    BONE_CARVER =       { skills = {BONECARVE=3} },
    POTTER =            { skills = {POTTERY=3} },
    GLAZER =            { skills = {GLAZING=3} }


--[[
    (not used)
    MERCHANT
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

--probability is used for randomly applying types to any and all dwarves
--luacheck:global
types = {
    resilient1 = {
        p = 0.2,
        attribs = {ENDURANCE={'verygood'},RECUPERATION={'verygood'},DISEASE_RESISTANCE={'superb'}}},
    resilient2 = {
        p = 0.05,
        attribs = {ENDURANCE={'amazing'},RECUPERATION={'incredible'},DISEASE_RESISTANCE={'unbelievable'}}},
    genius1 = {
        p = 0.1,
        attribs = {ANALYTICAL_ABILITY={'good'},FOCUS={'verygood'},INTUITION={'good'}}},
    genius2 = {
        p = 0.01,
        attribs = {ANALYTICAL_ABILITY={'superb'},FOCUS={'superb'},INTUITION={'superb'}}},
    genius3 = {
        p = 0.001,
        attribs = {ANALYTICAL_ABILITY={'unbelievable'},FOCUS={'amazing'},INTUITION={'amazing'}}},
    buff = {
        p = 0.1111,
        attribs = {STRENGTH={'good'},TOUGHNESS={'good'},WILLPOWER={'average'}}},
    fast1 = {
        p = 0.32,
        attribs = {AGILITY={'good'}}},
    fast2 = {
        p = 0.16,
        attribs = {AGILITY={'superb'}}},
    fast3 = {
        p = 0.08,
        attribs = {AGILITY={'incredible'}}},
    strong1 = {
        p = 0.1,
        attribs = {STRENGTH={'verygood'},TOUGHNESS={'good'},WILLPOWER={'good'}}},
    strong2 = {
        p = 0.05,
        attribs = {STRENGTH={'amazing'},TOUGHNESS={'superb'},WILLPOWER={'verygood'}}},
    strong3 = {
        p = 0.01,
        attribs = {STRENGTH={'unbelievable'},TOUGHNESS={'amazing'},WILLPOWER={'superb'}}},
    creative1 = {
        p = 0.05,
        attribs = {CREATIVITY={'superb'}}},
    creative2 = {
        p = 0.0059,
        attribs = {CREATIVITY={'incredible'}}},
    intuitive1 = {
        p = 0.2,
        attribs = {INTUITION={'superb'}}},
    intuitive2 = {
        p = 0.1,
        attribs = {INTUITION={'amazing'}}},
    intuitive3 = {
        p = 0.1,
        attribs = {INTUITION={'unbelievable'}}},
    spaceaware1 = {
        p = 0.3333,
        attribs = {KINESTHETIC_SENSE={'good'},SPATIAL_SENSE={'verygood'}}},
    spaceaware2 = {
        p = 0.2222,
        attribs = {KINESTHETIC_SENSE={'verygood'},SPATIAL_SENSE={'amazing'}}},
    spaceaware3 = {
        p = 0.1111,
        attribs = {KINESTHETIC_SENSE={'amazing'},SPATIAL_SENSE={'unbelievable'}}},
        
--with skills
    agile = {
        p = 0.1111,
        attribs = {AGILITY={'amazing'}},
        skills  = {DODGING={7,14}}},
    aware = {
        p = 0.1111,
        attribs = {SOCIAL_AWARENESS={'superb'},KINESTHETIC_SENSE={'verygood'},SPATIAL_SENSE={'amazing'}},
        skills  = {SITUATIONAL_AWARENESS={4,16},CONCENTRATION={5,10},MILITARY_TACTICS={3,11},DODGING={2,5}}},
    social = {
        p = 0.32,
        attribs = {LINGUISTIC_ABILITY={'superb'},SOCIAL_AWARENESS={'superb'},EMPATHY={'verygood'}},
        skills  = {JUDGING_INTENT={8,12},PACIFY={4,16},CONSOLE={4,16},PERSUASION={2,8},CONVERSATION={2,8},FLATTERY={2,8},COMEDY={3,9},SPEAKING={4,10},PROSE={3,6}}},
    artistic = {
        p = 0.0311,
        attribs = {CREATIVITY={'incredible'},MUSICALITY={'amazing'},EMPATHY={'superb'}},
        skills  = {POETRY={0,4},DANCE={0,4},MAKE_MUSIC={0,4},WRITING={0,4},PROSE={2,5},SING_MUSIC={2,5},PLAY_KEYBOARD_INSTRUMENT={2,5},PLAY_STRINGED_INSTRUMENT={2,5},PLAY_WIND_INSTRUMENT={2,5},PLAY_PERCUSSION_INSTRUMENT={2,5}}},
    leader = {
        p=0.14,
        attribs = {FOCUS={'superb'},ANALYTICAL_ABILITY={'amazing'},LINGUISTIC_ABILITY={'superb'},PATIENCE={'incredible'},MEMORY={'verygood'},INTUITION={'amazing'},SOCIAL_AWARENESS={'incredible'},RECUPERATION={'verygood'},DISEASE_RESISTANCE={'good'},CREATIVITY={'superb'}},
        skills  = {LEADERSHIP={7,19},ORGANIZATION={7,17},TEACHING={12,18},MILITARY_TACTICS={7,19}}},
    adaptable = {
        p = 0.6666,
        attribs = {STRENGTH={'average'},AGILITY={'average'},ENDURANCE={'average'},RECUPERATION={'average'},FOCUS={'verygood'}},
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
