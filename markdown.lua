-- Save selected unit/item' description in markdown (e.g., for reddit)
-- This script extracts descriptions of selected units or items and saves them in markdown format.
-- This is a derivatiwe work based upon scripts/forum-dwarves.lua by Caldfir and expwnent
-- Adapted for markdown by Mchl https://github.com/Mchl
-- Updated to work with Steam version by Glotov4 https://github.com/glotov4 

local helpstr = [====[

markdown
===========
Tags: fort | inspection | units

Save a description of selected unit or item to a markdown file.

This script will attempt to get description of selected unit or item.
For units, script will collect:
- Name, race, age, profession
- Description, as seen at the Unit/Health/Description screen
- Traits, as seen at the Unit/Personality/Traits

For items:
- Decorated name ("☼«☼Chalk Statue of Dakas☼»☼")
- Full description, as seen when clicking "View this item's sheet"

Then the script will append marked-down version of this data 
to the target file (for easy pasting on reddit for example).

This script doesn't work with the data from other screens.

Previous entries in the file are not overwritten, so you
may use the ``markdown`` command multiple times to create a single
document containing the description of multiple items & units.

By default, data is stored in markdown_/YourWorldName/_export.md

See `forum-dwarves` for BBCode export (for e.g. the Bay12 Forums).

Usage
-----

    markdown [-n] [filename]

:-n:    overwrites contents of output file
:filename:
        if provided, save to :file:`markdown_{filename}.md` instead
        of the default :file:`markdown_/worldName/_export.md`
:help: show help 

Examples
-----

### -chalk statue of Bìlalo Bandbeach-

#### Description: 
This is a well-crafted chalk statue of Bìlalo Bandbeach.  The item is a well-designed image of Bìlalo Bandbeach the elf and Lani Lyricmonks the Learned the ettin in chalk by Domas Uthmiklikot.  Lani Lyricmonks the Learned is striking down Bìlalo Bandbeach.  The artwork relates to the killing of the elf Bìlalo Bandbeach by the ettin Lani Lyricmonks the Learned with Hailbite in The Forest of Indignation in 147.  

---

### Lokum Alnisendok, dwarf, 27 years old Presser.

#### Description: 
A short, sturdy creature fond of drink and industry.

He is very quick to tire.  

His very long beard is neatly combed.  His very long sideburns are braided.  His very long moustache is neatly combed.  His hair is clean-shaven.  He is average in size.  His nose is sharply hooked.  His nose bridge is convex.  His gold eyes are slightly wide-set.  His somewhat tall ears are somewhat narrow.  His hair is copper.  His skin is copper.  

#### Personality: 
He has an amazing memory, but he has a questionable spatial sense and poor focus.  

He doesn't generally think before acting.  He feels a strong need to reciprocate any favor done for him.  He enjoys the company of others.  He does not easily hate or develop negative feelings.  He generally finds himself quite hopeful about the future.  He tends to be swayed by the emotions of others.  He finds obligations confining, though he is conflicted by this for more than one reason.  He doesn't tend to hold on to grievances.  He has an active imagination.  

He needs alcohol to get through the working day.  

---
]====]

local utils = require('utils')
local gui = require('gui')

-- Argument processing
local args = {...}
if args[1] == 'help' then
    print(helpstr)
    return
end

-- Determine file write mode and filename
local writemode = 'a' -- append (default)
local filename
local worldName = dfhack.df2utf(dfhack.TranslateName(df.global.world.world_data.name)):gsub(" ", "_")

if args[1] == '-n' or args[1] == '/n' then
    writemode = 'w' -- overwrite
    table.remove(args, 1)
end

if args[1] ~= nil then
    filename = 'markdown_' .. table.remove(args, 1) .. '.md'
else
    filename = 'markdown_' .. worldName .. '_export.md'
end

-- Utility functions
local function getFileHandle()
    return assert(io.open(filename, writemode), "Error opening file: " .. filename)
end

local function closeFileHandle(handle)
    handle:write('\n---\n\n')
    handle:close()
    print ('\nData exported to "' .. filename .. '"')
end

local function reformat(str)
    -- [B] tags seem to indicate a new paragraph
    -- [R] tags seem to indicate a sub-blocks of text.Treat them as paragraphs.
    -- [P] tags seem to be redundant
    -- [C] tags indicate color. Remove all color information
    return str:gsub('%[B%]', '\n\n')
              :gsub('%[R%]', '\n\n')
              :gsub('%[P%]', '')
              :gsub('%[C:%d+:%d+:%d+%]', '')
              :gsub('\n\n+', '\n\n')
end

local function getNameRaceAgeProf(unit)
    --%s is a placeholder for a string, and %d is a placeholder for a number.
    return string.format("%s, %d years old %s.", dfhack.units.getReadableName(unit), df.global.cur_year - unit.birth_year, dfhack.units.getProfessionName(unit))
end

-- Main logic for item and unit processing
local item = dfhack.gui.getSelectedItem(true)
local unit = dfhack.gui.getSelectedUnit(true)

if not item and not unit then
    print([[
Error: No unit or item is currently selected.
- To select a unit, click on it.
- For items that are installed as buildings (like statues or beds), 
open the building's interface in the game and click the magnifying glass icon.

Please select a valid target in the game and try running the script again.]])
    -- Early return to avoid proceeding further
    return
end

local log = getFileHandle()

if item then
    -- Item processing
    local item_raw_name = dfhack.items.getDescription(item, 0, true)
    local item_raw_description = df.global.game.main_interface.view_sheets.raw_description
    log:write('### ' .. dfhack.df2utf(item_raw_name) .. '\n\n#### Description: \n' .. reformat(dfhack.df2utf(item_raw_description)) .. '\n')
    print('Exporting description of the ' .. item_raw_name)

elseif unit then   
    -- Unit processing
    -- Simulate UI interactions to load data into memory (click through tabs)
    local screen = dfhack.gui.getDFViewscreen()
    -- Click "Personality" 
    df.global.gps.mouse_x = 145
    df.global.gps.mouse_y = 11
    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health"
    df.global.gps.mouse_x = 118
    df.global.gps.mouse_y = 13
    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health/Description"
    df.global.gps.mouse_x = 142
    df.global.gps.mouse_y = 15
    gui.simulateInput(screen, '_MOUSE_L')

    local unit_description_raw = df.global.game.main_interface.view_sheets.unit_health_raw_str[0].value
    local unit_personality_raw = df.global.game.main_interface.view_sheets.personality_raw_str

    if unit_description_raw or unit_personality_raw then
        log:write('### ' .. dfhack.df2utf(getNameRaceAgeProf(unit)) .. '\n\n#### Description: \n' .. reformat(dfhack.df2utf(unit_description_raw)) .. '\n\n#### Personality: \n')
        for _, unit_personality in ipairs(unit_personality_raw) do
            log:write(reformat(dfhack.df2utf(unit_personality.value)) .. '\n')
        end
        print('Exporting Health/Description & Personality/Traits data for: \n' .. dfhack.df2console(getNameRaceAgeProf(unit)))
    else
        print("Unit has no data in Description & Personality tabs")
    end
else 
end

closeFileHandle(log)