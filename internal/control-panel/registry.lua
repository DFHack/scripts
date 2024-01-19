--@module = true

local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')

-- please keep in alphabetical order per group
-- add a 'version' attribute if we want to reset existing configs for a command to the default
COMMANDS_BY_IDX = {
    -- automation tools
    {command='autobutcher', group='automation', mode='enable'},
    {command='autobutcher target 10 10 14 2 BIRD_GOOSE', group='automation', mode='run',
        desc='Enable if you usually want to raise geese.'},
    {command='autobutcher target 10 10 14 2 BIRD_TURKEY', group='automation', mode='run',
        desc='Enable if you usually want to raise turkeys.'},
    {command='autobutcher target 10 10 14 2 BIRD_CHICKEN', group='automation', mode='run',
        desc='Enable if you usually want to raise chickens.'},
    {command='autochop', group='automation', mode='enable'},
    {command='autoclothing', group='automation', mode='enable'},
    {command='autofarm', group='automation', mode='enable'},
    {command='autofarm threshold 150 grass_tail_pig', group='automation', mode='run',
        desc='Enable if you usually farm pig tails for the clothing industry.'},
    {command='autofish', group='automation', mode='enable'},
    --{command='autolabor', group='automation', mode='enable'}, -- hide until it works better
    {command='automilk', help_command='workorder', group='automation', mode='repeat',
        desc='Automatically milk creatures that are ready for milking.',
        params={'--time', '14', '--timeUnits', 'days', '--command', '[', 'workorder', '"{\\"job\\":\\"MilkCreature\\",\\"item_conditions\\":[{\\"condition\\":\\"AtLeast\\",\\"value\\":2,\\"flags\\":[\\"empty\\"],\\"item_type\\":\\"BUCKET\\"}]}"', ']'}},
    {command='autonestbox', group='automation', mode='enable'},
    {command='autoshear', help_command='workorder', group='automation', mode='repeat',
        desc='Automatically shear creatures that are ready for shearing.',
        params={'--time', '14', '--timeUnits', 'days', '--command', '[', 'workorder', 'ShearCreature', ']'}},
    {command='autoslab', group='automation', mode='enable'},
    {command='ban-cooking all', group='automation', mode='run'},
    {command='buildingplan set boulders false', group='automation', mode='run',
        desc='Enable if you usually don\'t want to use boulders for construction.'},
    {command='buildingplan set logs false', group='automation', mode='run',
        desc='Enable if you usually don\'t want to use logs for construction.'},
    {command='cleanowned', group='automation', mode='repeat',
        desc='Encourage dwarves to drop tattered clothing and grab new ones.',
        params={'--time', '1', '--timeUnits', 'months', '--command', '[', 'cleanowned', 'X', ']'}},
    {command='gui/settings-manager load-standing-orders', group='automation', mode='run',
        desc='Go to the Standing Orders tab in the Labor screen to save your current settings.'},
    {command='nestboxes', group='automation', mode='enable'},
    {command='orders-sort', help_command='orders', group='automation', mode='repeat',
        desc='Sort manager orders by repeat frequency so one-time orders can be completed.',
        params={'--time', '1', '--timeUnits', 'days', '--command', '[', 'orders', 'sort', ']'}},
    {command='prioritize', group='automation', mode='enable'},
    {command='seedwatch', group='automation', mode='enable'},
    {command='suspendmanager', group='automation', mode='enable'},
    {command='tailor', group='automation', mode='enable'},

    -- bugfix tools
    {command='fix/blood-del', group='bugfix', mode='run', default=true},
    {command='fix/dead-units', group='bugfix', mode='repeat', default=true,
        desc='Fix units still being assigned to burrows after death.',
        params={'--time', '7', '--timeUnits', 'days', '--command', '[', 'fix/dead-units', '--burrow', '-q', ']'}},
    {command='fix/empty-wheelbarrows', group='bugfix', mode='repeat', default=true,
        desc='Make abandoned full wheelbarrows usable again.',
        params={'--time', '1', '--timeUnits', 'days', '--command', '[', 'fix/empty-wheelbarrows', '-q', ']'}},
    {command='fix/general-strike', group='bugfix', mode='repeat', default=true,
        desc='Prevent dwarves from getting stuck and refusing to work.',
        params={'--time', '1', '--timeUnits', 'days', '--command', '[', 'fix/general-strike', '-q', ']'}},
    {command='fix/protect-nicks', group='bugfix', mode='enable', default=true},
    {command='fix/stuck-instruments', group='bugfix', mode='repeat', default=true,
        desc='Fix activity references on stuck instruments to make them usable again.',
        params={'--time', '1', '--timeUnits', 'days', '--command', '[', 'fix/stuck-instruments', ']'}},
    {command='fix/workorder-details', group='bugfix', mode='enable', default=true},
    {command='preserve-tombs', group='bugfix', mode='enable', default=true},

    -- gameplay tools
    {command='combine', group='gameplay', mode='repeat',
        desc='Combine partial stacks in stockpiles into full stacks.',
        params={'--time', '7', '--timeUnits', 'days', '--command', '[', 'combine', 'all', '-q', ']'}},
    {command='drain-aquifer --top 2', group='gameplay', mode='run',
        desc='Ensure that your maps have no more than 2 layers of aquifer.'},
    {command='dwarfvet', group='gameplay', mode='enable'},
    {command='emigration', group='gameplay', mode='enable'},
    {command='fastdwarf', group='gameplay', mode='enable'},
    {command='hermit', group='gameplay', mode='enable'},
    {command='hide-tutorials', group='gameplay', mode='system_enable'},
    {command='light-aquifers-only', group='gameplay', mode='run'},
    {command='misery', group='gameplay', mode='enable'},
    {command='orders-reevaluate', help_command='orders', group='gameplay', mode='repeat',
        desc='Invalidates all work orders once a month, allowing conditions to be rechecked.',
        params={'--time', '1', '--timeUnits', 'months', '--command', '[', 'orders', 'recheck', ']'}},
    {command='starvingdead', group='gameplay', mode='enable'},
    {command='warn-starving', group='gameplay', mode='repeat', default=true,
        desc='Show a warning dialog when units are starving or dehydrated.',
        params={'--time', '10', '--timeUnits', 'days', '--command', '[', 'warn-starving', ']'}},
    {command='warn-stranded', group='gameplay', mode='repeat',
        desc='Show a warning dialog when units are stranded from all others.',
        params={'--time', '2', '--timeUnits', 'days', '--command', '[', 'warn-stranded', ']'}},
    {command='work-now', group='gameplay', mode='enable'},
}

COMMANDS_BY_NAME = {}
for _,data in ipairs(COMMANDS_BY_IDX) do
    COMMANDS_BY_NAME[data.command] = data
end

-- keep in desired display order
PREFERENCES_BY_IDX = {
    {
        name='HIDE_ARMOK_TOOLS',
        label='Mortal mode: hide "armok" tools',
        desc='Don\'t show tools that give you god-like powers wherever DFHack tools are listed.',
        default=false,
        get_fn=function() return dfhack.HIDE_ARMOK_TOOLS end,
        set_fn=function(val) dfhack.HIDE_ARMOK_TOOLS = val end,
    },
    {
        name='FILTER_FULL_TEXT',
        label='DFHack searches full text',
        desc='When searching, whether to match anywhere in the text (true) or just at the start of words (false).',
        default=false,
        get_fn=function() return utils.FILTER_FULL_TEXT end,
        set_fn=function(val) utils.FILTER_FULL_TEXT = val end,
    },
    {
        name='HIDE_CONSOLE_ON_STARTUP',
        label='Hide console on startup (MS Windows only)',
        desc='Hide the external DFHack terminal window on startup. Use the "show" command to unhide it.',
        default=true,
        get_fn=function() return dfhack.HIDE_CONSOLE_ON_STARTUP end,
        set_fn=function(val) dfhack.HIDE_CONSOLE_ON_STARTUP = val end,
    },
    {
        name='DEFAULT_INITIAL_PAUSE',
        label='DFHack tools autopause game',
        desc='Always pause the game when a DFHack tool window is shown (you can still unpause afterwards).',
        default=true,
        get_fn=function() return gui.DEFAULT_INITIAL_PAUSE end,
        set_fn=function(val) gui.DEFAULT_INITIAL_PAUSE = val end,
    },
    {
        name='INTERCEPT_HANDLED_HOTKEYS',
        label='Intercept handled hotkeys',
        desc='Prevent key events handled by DFHack windows from also affecting the vanilla widgets.',
        default=true,
        get_fn=dfhack.internal.getSuppressDuplicateKeyboardEvents,
        set_fn=dfhack.internal.setSuppressDuplicateKeyboardEvents,
    },
    {
        name='DOUBLE_CLICK_MS',
        label='Mouse double click speed (ms)',
        desc='How long to wait for the second click of a double click, in ms.',
        default=500,
        min=50,
        get_fn=function() return widgets.DOUBLE_CLICK_MS end,
        set_fn=function(val) widgets.DOUBLE_CLICK_MS = val end,
    },
    {
        name='SCROLL_DELAY_MS',
        label='Mouse scroll repeat delay (ms)',
        desc='The delay between events when holding the mouse button down on a scrollbar, in ms.',
        default=20,
        min=5,
        get_fn=function() return widgets.SCROLL_DELAY_MS end,
        set_fn=function(val) widgets.SCROLL_DELAY_MS = val end,
    },
    {
        name='SCROLL_INITIAL_DELAY_MS',
        label='Mouse initial scroll repeat delay (ms)',
        desc='The delay before scrolling quickly when holding the mouse button down on a scrollbar, in ms.',
        default=300,
        min=5,
        get_fn=function() return widgets.SCROLL_INITIAL_DELAY_MS end,
        set_fn=function(val) widgets.SCROLL_INITIAL_DELAY_MS = val end,
    },
}

PREFERENCES_BY_NAME = {}
for _,data in ipairs(PREFERENCES_BY_IDX) do
    PREFERENCES_BY_NAME[data.name] = data
end
