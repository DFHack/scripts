--@ module=true

local overlay = require('plugins.overlay')
local utils = require('utils')

local ignore_words = utils.invert{
    "a", "an", "by", "in", "occurred", "of", "or",
    "s", "the", "this", "to", "was", "which"
}

local adventure = df.global.game.main_interface.adventure

-- Gets the keywords already present on the dialog choice
local function getKeywords(choice)
    local keywords = {}
    for _, keyword in ipairs(choice.keywords) do
        table.insert(keywords, keyword.value:lower())
    end
    return keywords
end

-- Adds a keyword to the dialog choice
local function addKeyword(choice, keyword)
    local keyword_ptr = df.new('string')
    keyword_ptr.value = dfhack.toSearchNormalized(keyword)
    choice.keywords:insert('#', keyword_ptr)
end

-- Adds multiple keywords to the dialog choice
local function addKeywords(choice, keywords)
    for _, keyword in ipairs(keywords) do
        addKeyword(choice, keyword)
    end
end

-- Generates keywords based on the text of the dialog choice, plus keywords for special cases
local function generateKeywordsForChoice(choice)
    local new_keywords, keywords_set = {}, utils.invert(getKeywords(choice))

    -- Puts the keyword into a new_keywords table, but only if unique and not ignored
    local function collect_keyword(word)
        if ignore_words[word] or keywords_set[word] then return end
        table.insert(new_keywords, word)
        keywords_set[word] = true
    end

    -- generate keywords from useful words in the text
    for _, data in ipairs(choice.title.text) do
        for word in dfhack.toSearchNormalized(data.value):gmatch('%w+') do
            -- collect additional keywords based on the special words
            if word == 'slew' or word == 'slain' then
                collect_keyword('kill')
                collect_keyword('slay')
            elseif word == 'you' or word == 'your' then
                collect_keyword('me')
            end
            -- collect the actual word if it's unique and not ignored
            collect_keyword(word)
        end
    end
    addKeywords(choice, new_keywords)
end

-- Helper function to create new dialog choices, returns the created choice
local function new_choice(choice_type, title, keywords)
    local choice = df.adventure_conversation_choice_infost:new()
    choice.choice = df.talk_choice:new()
    choice.choice.type = choice_type
    local text = df.new("string")
    text.value = title
    choice.title.text:insert("#", text)

    if keywords ~= nil then
        addKeywords(choice, keywords)
    end
    return choice
end

local function addWhereaboutsChoice(race, name, target_id, heard_of)
    local title = "Ask for the whereabouts of the " .. race .. " " .. dfhack.translation.translateName(name, true)
    if heard_of then
        title = title .. " (Heard of)"
    end
    local choice = new_choice(df.talk_choice_type.AskForDirectionsToHF, title, dfhack.translation.translateName(name):split())
    -- insert before the last choice, which is usually "back"
    adventure.conversation.conv_choice_info:insert(#adventure.conversation.conv_choice_info-1, choice)
    choice.choice.invocation_target_hfid = target_id
end

local function addHistFigWhereaboutsChoice(profile)
    local histfig = df.historical_figure.find(profile.histfig_id)
    local race = ""
    local creature = df.creature_raw.find(histfig.race)
    if creature then
        local caste = creature.caste[histfig.caste]
        race = caste.caste_name[0]
    end

    addWhereaboutsChoice(race, histfig.name, histfig.id, profile._type == df.relationship_profile_hf_historicalst)
end

local function addIdentityWhereaboutsChoice(identity)
    local identity_name = identity.name
    local race = ""
    local creature = df.creature_raw.find(identity.race)
    if creature then
        local caste = creature.caste[identity.caste]
        race = caste.caste_name[0]
    else
        -- no race given for the identity, assume it's the histfig
        local histfig = df.historical_figure.find(identity.histfig_id)
        creature = df.creature_raw.find(histfig.race)
        if creature then
            local caste = creature.caste[histfig.caste]
            race = caste.caste_name[0]
        end
    end
    addWhereaboutsChoice(race, identity_name, identity.impersonated_hf)
end

-- Condense the rumor system choices
local function rumorUpdate()
    local conversation_state = adventure.conversation.conv_act.events[0].menu
    -- add new conversation options depending on state

    -- If we're asking about directions, add ability to ask about all our relationships - visual, historical and identities.
    -- In vanilla, we're only allowed to ask for directions to people we learned in anything that's added to df.global.adventure.rumor
    if conversation_state == df.conversation_state_type.AskDirections then
        local adventurer_figure = df.historical_figure.find(dfhack.world.getAdventurer().hist_figure_id)
        local relationships = adventurer_figure.info.relationships

        local visual = relationships.hf_visual
        local historical = relationships.hf_historical
        local identity = relationships.hf_identity

        for _, profile in ipairs(visual) do
            addHistFigWhereaboutsChoice(profile)
        end

        -- This option will likely always fail unless the false identity is impersonating someone
        -- but giving away the false identity's true historical figure feels cheap.
        for _, profile in ipairs(identity) do
            addIdentityWhereaboutsChoice(df.identity.find(profile.identity_id))
        end

        -- Historical entities go last so as to not give away fake identities
        for _, profile in ipairs(historical) do
            addHistFigWhereaboutsChoice(profile)
        end
    end

    -- generate extra keywords for all options
    for i, choice in ipairs(adventure.conversation.conv_choice_info) do
        generateKeywordsForChoice(choice)
    end
end

-- Overlay

AdvRumorsOverlay = defclass(AdvRumorsOverlay, overlay.OverlayWidget)
AdvRumorsOverlay.ATTRS{
    desc='Adds keywords to conversation entries.',
    default_enabled=true,
    viewscreens='dungeonmode/Conversation',
    frame={w=0, h=0},
}

local last_first_entry = nil
function AdvRumorsOverlay:render()
    -- Only update if the first entry pointer changed, this reliably indicates the list changed
    if #adventure.conversation.conv_choice_info <= 0 or last_first_entry == adventure.conversation.conv_choice_info[0] then return end
    -- Remember the last first entry. This entry changes even if we quit out and return on the same menu!
    last_first_entry = adventure.conversation.conv_choice_info[0]
    rumorUpdate()
end
