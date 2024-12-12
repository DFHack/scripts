-- Find and real-time track historical figures in adventurer mode

local repeatUtil = require 'repeat-util'
local gui = require('gui')
local widgets = require('gui.widgets')

local function matchName(searchName, nameObj)
    translated = dfhack.TranslateName(nameObj, true)
    notTranslated = dfhack.TranslateName(nameObj, false)
    searchName = string.lower(searchName)
    if string.match(string.lower(translated), searchName) then
        return translated
    end

    if string.match(string.lower(notTranslated), searchName) then
        return notTranslated
    end
    return false
end

local function getHFnemesisFromName(searchName)
    finds = {}
    for id, hf in pairs(df.global.world.history.figures) do
        name = matchName(searchName, hf.name)
        if name then
            table.insert(finds, {name, hf.unit_id, hf.site_links, hf})
        end
    end
    return finds
end

local function getAdvRegionPos()
    -- traveling world map
    for id, adv in pairs(df.global.world.armies.all) do
        if adv.flags[0] == true then
            return {region = {x = math.floor(adv.pos.x / 48), y = math.floor(adv.pos.y / 48)}, global = adv.pos}
        end
    end
    -- in site
    return {region = {x = df.global.world.world_data.midmap_data.adv_region_x, y = df.global.world.world_data.midmap_data.adv_region_y}, loc = dfhack.world.getAdventurer().pos}
end

local function getPosFromHistFig(hf)
    -- Not in this realm
    if hf.appeared_year == -1 and hf.died_year == -1 and hf.born_year == -1 and hf.profession == -1 then
        return {type = "otherworld"}
    end

    -- check if in same site
    for _,unit in ipairs(df.global.world.units.all) do
        if unit.id == hf.unit_id then
            return {type = "local", pos = unit.pos}
        end
    end

    --check if already as nemesis in a site
    for _, site in ipairs(df.global.world.world_data.sites) do
        for _, nem in ipairs(site.populace.nemesis) do
            if nem == hf.nemesis_id then
                if hf.info.whereabouts.abs_smm_x ~= -1 then
                    local globPos = {x = hf.info.whereabouts.abs_smm_x, y = hf.info.whereabouts.abs_smm_y}
                    return {type = "site", siteName = site.name, pos = site.pos, globPos = globPos}
                end
                return {type = "site", siteName = site.name, pos = site.pos}
            end
        end
    end

    --check if already as nemesis in an army
    for _, army in ipairs(df.global.world.armies.all) do
        for _, member in ipairs(army.members) do
            if member.nemesis_id == hf.nemesis_id then
                return {type = "army", pos = army.pos}
            end
        end
    end

    for _, siteLair in pairs(hf.site_links) do
        -- What if more than one lair???
        local site = df.world_site.find(siteLair.site)
        if hf.info.whereabouts.abs_smm_x ~= -1 then
            local globPos = {x = hf.info.whereabouts.abs_smm_x, y = hf.info.whereabouts.abs_smm_y}
            return {type = "site", siteName = site.name, pos = site.pos, globPos = globPos}
        end
        return {type = "site", siteName = site.name, pos = site.pos}
    end

    return nil
end

local HIGHLIGHT_PEN = dfhack.pen.parse{
    ch=string.byte(' '),
    fg=COLOR_LIGHTGREEN,
    bg=COLOR_LIGHTGREEN,
}

HFfindWindow = defclass(HFfindWindow, widgets.Window)
HFfindWindow.ATTRS{
    frame={w=75, h=25, t = 18, r = 2},
    frame_title='find HF'
}

function HFfindWindow:init()
    self:addviews{
        widgets.Label{
            view_id = 'label1',
            text={{text='Search: ', pen=COLOR_LIGHTGREEN}},
            frame = {t = 0, l = 0}
        },
        widgets.List{
            view_id = 'selection',
            frame = {t = 2, l = 0, w = 40},
            on_submit = self:callback("on_submit_choice")
        },
        widgets.Label{
            view_id = 'label2',
            text = " ",
            frame = {t = 1, l = 4}
        },
        widgets.EditField{
            view_id = 'editfield',
            frame = {t = 0, l = 8},
            on_submit = self:callback("on_edit_change")
        },
        -- Adv position info
        widgets.Panel{
            view_id = "advPanel",
            frame = {t = 1, l = 42, w = 30, h = 7},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'advPosLabel',
                    text = "",
                    frame = {t = 0, l = 0}
                },
            },
        },
        -- HF position info
        widgets.Panel{
            view_id = "HFPanel",
            frame = {t = 12, l = 42, w = 30, h = 10},
            frame_style = gui.FRAME_INTERIOR,
            subviews = {
                widgets.Label{
                    view_id = 'HFPosLabel1',
                    text = " ",
                    frame = {t = 0, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel2',
                    text = " ",
                    frame = {t = 1, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel3',
                    text = " ",
                    frame = {t = 2, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel4',
                    text = " ",
                    frame = {t = 3, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel5',
                    text = " ",
                    frame = {t = 4, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel6',
                    text = " ",
                    frame = {t = 5, l = 0}
                },
                widgets.Label{
                    view_id = 'HFPosLabel7',
                    text = " ",
                    frame = {t = 6, l = 0}
                },
            },
        }
    }

    self.firstSelection = true
    repeatUtil.scheduleEvery('findHF', 10, 'frames', function()
        local advPos = getAdvRegionPos()
        local advPosInfo = string.format("           You\nregion: X%d Y%d", advPos.region.x, advPos.region.y)
        if advPos['global'] then
            advPosInfo = string.format("%s\nglobal: X%d Y%d Z%d", advPosInfo, advPos.global.x, advPos.global.y, advPos.global.z)
        else
            advPosInfo = string.format("%s\nlocal: X%d Y%d Z%d", advPosInfo, advPos.loc.x, advPos.loc.y, advPos.loc.z)
        end
        self.subviews.advPanel.subviews.advPosLabel:setText(advPosInfo)
    end)
end
function HFfindWindow:on_submit_choice(_, choice) -- aban swlterdhame
    self.currentChoice = choice
    self.choiceTranslatedName = dfhack.TranslateName(choice[4].name, true)
    self.choiceNotTranslatedName = dfhack.TranslateName(choice[4].name, false)

    self.choiceRaceName = ""
    if choice[4].race ~= -1 then
        self.choiceRaceName = dfhack.capitalizeStringWords(df.creature_raw.find(choice[4].race).name[0])
    end
    self.choiceProfessionName = ""

    if choice[4].profession ~= -1 then
        self.choiceProfessionName = df.profession[choice[4].profession]
    end

    if self.firstSelection then
        self.firstSelection = false

        repeatUtil.scheduleEvery('findHF2', 10, 'frames', function()
            local histFigInfo = getPosFromHistFig(self.currentChoice[4])
            local HFinfo1, HFinfo2, HFinfo3, HFinfo4, HFinfo5, HFinfo6, HFinfo7  = ""


            HFinfo1 = self.choiceTranslatedName
            HFinfo2 = self.choiceNotTranslatedName
            HFinfo3 = self.choiceRaceName

            if histFigInfo then
                if histFigInfo["type"] == "otherworld" then
                    HFinfo5 = {{text='Not in this realm', pen=COLOR_MAGENTA}}
                elseif histFigInfo["type"] == "site" then
                    HFinfo5 =  dfhack.TranslateName(histFigInfo["siteName"], true)
                    HFinfo6 = string.format("region: X%d Y%d", histFigInfo["pos"].x, histFigInfo["pos"].y)
                    if histFigInfo["globPos"] then
                        HFinfo7 = string.format("global: X%d Y%d", histFigInfo["globPos"].x, histFigInfo["globPos"].y)
                    end
                elseif histFigInfo["type"] == "army" then
                    HFinfo5 = "Traveling the world"
                    HFinfo6 = string.format("global: X%d Y%d Z%d", histFigInfo["pos"].x, histFigInfo["pos"].y, histFigInfo["pos"].z)
                elseif histFigInfo["type"] == "local" then
                    HFinfo5 =  "Same site as you"
                    HFinfo6 = string.format("local: X%d Y%d Z%d", histFigInfo["pos"].x, histFigInfo["pos"].y, histFigInfo["pos"].z)
                end


            else
                HFinfo5 = {{text='Not in this realm', pen=COLOR_MAGENTA}}
            end

            if self.currentChoice[4].died_year == -1 then
                HFinfo4 = {{text='ALIVE', pen=COLOR_LIGHTGREEN}}
            else
                HFinfo4 = {{text='DEAD', pen=COLOR_RED}}
            end

            self.subviews.HFPanel.subviews.HFPosLabel1:setText(HFinfo1)
            self.subviews.HFPanel.subviews.HFPosLabel2:setText(HFinfo2)
            self.subviews.HFPanel.subviews.HFPosLabel3:setText(HFinfo3)
            self.subviews.HFPanel.subviews.HFPosLabel4:setText(HFinfo4)
            self.subviews.HFPanel.subviews.HFPosLabel5:setText(HFinfo5)
            self.subviews.HFPanel.subviews.HFPosLabel6:setText(HFinfo6)
            self.subviews.HFPanel.subviews.HFPosLabel7:setText(HFinfo7)
        end)
    end
end

function HFfindWindow:on_edit_change(txt)
    self.subviews.selection:setChoices()
    nonLocalHF = getHFnemesisFromName(txt)
    self.subviews.label2:setText(" ")

    if #nonLocalHF == 0 then
        self.subviews.label2:setText("No found")
    else
        self.subviews.selection:setChoices(nonLocalHF)
    end
end

function HFfindWindow:toggleHighlight()
    local panel = self.subviews.highlight
    panel.frame_background = not panel.frame_background and HIGHLIGHT_PEN or nil
end

HFfindScreen = defclass(HFfindScreen, gui.ZScreen)
HFfindScreen.ATTRS{
    focus_path='HFfindScreen',
    pass_movement_keys=true,
}

function HFfindScreen:init()
    self:addviews{HFfindWindow{}}
end

function HFfindScreen:onDismiss()
    view = nil
end

if not dfhack.world.isAdventureMode() then
    qerror('Only works in adventure mode')
end

view = view and view:raise() or HFfindScreen{}:show()
