--Edit certain worldgen parameters while it is running.
--[====[

worldgenedit
============
Perhaps of dubious utility in general, being able to alter an active worldgen is handy.
Currently just has the end year, site count, and maximum population caps shown.
Still a work in progress as I intend to add a display of non-histfig civilized units once I figure out how.

]====]
local gui = require 'gui'
local widgets = require 'gui.widgets'
local wv = dfhack.gui.getCurViewscreen()
local wd = df.global.world.world_data
local wg = df.global.world.worldgen.worldgen_parms
local sites = df.global.world.world_data.sites
local ents = df.global.world.entities.all
local pent, dent, dnm, eent, enm, wnm, hent, hnm, gent, gnm, stn, stc, pop, eny

genedit=defclass(genedit,gui.Screen)
genedit.focus_path = 'worldgenedit'
function genedit:init()
    if not df.viewscreen_new_regionst:is_instance(wv) then
        self:dismiss()
        qerror("Should be used during worldgen.")
    else
        wv.worldgen_paused = 1
    end
    self:addviews{
      widgets.Label{
        view_id="main",
        frame = {t=18,l=0}, 
        text={
            {text="Quit: Enter/Esc        "},{id="prec", text="Site Num: "}, {id="curs", text=self:callback("getSites")},NEWLINE,
            {text="Edit: Left/Right(Fast) "},{id="pres", text="Site Cap: "}, {id="caps", text=self:callback("getCaps")},NEWLINE,
            {text="Edit: Up/Down(Fast/Z)  "},{id="ends", text="End Year: "}, {id="endy", text=self:callback("getEny")},NEWLINE,
            {text="Edit: PgUp/Dn(Fast)    "},{id="pops", text="Pop Cap: "}, {id="popc", text=self:callback("getPops")},NEWLINE,
            {text="Dwarves:       "},{id="drf", text=self:callback("getDwf")},NEWLINE,
            {text="Humans:        "},{id="hmn", text=self:callback("getHum")},NEWLINE,
            {text="Elves:         "},{id="elf", text=self:callback("getElf")},NEWLINE,
            {text="Goblins:       "},{id="grb", text=self:callback("getGob")},NEWLINE,
            {text="Total:         "},{id="pll", text=self:callback("getAll")},
            }
        }
    }
end

function genedit:getSites()
    stn = wd.next_site_id-1
    return stn
end

function genedit:getCaps()
    stc = wg.site_cap
    return stc
end

function genedit:getPops()
    pop = wg.total_civ_population
    return pop
end

function genedit:getEny()
    eny = wg.end_year
    return eny
end

function genedit:getDwf()
    dent = 0
    for k = 0, #sites-1, 1 do
        local inh = sites[k].inhabitants
        for v = 0, #inh-1, 1 do
            if df.creature_raw.find(inh[v].race).creature_id=='DWARF' then
                dent = dent + inh[v].count
            end
        end
    end 
    return dent
end

function genedit:getHum()
    hent = 0
    for k = 0, #sites-1, 1 do
        local inh = sites[k].inhabitants
        for v = 0, #inh-1, 1 do
            if df.creature_raw.find(inh[v].race).creature_id=='HUMAN' then
                hent = hent + inh[v].count
            end
        end
    end 
    return hent
end

function genedit:getElf()
    eent = 0
    for k = 0, #sites-1, 1 do
        local inh = sites[k].inhabitants
        for v = 0, #inh-1, 1 do
            if df.creature_raw.find(inh[v].race).creature_id=='ELF' then
                eent = eent + inh[v].count
            end
        end
    end 
    return eent
end

function genedit:getGob()
    gent = 0
    for k = 0, #sites-1, 1 do
        local inh = sites[k].inhabitants
        for v = 0, #inh-1, 1 do
            if df.creature_raw.find(inh[v].race).creature_id=='GOBLIN' then
                gent = gent + inh[v].count
            end
        end
    end 
    return gent
end

function genedit:getAll()
    pent = dent+eent+hent+gent
    return pent
end

function genedit:onInput(keys)
    if df.viewscreen_new_regionst:is_instance(wv) then
        if keys.LEAVESCREEN or keys.SELECT then
                   self:dismiss()
                   wv.worldgen_paused = 0
        end
        if keys.CURSOR_LEFT then 
            wg.site_cap = wg.site_cap-25
        elseif keys.CURSOR_RIGHT then
            wg.site_cap = wg.site_cap+25
        elseif keys.CURSOR_LEFT_FAST then
            wg.site_cap = wg.site_cap-100
        elseif keys.CURSOR_RIGHT_FAST then
            wg.site_cap = wg.site_cap+100
        elseif keys.CURSOR_DOWN then
            wg.end_year = wg.end_year-1
        elseif keys.CURSOR_UP then
            wg.end_year = wg.end_year+1
        elseif keys.CURSOR_DOWN_FAST then
            wg.end_year = wg.end_year-25
        elseif keys.CURSOR_UP_FAST then
            wg.end_year = wg.end_year+25
        elseif keys.CURSOR_DOWN_Z then
            wg.end_year = wg.end_year-1000
        elseif keys.CURSOR_UP_Z then
            wg.end_year = wg.end_year+1000
        elseif keys.STANDARDSCROLL_PAGEDOWN then
            wg.total_civ_population = wg.total_civ_population-250
        elseif keys.STANDARDSCROLL_PAGEUP then
            wg.total_civ_population = wg.total_civ_population+250
        elseif keys.SECONDSCROLL_PAGEDOWN then
            wg.total_civ_population = wg.total_civ_population-1000
        elseif keys.SECONDSCROLL_PAGEUP then
            wg.total_civ_population = wg.total_civ_population+1000
        end
    end
    self.super.onInput(self,keys)
end

function genedit:onRenderBody(dc)
    self._native.parent:render()
end

genedit():show()
