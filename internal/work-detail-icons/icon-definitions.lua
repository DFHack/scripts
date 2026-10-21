-- Vanilla and DFHack duilt-in work detail icon definitions to pass to make_icon_text
--@module=true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

-- vanilla icon sprites will be loaded using the asset attribute in widgets.makeButtonLabelText
-- while DFHack ones (including user-defined) will use the tileset attr instead

IconDef = defclass(IconDef)
IconDef.ATTRS{
    ch1=' ',
    ch2=' ',
    
    fg1=COLOR_WHITE,
    fg2=COLOR_WHITE,
    bg2=COLOR_BLACK,
    bg2=COLOR_BLACK,
}

--
-- Vanilla
--

local lab = 'INTERFACE_BITS_LABOR'
local loc = 'INTERFACE_BITS_LOCATIONS'

VanillaIconDef = defclass(VanillaIconDef, IconDef)
VanillaIconDef.ATTRS{
    asset={},
}

vanilla = {
    -- adhering to the names given in the raws (graphics_interface.txt) where possible
    MINERS = VanillaIconDef{
        ch1='-',
        ch2=')',
        
        fg1=COLOR_BROWN,
        fg2=COLOR_DARKGREY,
        
        asset={page=lab, x=20, y=0},
    },
    WOODCUTTERS = VanillaIconDef{
        -- /♠
        ch1='/',
        ch2=6,
        
        fg1=COLOR_DARKGREY,
        fg2=COLOR_GREEN,
        
        asset={page=lab, x=24, y=0},
    },
    -- todo: add the rest
}

--
-- DFHack
--

local builtin_sprites = dfhack.textures.loadTileset('hack/data/art/work-details.png', 8, 12, true)
local column_count = 9
-- todo: calculate offset automatically

DFHackIconDef = defclass(DFHackIconDef, IconDef)
DFHackIconDef.ATTRS{
    tileset=builtin_sprites,
    tileset_stride=4*column_count,
    tileset_offset=1,
}

builtin = { -- obv. placeholders
    MAGENTA = DFHackIconDef{
        -- pasting the ascii for any of these into a comment makes lua unable to parse the script 
        ch1=176, -- the left one won't show up for some reason
        ch2=176,
        
        fg1=COLOR_BLACK,
        fg2=COLOR_BLACK,
        bg1=COLOR_MAGENTA,
        bg2=COLOR_MAGENTA,
        
        tileset_offset=1,
    },
    YELLOW = DFHackIconDef{ -- causes weird flickering
        ch1=177,
        ch2=177,
        
        fg1=COLOR_YELLOW,
        fg2=COLOR_YELLOW,
        
        tileset_offset=(4*1)+1,
    },
    CYAN = DFHackIconDef{
        ch1=178,
        ch2=178,
        
        fg1=COLOR_CYAN,
        fg2=COLOR_CYAN,
        
        tileset_offset=(12*column_count*1)+(4*1)+1,
    },
}
