-- Add pages to written content that have no pages.

local function isBook(item)
    if item and
        df.item_bookst:is_instance(item) or
        df.item_toolst:is_instance(item) and
        (item:getSubtype() == dfhack.items.findSubtype('TOOL:ITEM_TOOL_QUIRE') or
        item:getSubtype() == dfhack.items.findSubtype('TOOL:ITEM_TOOL_SCROLL')) and
        item:hasWriting()
    then
        return true
    end
    return false
end

local function GetBooks(target)
    local books = {}
    local item
    if target.selected then
        local item = dfhack.gui.getSelectedItem(true)
        if item and isBook(item) then table.insert(books, item) end
    elseif target.site then
        local siteTools = df.global.world.items.other.TOOL
        for _, item in ipairs(siteTools) do
            if isBook(item) then table.insert(books, item) end
        end
        local siteBooks = df.global.world.items.other.BOOK
        for _, item in ipairs(siteBooks) do
            if isBook(item) then table.insert(books, item) end
        end
    end
    return books
end

local function GetWrittenContent(book)
    for _, improvement in ipairs(book.improvements) do
        if df.itemimprovement_pagesst:is_instance(improvement) or
            df.itemimprovement_writingst:is_instance(improvement)
        then
            for _, content in ipairs(improvement.contents) do
                return df.written_content.find(content)
            end
        end
    end
    return nil
end

local function GetPageCount(targetWcType)
    -- These values are based on polling page counts from various saves and may not be accurate.
    local types = {
        ['NONE'] = {upperCount = 1, lowerCount = 1, mode = 1},
        ['Manual'] = {upperCount = 250, lowerCount = 20, mode = 80},
        ['Guide'] = {upperCount = 250, lowerCount = 20, mode = 100},
        ['Chronicle'] = {upperCount = 450, lowerCount = 100, mode = nil},
        ['ShortStory'] = {upperCount = 50, lowerCount = 10, mode = nil},
        ['Novel'] = {upperCount = 450, lowerCount = 100, mode = 200},
        ['Biography'] = {upperCount = 400, lowerCount = 100, mode = 250},
        ['Autobiography'] = {upperCount = 450, lowerCount = 100, mode = 250},
        ['Poem'] = {upperCount = 10, lowerCount = 1, mode = 1},
        ['Play'] = {upperCount = 50, lowerCount = 20, mode = 30},
        ['Letter'] = {upperCount = 10, lowerCount = 1, mode = nil},
        ['Essay'] = {upperCount = 50, lowerCount = 10, mode = nil},
        ['Dialog'] = {upperCount = 30, lowerCount = 5, mode = nil},
        ['MusicalComposition'] = {upperCount = 20, lowerCount = 1, mode = 1},
        ['Choreography'] = {upperCount = 1, lowerCount = 1, mode = 1},
        ['ComparativeBiography'] = {upperCount = 300, lowerCount = 150, mode = nil},
        ['BiographicalDictionary'] = {
            upperCount = math.max(300, math.min(500, math.ceil(df.global.hist_figure_next_id / 1000))),
            lowerCount = math.max(100, math.min(150, math.floor(df.global.hist_figure_next_id / 10000))),
            mode = nil}, -- Very few samples were available, so this one is mostly arbitrary.
        ['Genealogy'] = {upperCount = 5, lowerCount = 1, mode = 4},
        ['Encyclopedia'] = {upperCount = 150, lowerCount = 50, mode = nil},
        ['CulturalHistory'] = {upperCount = 450, lowerCount = 100, mode = 200},
        ['CulturalComparison'] = {upperCount = 400, lowerCount = 100, mode = 200},
        ['AlternateHistory'] = {upperCount = 250, lowerCount = 100, mode = 150},
        ['TreatiseOnTechnologicalEvolution'] = {upperCount = 300, lowerCount = 100, mode = nil},
        ['Dictionary'] = {upperCount = 450, lowerCount = 100, mode = 250},
        ['StarChart'] = {upperCount = 1, lowerCount = 1, mode = 1},
        ['StarCatalogue'] = {upperCount = 150, lowerCount = 10, mode = 100},
        ['Atlas'] = {upperCount = 30, lowerCount = 10, mode = 25},
    }
    local upperCount, lowerCount = 1, 1
    local mode
    for wcType, tab in pairs(types) do
        if df.written_content_type[wcType] == targetWcType then
            upperCount = tab.upperCount
            lowerCount = tab.lowerCount
            mode = tab.mode
        end
    end
    return upperCount, lowerCount, mode
end

local function GetPageCountModifier(targetStyle, targetStrength)
    -- These values are arbitrary and may not even have any effect on page count in vanilla DF.
    local styles = {
        ['NONE'] = 0,
        ['Meandering'] = 0.5,
        ['Cheerful'] = 0,
        ['Depressing'] = 0.1,
        ['Rigid'] = 0,
        ['Serious'] = 0,
        ['Disjointed'] = 0.2,
        ['Ornate'] = 0.2,
        ['Forceful'] = 0,
        ['Humorous'] = 0,
        ['Immature'] = 0.3,
        ['SelfIndulgent'] = 0.5,
        ['Touching'] = 0,
        ['Compassionate'] = 0,
        ['Vicious'] = 0,
        ['Concise'] = -0.2,
        ['Scornful'] = 0,
        ['Witty'] = 0,
        ['Ranting'] = 1,
    }
    local strength = {
        ['NONE'] = 1,
        ['Thorough'] = 1.5,
        ['Somewhat'] = 1,
        ['Hint'] = 0.5,
    }
    local pageCountModifier = 0
    for style, modifier in pairs(styles) do
        if df.written_content_style[style] == targetStyle then
            pageCountModifier = modifier
            break
        end
    end
    for strength, addModifier in pairs(strength) do
        if df.writing_style_modifier_type[strength] == targetStrength then
            if pageCountModifier ~= 0 then
                pageCountModifier = pageCountModifier * addModifier
                break
            end
        end
    end
    return pageCountModifier
end

local rng = dfhack.random.new(nil, 10)
local seed = dfhack.world.ReadCurrentTick()

local function SetPageCount(upperCount, lowerCount, mode)
    if upperCount > 1 then
        local range = upperCount - lowerCount
        local increment = 1 + math.floor(range ^ 2)
        local weightedTable = {}
        local weight = 0
        for i = lowerCount, upperCount, 1 do
            weight = weight + increment - math.floor(math.abs(i - mode) ^ 2)
            if i == mode and mode == 1 then
                -- Set heavy bias for very short written forms with mostly 1 page long works.
                weight = weight + increment ^ 2
            end
            table.insert(weightedTable, weight)
        end
        local limit = weight
        rng:init(seed, 10)
        local result = rng:random(limit)
        for i, weight in ipairs(weightedTable) do
            if result <= weight then
                return i + lowerCount - 1
            end
        end
    end
    return 1
end

local function AddPages(wc)
    local pages = 0
    if wc.page_start == -1 and wc.page_end == -1 then
        local wcType = wc.type
        local upperCount, lowerCount, mode = GetPageCount(wcType)
        if upperCount and lowerCount then
            local modifier = 1
            for i, style in ipairs(wc.styles) do
                if wc.style_strength[i] then
                    modifier = modifier + GetPageCountModifier(style, wc.style_strength[i])
                end
            end
            upperCount = math.max(1, math.ceil(upperCount * modifier))
            lowerCount = math.max(1, math.floor(lowerCount * modifier))
            if mode and mode ~= 1 then
                mode = math.max(1, math.floor(mode * modifier))
            end
        else
            upperCount, lowerCount = 1, 1
        end
        mode = mode or math.ceil((lowerCount + upperCount) / 2)
        wc.page_start = 1
        wc.page_end = SetPageCount(upperCount, lowerCount, mode)
        pages = wc.page_end
    end
    return pages
end

local function FixPageCount(target)
    local writtenContents = {}
    if not target.all then
        local books = GetBooks(target)
        if #books == 0 then
            if target.selected then
                print('No book with written content selected.')
            elseif target.site then
                print('No books available in site.')
            end
            return
        end
        for _, book in ipairs(books) do
            table.insert(writtenContents, GetWrittenContent(book))
        end
    else
        writtenContents = df.global.world.written_contents.all
    end
    local booksModified = 0
    local pagesAdded = 0
    for _, wc in ipairs(writtenContents) do
        local pages = 0
        pages = AddPages(wc)
        if pages > 0 then
            local title
            if wc.title == '' then
                title = 'an untitled work'
            else
                title = ('"%s"'):format(wc.title)
            end
            print(('%d pages added to %s.'):format(pages, title))
            pagesAdded = pagesAdded + pages
            seed = seed + pages
            booksModified = booksModified + 1
        end
    end
    if booksModified > 0 then
        local plural = ''
        if booksModified > 1 then plural = 's' end
        print(('\nA total of %d pages were added to %d book%s.'):format(pagesAdded, booksModified, plural))
    elseif target.selected then
        print('Selected book already has pages in it.')
    else
        print('No written content with unspecified page counts were found; no pages were added to any books.')
    end
end

local function Main(args)
    local target = {
        selected = false,
        site = false,
        all = false,
    }
    if #args > 0 then
        if args[1] == 'help' then
            print(dfhack.script_help())
            return
        end
        if args[1] == 'this' then target.selected = true end
        if args[1] == 'site' then target.site = true end
        if args[1] == 'all' then target.all = true end
        FixPageCount(target)
    end
end

if not dfhack.isSiteLoaded() and not dfhack.world.isFortressMode() then
    qerror('This script requires the game to be in fortress mode.')
end

Main({...})
