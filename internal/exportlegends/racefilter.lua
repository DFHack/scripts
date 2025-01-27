--@module = true

local dlg = require('gui.dialogs')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local choices, race_to_label, hfid_to_race, hfid_to_name, cur_race, prev_search

function reset_state()
    choices = {}
    race_to_label = {[-1]='All'}
    hfid_to_race = {}
    hfid_to_name = {}
    cur_race = -1
    prev_search = ''
end
reset_state()

-- -------------------
-- RaceFilterOverlay
--

RaceFilterOverlay = defclass(RaceFilterOverlay, overlay.OverlayWidget)
RaceFilterOverlay.ATTRS {
    desc="Adds the ability to filter historical figures by race in legends mode.",
    default_pos={x=56, y=11},
    default_enabled=true,
    viewscreens='legends',  -- finer grained visibility managed in render and onInput functions
    frame={w=54, h=1},      --   can't use visible property due to self.dirty state management
}

function RaceFilterOverlay:init()
    self:addviews{
        widgets.BannerPanel{
            subviews={
                widgets.HotkeyLabel{
                    frame={l=1},
                    label='Filter by race:',
                    key='CUSTOM_ALT_S',
                    auto_width=true,
                    on_activate=self:callback('choose_race'),
                },
                widgets.Label{
                    frame={l=24},
                    text={{text=function() return race_to_label[cur_race] end}},
                    text_pen=COLOR_YELLOW,
                },
            },
        },
    }
end

function RaceFilterOverlay:set_race(_, choice)
    if cur_race == choice.race then return end
    cur_race = choice.race
    self.dirty = true
end

function RaceFilterOverlay:choose_race()
    if #choices == 0 then
        for race,cre in ipairs(df.global.world.raws.creatures.all) do
            local label = string.lower(cre.creature_id)
            race_to_label[race] = label
            table.insert(choices, {text=label, race=race})
        end
        table.sort(choices, function(a, b) return a.text < b.text end)
        table.insert(choices, 1, {text='All', race=-1})
    end

    dlg.showListPrompt('Races', 'Choose race filter', COLOR_WHITE, choices,
        self:callback('set_race'), nil, 30, true)
end

local function do_filter(scr, filter_str, full_refresh)
    print('filtering', cur_race, filter_str, full_refresh)
    if full_refresh then
        scr.histfigs_filtered:resize(#scr.histfigs)
        for i=0,#scr.histfigs-1 do
            scr.histfigs_filtered[i] = i
        end
    end
    local filter_by_name = full_refresh and #filter_str > 0
    filter_str = dfhack.toSearchNormalized(filter_str)
    if cur_race < 0 and not filter_by_name then return end
    for idx=#scr.histfigs_filtered-1,0,-1 do
        local hfid = scr.histfigs[scr.histfigs_filtered[idx]]
        if not hfid_to_race[hfid] then
            local hf = df.historical_figure.find(hfid)
            hfid_to_race[hfid] = hf and hf.race or -1
            hfid_to_name[hfid] = hf and
                dfhack.toSearchNormalized(
                    ('%s %s'):format(dfhack.translation.translateName(hf.name, false), dfhack.translation.translateName(hf.name, true))) or ''
        end
        if cur_race >= 0 and hfid_to_race[hfid] ~= cur_race then
            scr.histfigs_filtered:erase(idx)
        elseif filter_by_name and not  hfid_to_name[hfid]:match(filter_str) then
            scr.histfigs_filtered:erase(idx)
        end
    end
end

local function get_cur_page(scr)
    scr = scr or dfhack.gui.getDFViewscreen(true)
    return scr.page[scr.active_page_index]
end

local function is_hf_page(scr, page)
    page = page or get_cur_page(scr)
    return page.mode == df.legend_pagest.T_mode.HFS and page.index == -1
end

function RaceFilterOverlay:render(dc)
    local scr = dfhack.gui.getDFViewscreen(true)
    local page = get_cur_page(scr)
    if not is_hf_page(scr, page) then
        self.dirty = true
        return
    end
    if self.dirty or prev_search ~= page.filter_str then
        do_filter(scr, page.filter_str, self.dirty)
        prev_search = page.filter_str
        self.dirty = false
    end
    RaceFilterOverlay.super.render(self, dc)
end

function RaceFilterOverlay:onInput(keys)
    if not is_hf_page() then return end
    RaceFilterOverlay.super.onInput(self, keys)
end
