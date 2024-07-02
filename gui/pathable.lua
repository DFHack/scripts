-- View whether tiles on the map can be pathed to.
--@module=true

local gui = require('gui')
local plugin = require('plugins.pathable')
local widgets = require('gui.widgets')

-- ------------------------------
-- FollowMousePage

FollowMousePage = defclass(FollowMousePage, widgets.Panel)

function FollowMousePage:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='draw',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_D',
            label='Draw:',
            label_width=12,
            initial_option=true,
        },
        widgets.ToggleHotkeyLabel{
            view_id='lock',
            frame={t=1, l=0},
            key='CUSTOM_CTRL_M',
            label='Lock target:',
            initial_option=false,
        },
        widgets.ToggleHotkeyLabel{
            view_id='show',
            frame={t=2, l=0},
            key='CUSTOM_CTRL_U',
            label='Show hidden:',
            initial_option=false,
        },
        widgets.Label{
            frame={t=4, l=0},
            text='Pathability group:',
        },
        widgets.Label{
            view_id='group',
            frame={t=4, l=19, h=1},
            text='',
            text_pen=COLOR_LIGHTCYAN,
            auto_height=false,
        },
    }
end

function FollowMousePage:onRenderBody()
    local target = self.subviews.lock:getOptionValue() and
            self.saved_target or dfhack.gui.getMousePos()
    self.saved_target = target

    local group = self.subviews.group
    local show = self.subviews.show:getOptionValue()

    if not target then
        group:setText('')
    elseif not show and not dfhack.maps.isTileVisible(target) then
        group:setText('Hidden')
    else
        local walk_group = dfhack.maps.getWalkableGroup(target)
        group:setText(walk_group == 0 and 'None' or tostring(walk_group))

        if self.subviews.draw:getOptionValue() then
            plugin.paintScreenPathable(target, show)
        end
    end
end

-- ------------------------------
-- DepotPage

DepotPage = defclass(DepotPage, widgets.Panel)
DepotPage.ATTRS {
    force_pause=true,
}

function DepotPage:init()
    if dfhack.world.isAdventureMode() then
        self:addviews{
            widgets.WrappedLabel{
                text_to_wrap='Not available in adventure mode.',
                text_pen=COLOR_YELLOW,
            },
        }
        return
    end

    self.animals = false
    self.wagons = false

    local TD = df.global.world.buildings.other.TRADE_DEPOT
    local depot_idx = 0

    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='Depot is reachable by:',
        },
        widgets.Label{
            frame={t=1, l=2},
            text={
                'Pack animals:',
                {gap=1, text=function() return self.animals and 'Yes' or 'No' end,
                 pen=function() return self.animals and COLOR_GREEN or COLOR_RED end},
            },
        },
        widgets.Label{
            frame={t=2, l=8},
            text={
                'Wagons:',
                {gap=1, text=function() return self.wagons and 'Yes' or 'No' end,
                 pen=function() return self.wagons and COLOR_GREEN or COLOR_RED end},
            },
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            key='CUSTOM_CTRL_D',
            label='Zoom to depot',
            on_activate=function()
                depot_idx = depot_idx + 1
                if depot_idx >= #TD then depot_idx = 0 end
                local bld = TD[depot_idx]
                dfhack.gui.revealInDwarfmodeMap(xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
            end,
            enabled=#TD > 0,
        },
    }
end

function DepotPage:on_show()
    self.animals = plugin.getDepotAccessibleByAnimals()
    self.wagons = plugin.getDepotAccessibleByWagons(true)
end

function DepotPage:onRenderBody()
    plugin.paintScreenDepotAccess()
end

-- ------------------------------
-- Pathable

Pathable = defclass(Pathable, widgets.Window)
Pathable.ATTRS {
    frame_title='Pathability Viewer',
    frame={t=18, r=2, w=30, h=12},
}

function Pathable:init()
    self:addviews{
        widgets.TabBar{
            frame={t=0, l=0},
            labels={
                'Follow mouse',
                'Depot',
            },
            on_select=function(idx)
                self.subviews.pages:setSelected(idx)
                local _, page = self.subviews.pages:getSelected()
                self.parent_view.force_pause = page.force_pause
                if page.on_show then
                    page:on_show()
                end
            end,
            get_cur_page=function() return self.subviews.pages:getSelected() end,
        },
        widgets.Pages{
            view_id='pages',
            frame={t=3, l=0, b=0, r=0},
            subviews={
                FollowMousePage{},
                DepotPage{},
            },
        },
    }
end

-- ------------------------------
-- PathableScreen

PathableScreen = defclass(PathableScreen, gui.ZScreen)
PathableScreen.ATTRS {
    focus_path='pathable',
    pass_movement_keys=true,
}

function PathableScreen:init()
    self:addviews{Pathable{}}
end

function PathableScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

-- ------------------------------
-- CLI

if not dfhack.isMapLoaded() then
    qerror('gui/pathable requires a map to be loaded')
end

view = view and view:raise() or PathableScreen{}:show()
