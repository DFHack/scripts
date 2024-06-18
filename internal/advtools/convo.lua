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
    for _, keyword in ipairs(choice.key_word) do
        table.insert(keywords, keyword.value:lower())
    end
    return keywords
end

-- Adds a keyword to the dialog choice
local function addKeyword(choice, keyword)
    local keyword_ptr = df.new('string')
    keyword_ptr.value = keyword
    choice.key_word:insert('#', keyword_ptr)
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
    for _, data in ipairs(choice.print_string.text) do
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

-- Condense the rumor system choices
local function rumorUpdate()
    for i, choice in ipairs(adventure.conversation.conv_choice_info) do
        generateKeywordsForChoice(choice)
    end
end

-- Overlay

AdvRumorsOverlay = defclass(AdvRumorsOverlay, overlay.OverlayWidget)
AdvRumorsOverlay.ATTRS{
    desc='Adds keywords to conversation entries.',
    overlay_only=true,
    default_enabled=true,
    viewscreens='dungeonmode/Conversation',
}

function AdvRumorsOverlay:render()
    rumorUpdate()
end
