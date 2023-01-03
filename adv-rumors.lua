-- Improve "Bring up specific incident or rumor", "Ask for Directions" and "Ask about Somebody" menus in Adventure mode
--@ enable = true
--[====[

adv-rumors
==========
Improves the "Bring up specific incident or rumor" menu in Adventure mode.

- Moves entries into one line
- Adds a "slew" keyword for filtering, making it easy to find your kills and not your companions'
- Adds "gaining", "placement" and "giving" keywords for artifacts
- Trims repetitive words

]====]

--========================
-- Author : 1337G4mer on bay12 and reddit, version 0.3 by Crystalwarrior on Discord
-- Version : 0.3
-- Description : An utility based on dfhack to improve the rumor, directions and ask about... UIs in adventure mode.
--
--      "Bring up specific incident or rumor", "Ask for Directions" and "Ask about Somebody" menus will
--      be automatically improved with better searchability and organization.
--
-- Prior Configuration: (you can skip this if you want)
--      Set the three boolean values below and play around with the script as to how you like
--      improveReadability = will move everything in one line
--      addPrefix = will add prefixes for every supported type of incident (Fight: , Event: , Rumor: , Place: , Person: )
--      addKeywords = will add a lot more keywords to make the rumors more searchable, such as missing names, "slew" keyword, "me" where "you" is used, etc.
--      shortenString = will further shorten the line to = slew "XYZ" ( "n time" ago in " Region")
--=======================
local improveReadability = true
local addPrefix = true
local addKeywords = true
local shortenString = true

local utils = require "utils"

function condenseChoiceTitle(choice)
    while #choice.title > 1 do
        choice.title[0].value = choice.title[0].value .. choice.title[1].value
        choice.title:erase(1)
    end
end

function addPrefixByType(choice)
    if choice.choice.type == df.talk_choice_type.SummarizeConflict and not string.find(choice.title[0].value, "^Fight: ") then
        choice.title[0].value = "Fight: " .. choice.title[0].value
    end
    if choice.choice.type == df.talk_choice_type.BringUpEvent and not string.find(choice.title[0].value, "^Event: ") then
        choice.title[0].value = "Event: " .. choice.title[0].value
    end
    if choice.choice.type == df.talk_choice_type.SpreadRumor and not string.find(choice.title[0].value, "^Rumor: ") then
        choice.title[0].value = "Rumor: " .. choice.title[0].value
    end
    if choice.choice.type == df.talk_choice_type.AskDirectionsPlace and not string.find(choice.title[0].value, "^Place: ") then
        choice.title[0].value = "Place: " .. choice.title[0].value
    end
    if choice.choice.type == df.talk_choice_type.AskAboutPerson and not string.find(choice.title[0].value, "^Whom: ") then
        choice.title[0].value = "Whom: " .. choice.title[0].value
    end
    if choice.choice.type == df.talk_choice_type.AskWhereabouts and not string.find(choice.title[0].value, "^Who: ") then
        choice.title[0].value = "Who: " .. choice.title[0].value
    end
end

function addKeywordsForChoice(choice)    
    if string.find(choice.title[0].value, "slew") then
        addKeyword(choice, 'slew')
    end
    if string.find(choice.title[0].value, "attack") then
        addKeyword(choice, 'attack')
    end
    if string.find(choice.title[0].value, " you ") or string.find(choice.title[0].value, " your ") then
        addKeyword(choice, 'me')
    end
    if choice.choice.type == df.talk_choice_type.SummarizeConflict then
        addKeyword(choice, "conflict") -- keyword 'conflict' already exists
    end
    if choice.choice.type == df.talk_choice_type.BringUpEvent then
        addKeyword(choice, "event")
    end
    if choice.choice.type == df.talk_choice_type.SpreadRumor then
        addKeyword(choice, "rumor")
    end
    if choice.choice.type == df.talk_choice_type.AskDirectionsPlace then
        addKeyword(choice, "directions")
        addKeyword(choice, "place")
    end
    if choice.choice.type == df.talk_choice_type.AskWhereabouts then
        addKeyword(choice, "person")
        addKeyword(choice, "whereabouts")
    end

    -- Transform the whole thing into keywords barring blacklist
    local names_blacklist = utils.invert{"the", "a", "an", "you", "your", "of", "to", "attacked", "slew", "was", "slain", "by"}
    local title = choice.title[0].value
    if title:find('%(') then
        title = title:sub(1, title:find('%(') - 1)
    end
    local keywords = title:gmatch('%w+')
    for keyword in keywords do
        keyword = keyword:lower()
        if not names_blacklist[keyword] then
            addKeyword(choice, keyword)
        end
    end
end

function shortenChoice(choice)
    choice.title[0].value = choice.title[0].value
        :gsub("Summarize the conflict in which +", "")
        :gsub("This occurred +", "")
        :gsub("Bring up +", "")
        :gsub("Spread rumor of +", "")
        :gsub("Ask about +", "")
        :gsub("Ask for directions to +", "where is ")
        :gsub("Ask for the whereabouts of +", "where is ")
end

function addKeyword(choice, keyword)
    -- Prevent duplicate keywords
    for i, kword in ipairs(choice.keywords) do
        if kword.value == keyword then
            return
        end
    end
    local keyword_ptr = df.new('string')
    keyword_ptr.value = keyword
    choice.keywords:insert('#', keyword_ptr)
end

-- Helper function to create new dialog choices
function new_choice(choice_type, title, keywords)
    local dialog = df.global.ui_advmode.conversation
    dialog.choices:insert("#", {new = df.ui_advmode.T_conversation.T_choices,})
    local choice_idx = #dialog.choices-1
    local choice = dialog.choices[choice_idx]
    if choice.choice == nil then
        choice.choice = df.talk_choice:new()
    end
    choice.choice.type = choice_type
    choice.title:insert("#",df.new("string"))
    choice.title[0].value=title
    for i, key in ipairs(keywords) do
        addKeyword(choice, key)
    end

    dialog.page_bottom_choices[0] = choice_idx
end

-- Condense the rumor system choices
function rumorUpdate()
    for i, choice in ipairs(df.global.ui_advmode.conversation.choices) do
        if choice.choice.type == df.talk_choice_type.SummarizeConflict or
           choice.choice.type == df.talk_choice_type.BringUpEvent or
           choice.choice.type == df.talk_choice_type.SpreadRumor or
           choice.choice.type == df.talk_choice_type.AskAboutPerson or 
           choice.choice.type == df.talk_choice_type.AskDirectionsPlace or
           choice.choice.type == df.talk_choice_type.AskWhereabouts then
            if improveReadability then
                condenseChoiceTitle(choice)
            end
            if addPrefix then
                addPrefixByType(choice)
            end
            if shortenString then
                condenseChoiceTitle(choice)
                shortenChoice(choice)
            end
            if addKeywords then
                addKeywordsForChoice(choice)
            end
        end
    end
end

-- Optionally add new choices in addition of existing ones
function choiceUpdate()
    if df.global.ui_advmode.conversation.activity_event[0].menu == df.conversation_menu.MainMenu then
        -- Essentially the "weather talking" exploit (as described by Rumrusher) in a single speaking action, put this in more menus to see its awesome potential.
        new_choice(df.talk_choice_type.AskTargetAction, "Ask what will they do about it", {"initiative", "action", "speak", "opinion"})
    end
end

-- Main Loop
active = active or false
function rumorloop()
    if active then dfhack.timeout(1, 'frames', check) end
end

-- Check if Continue Looping
local last_menu = nil
function check()
    if not dfhack.world.isAdventureMode() then
        return
    end
    if df.global.ui_advmode.menu ~= df.ui_advmode_menu.ConversationSpeak then
        last_menu = nil
        rumorloop()
        return
    end
    if df.global.ui_advmode.conversation.activity_event[0].menu ~= last_menu then
        rumorUpdate()
        -- Experimental "add extra choices" system, disabled by default. Uncomment the line below to test it out!
        -- choiceUpdate()
        last_menu = df.global.ui_advmode.conversation.activity_event[0].menu
    end
    rumorloop()
end

-- onStateChange listener to start/stop looping in relevant context
function dfhack.onStateChange.advRumorConversation (code)
    if code == SC_VIEWSCREEN_CHANGED and dfhack.isWorldLoaded() then
        local scr = dfhack.gui.getCurViewscreen()
        set_listener_active(scr._type == df.viewscreen_dungeonmodest)
    end
end

-- Toggle Loop on/off
function set_listener_active(tog)
    active = tog
    if active then
        print("activating rumor listener")
        check()
    else
        print("de-activating rumor listener")
    end
end