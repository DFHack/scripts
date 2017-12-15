--local _ENV = mkmodule('dorf_tables')
attrib_levels = {
    incompetent =   {p=0.02,    100,    20},
    verybad =       {p=0.04,    250,    25},
    bad =           {p=0.08,    450,    30},
    average =       {p=0.18,    810,    60},
    good =          {p=0.24,    1350,   75},
    verygood =      {p=0.22,    1700,   42},
    superb =        {p=0.12,    1900,   88},
    amazing =       {p=0.06,    2900,   188},
    incredible =    {p=0.03,    3800,   242},
    unbelievable =  {p=0.01,    4829,   42}
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
        skills  = {SITUATIONAL_AWARENESS={4,16}, CONCENTRATION={5,10}, MILITARY_TACTICS={3,11}, DODGING={2,5}}},
    social = {
        p = 0.1888,
        attribs = {LINGUISTIC_ABILITY={'amazing'},SOCIAL_AWARENESS={'superb'},EMPATHY={'good'}},
        skills  = {JUDGING_INTENT={8,12}, PACIFY={4,16}, CONSOLE={4,16}, PERSUASION={2,8}, CONVERSATION={2,8}, FLATTERY={2,8}, COMEDY={3,9}, SPEAKING={4,10}, PROSE={3,6}}},
    artistic = {
        p = 0.0311,
        attribs = {CREATIVITY={'incredible'},MUSICALITY={'amazing'},EMPATHY={'superb'}},
        skills  = {POETRY={0,4}, DANCE={0,4}, MAKE_MUSIC={0,4}, WRITING={0,4}, PROSE={2,5}, SING_MUSIC={2,5}, PLAY_KEYBOARD_INSTRUMENT={2,5}, PLAY_STRINGED_INSTRUMENT={2,5}, PLAY_WIND_INSTRUMENT={2,5}, PLAY_PERCUSSION_INSTRUMENT={2,5}}},
    leader = {
        p=0.14,
        attribs = {FOCUS={'superb'},ANALYTICAL_ABILITY={'amazing'},LINGUISTIC_ABILITY={'superb'},PATIENCE={'incredible'},MEMORY={'verygood'},INTUITION={'amazing'},SOCIAL_AWARENESS={'incredible'},RECUPERATION={'verygood'},DISEASE_RESISTANCE={'good'},CREATIVITY={'superb'}},
        skills  = {LEADERSHIP={7,19},ORGANIZATION={7,17}}},
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

dorf_jobs = {
    --[[
        When looping the dorfs check if custom_profession matches a dorf prof below.
        If it matches, proceed to next dorf in loop.

        It might be prudent to create an additional signal for the loop to bypass a dorf.
        The question is what? A preceding character? A custom profession, period?
        (Whatever it be, the dorf should probably be printed to the console for the user to know about.)
    --]]
    Miner = { --4/24 max:8
        req={'MINER'},
        types={'adaptable','fighter','strong','strong','agile','aware','resilient'}},
    Grunt = { --3/24 max:20
        req={'RECRUIT'},
        types={'adaptable','fighter','soldier','strong','agile','aware','resilient','strong','agile','aware','resilient','strong','agile','aware','resilient'}},
    Smelter = { --1/24 max:6
        req={'FURNACE_OPERATOR','WOOD_BURNER'},
        types={'fighter','agile','buff','aware','resilient','resilient','resilient'}},
    Blacksmith = { --1/24 max:4
        req={'BLACKSMITH'},
        prio={'WEAPONSMITH','ARMORER'},
        METALSMITH=0.38, BOWYER=0.24,
        types={'buff','buff','intuitive','aware'}},

    Stoneworker = { --2/24 max:7
        req={'STONEWORKER'}, 
        prio={'ENGRAVER'},
        MASON=0.42, MECHANIC=0.42,
        types={'buff','speedy','aware','resilient'}},
    Woodworker = { --1/24 max:4
        req={'WOODWORKER'},
        prio={'WOODCUTTER'},
        CARPENTER=0.55, BOWYER=0.38,
        types={'agile','agile','social','smart','creative'}},
    Architect = { --1/24 max:3
        req={'ARCHITECT'},
        prio={'MASON','CARPENTER'},
        MECHANIC=0.66,
        types={'genius','creative','speedy'}},

    Farmer = { --3/24 max:5
        req={'PLANTER'},
        prio={'POTASH_MAKER','BREWER'},
        MILLER=0.25, SHEARER=0.15, MILKER=0.25, CHEESE_MAKER=0.25,
        types={'speedy','aware','intuitive'}},
    Clothier = { --2/24 max:4
        req={'CLOTHIER'},
        prio={'THRESHER','WEAVER'},
        SPINNER=0.66, LEATHERWORKER=0.5, DYER=0.25,
        types={'speedy','speedy','social'}},
    Warden = { --1/24 max:3
        req={'ANIMAL_CARETAKER'},
        prio={'SHEARER','MILKER','ANIMAL_TRAINER'},
        CHEESE_MAKER=0.41, BUTCHER=0.25, TANNER=0.38, BONE_CARVER=0.28,
        types={'aware','social','speedy','buff'}},        
    Hunter = { --1/24 max:2
        req={'HUNTER','RANGER'},
        prio={'TANNER','BUTCHER','TRAPPER'},
        HERBALIST=0.75,
        types={'buff','agile','agile','agile','aware','intuitive','smart'}},
    Butcher = { --0/24 max:2
        req={'BUTCHER'},
        prio={'TANNER','BONE_CARVER'},
        COOK=0.66,
        types={'buff','speedy','aware'}},

    Artison = { --1/24 max:7
        req={'CRAFTSMAN'},
        prio={'ENGRAVER'},
        WOODCRAFTER=0.33, STONECRAFTER=0.33, JEWELER=0.33, GEM_CUTTER=0.33, GEM_SETTER=0.33, BONE_CARVER=0.33, POTTER=0.33,
        types={'agile','agile','smart','creative','social','resilient'}},
    Doctor = { --1/24 max:3
        req={'DOCTOR'},
        prio={'DIAGNOSER','BONE_SETTER','SUTURER'},
        SURGEON=0.38,
        types={'smart','aware','agile','social','resilient'}},
    Leader = { --2/24 max:7
        req={'ADMINISTRATOR'},
        BREWER=0.51, CLERK=0.51,
        types={'leader','smart','social'}},
    Trader = { --0/24 max:4
        req={'TRADER'},
        prio={'CLERK','MERCHANT'},
        ADMINISTRATOR=0.42, JEWELER=0.51, CRAFTSMAN=0.33,
        types={'smart','social'}},
    Engineer = { --0/24 max:3
        req={'ENGINEER'},
        SIEGE_ENGINEER=0.88, MECHANIC=0.88, METALSMITH=0.33,
        types={'genius','intuitive'}}
}

--[[
    Primary professions (ie. listed as prof1)
        cur = cur + 1.0
    Secondary professions (ie. listed as prof2)
        cur = cur + 0.7
    Tertiary professions (ie. unlisted profs)
        cur = cur + 0.3
(this may not be a good idea)
--]]
professions = {
    MINER = {
        cur=0, max=8, ratio=0.1667,
        skills = {MINING=3}},
    RECRUIT = {
        cur=0, max=20, ratio=0.1458,
        skills = {KNOWLEDGE_ACQUISITION=2, INTIMIDATION=1, DISCIPLINE=3}},
    FURNACE_OPERATOR = {
        cur=0, max=6, ratio=0.0746,
        skills = {SMELT=3}},
    WOOD_BURNER = {
        cur=0, max=6, ratio=0.0746,
        skills = {WOOD_BURNING=2}},
    BLACKSMITH = {
        cur=0, max=4, ratio=0.0554,
        skills = {FORGE_WEAPON=4, FORGE_ARMOR=3}},

    STONEWORKER = {
        cur=0, max=7, ratio=0.1187,
        skills = {MASONRY=3, STONECRAFT=2}},
    WOODWORKER = {
        cur=0, max=4, ratio=0.0482,
        skills = {CARPENTRY=3, WOODCRAFT=1}},
    ARCHITECT = {
        cur=0, max=3, ratio=0.0511,
        skills = {DESIGNBUILDING=3, MASONRY=2, CARPENTRY=1}},

    PLANTER = {
        cur=0, max=5, ratio=0.1279,
        skills = {PLANT=3, POTASH_MAKING=2}},
    CLOTHIER = {
        cur=0, max=4, ratio=0.0909,
        skills = {CLOTHESMAKING=2, WEAVING=1, PROCESSPLANTS=1}},
    ANIMAL_CARETAKER = {
        cur=0, max=3, ratio=0.0770,
        skills = {ANIMALCARE=3, SHEARING=2, MILK=1, ANIMALTRAIN=1}},
    HUNTER = {
        cur=0, max=3, ratio=0.0417,
        skills = {SNEAK=3, TRACKING=2, RANGED_COMBAT=2, CROSSBOW=1}},
    RANGER = {
        cur=0, max=2, ratio=0.0417,
        skills = {ANIMALCARE=3, ANIMALTRAIN=3, CROSSBOW=2, SNEAK=2, TRAPPING=2}},
    BUTCHER = {
        cur=0, max=2, ratio=0.0411,
        skills = {BUTCHER=3, TANNER=2, COOK=1}},

    CRAFTSMAN = {
        cur=0, max=7, ratio=0.0416,
        skills = {WOODCRAFT=1, STONECRAFT=1, METALCRAFT=1}},
    DOCTOR = {
        cur=0, max=3, ratio=0.0444,
        skills = {DIAGNOSE=1, DRESS_WOUNDS=1, SET_BONE=1, SUTURE=1, CRUTCH_WALK=1}},
    ADMINISTRATOR = {
        cur=0, max=7, ratio=0.0833,
        skills = {RECORD_KEEPING=3, ORGANIZATION=2, APPRAISAL=1}},
    TRADER = {
        cur=0, max=4, ratio=0.0404,
        skills = {APPRAISAL=3, NEGOTIATION=2, JUDGING_INTENT=1}},
    ENGINEER = {
        cur=0, max=3, ratio=0.0409,
        skills = {OPTICS_ENGINEER=3, FLUID_ENGINEER=3, MATHEMATICS=2, CRITICAL_THINKING=2, LOGIC=2, CHEMISTRY=1}},

--Section Two
    METALSMITH = {
        cur=0, max=3,
        skills = {FORGE_FURNITURE=3, METALCRAFT=2}},
    ARMORER = {
        cur=0, max=2,
        skills = {FORGE_ARMOR=3}},
    WEAPONSMITH = {
        cur=0, max=3,
        skills = {FORGE_WEAPON=3}},

    BOWYER = {
        cur=0, max=2,
        skills = {BOWYER=3}},
    CARPENTER = {
        cur = 0, max=7,
        skills = {CARPENTRY=3, DESIGNBUILDING=2}},
    WOODCUTTER = {
        cur=0, max=2,
        skills = {WOODCUTTING=3}},
    WOODCRAFTER = {
        cur=0, max=5,
        skills = {WOODCRAFT=3}},

    MASON = {
        cur=0, max=7,
        skills = {MASONRY=3, DESIGNBUILDING=2}},
    ENGRAVER = {
        cur=0, max=10,
        skills = {DETAILSTONE=3}},
    MECHANIC = {
        cur=0, max=7,
        skills = {MECHANICS=3}},
    STONECRAFTER = {
        cur=0, max=5,
        skills = {STONECRAFT=3}},

    JEWELER = {
        cur=0, max=3,
        skills = {APPRAISAL=3, ENCRUSTGEM=2, CUTGEM=1}},
    GEM_CUTTER = {
        cur=0, max=2,
        skills = {CUTGEM=3}},
    GEM_SETTER = {
        cur=0, max=2,
        skills = {ENCRUSTGEM=3}},

    POTASH_MAKER = {
        cur=0, max=2,
        skills = {POTASH_MAKING=3}},
    BREWER = {
        cur=0, max=3,
        skills = {BREWING=3}},
    MILLER = {
        cur=0, max=1,
        skills = {MILLING=3}},
    MILKER = {
        cur=0, max=1,
        skills = {MILK=3}},
    CHEESE_MAKER = {
        cur=0, max=1,
        skills = {CHEESEMAKING=3}},
    COOK = {
        cur=0, max=2,
        skills = {COOK=3}},

    ANIMAL_TRAINER = {
        cur=0, max=3,
        skills = {ANIMALTRAIN=3}},
    TRAPPER = {
        cur=0, max=1,
        skills = {TRAPPING=3}},
    HERBALIST = {
        cur=0, max=3,
        skills = {HERBALISM=3}},
    FISHERMAN = {
        cur=0, max=2,
        skills = {FISH=3, DISSECT_FISH=2, PROCESSFISH=2}},

    LEATHERWORKER = {
        cur=0, max=2,
        skills = {LEATHERWORK=3, TANNER=2}},
    TANNER = {
        cur=0, max=2,
        skills = {TANNER=3}},
    SPINNER = {
        cur=0, max=2,
        skills = {SPINNING=3}},
    WEAVER = {
        cur=0, max=2,
        skills = {WEAVING=3}},
    SHEARER = {
        cur=0, max=3,
        skills = {SHEARING=3}},
    THRESHER = {
        cur=0, max=2,
        skills = {PROCESSPLANTS=3}},

    DIAGNOSER = {
        cur=0, max=2,
        skills = {DIAGNOSE=3}},
    BONE_SETTER = {
        cur=0, max=2,
        skills = {SET_BONE=3}},
    SUTURER = {
        cur=0, max=2,
        skills = {SUTURE=3}},
    SURGEON = {
        cur=0, max=2,
        skills = {SURGERY=3}},

    BONE_CARVER = {
        cur=0, max=2,
        skills = {BONECARVE=3}},
    POTTER = {
        cur=0, max=1,
        skills = {{POTTERY=3}}},
    GLAZER = {
        cur=0, max=1,
        skills = {GLAZING=3}},

    SIEGE_ENGINEER = {
        cur=0, max=2,
        skills = {SIEGECRAFT=3, SIEGEOPERATE=1}},
    SIEGE_OPERATOR = {
        cur=0, max=4,
        skills = {SIEGEOPERATE=3}},
    PUMP_OPERATOR = {
        cur=0, max=3,
        skills = {OPERATE_PUMP=3}},

    CLERK = {
        cur=0, max=2,
        skills = {RECORD_KEEPING=3, ORGANIZATION=2}},
    MERCHANT = {
        cur=0, max=2,
        skills = {NEGOTIATION=3, APPRAISAL=2, LYING=1}},

--[[
    (not used)
    FARMER--we don't talk about this
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
function ResetProfessionTable()
    for prof, profTable in pairs(professions) do
        profTable.cur = 0
    end
end
ResetProfessionTable()
--return _ENV