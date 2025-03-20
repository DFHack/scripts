--@ module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local toolbar_textures = (dfhack.textures.loadTileset('hack/data/art/sitemap_toolbar.png', 8,12))

function launch_sitemap()
    dfhack.run_command('gui/sitemap')
end


-- --------------------------------
-- SitemapToolbarOverlay
--

SitemapToolbarOverlay = defclass(SitemapToolbarOverlay, overlay.OverlayWidget)
SitemapToolbarOverlay.ATTRS{
    desc='Adds widgets to the erase interface to open the mass removal tool',
    default_pos={x=35, y=-1},
    default_enabled=true,
    viewscreens={
        'dwarfmode'
    },
    frame={w=28, h=9},
}

function SitemapToolbarOverlay:init()
    local button_chars = {
        {218, 196, 196, 191},
        {179, '-', 'O', 179},
        {192, 196, 196, 217},
    }

    self:addviews{
        widgets.Panel{
            frame={t=0, l=0, w=26, h=5},
            frame_style=gui.FRAME_PANEL,
            frame_background=gui.CLEAR_PEN,
            frame_inset={l=1, r=1},
            visible=function() return not not self.subviews.icon:getMousePos() end,
            subviews={
                widgets.Label{
                    text={
                        'Open the sitemap menu.', NEWLINE,
                        NEWLINE,
                        {text='Hotkey: ', pen=COLOR_GRAY}, {key='CUSTOM_CTRL_G'},
                    },
                },
            },
        },
        widgets.Panel{
            view_id='icon',
            frame={b=0, l=0, w=4, h=3},
            subviews={
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens=COLOR_GRAY,
                        tileset=toolbar_textures,
                        tileset_offset=1,
                        tileset_stride=8,
                    },
                    on_click=launch_sitemap,
                    visible=function () return not self.subviews.icon:getMousePos() end,
                },
                widgets.Label{
                    text=widgets.makeButtonLabelText{
                        chars=button_chars,
                        pens={
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                            {COLOR_WHITE, COLOR_GRAY,  COLOR_GRAY,  COLOR_WHITE},
                            {COLOR_WHITE, COLOR_WHITE, COLOR_WHITE, COLOR_WHITE},
                        },
                        tileset=toolbar_textures,
                        tileset_offset=5,
                        tileset_stride=8,
                    },
                    on_click=launch_sitemap,
                    visible=function() return not not self.subviews.icon:getMousePos() end,
                },
            },
        },
    }
end

function SitemapToolbarOverlay:onInput(keys)
    if keys.CUSTOM_CTRL_G then
        launch_sitemap()
        return true
    end
    return SitemapToolbarOverlay.super.onInput(self, keys)
end

OVERLAY_WIDGETS = {sitemaptoolbar=SitemapToolbarOverlay}

if dfhack_flags.module then
    return
end
