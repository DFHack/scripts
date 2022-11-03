-- Revives the specified historical figure

--[====[

devel/revive-hf
=============

Revivs the specified historical figure, even if off-site.

Usage::

    devel/revive-hf HISTFIG_ID

Arguments:

``histfig_id``:
    the ID of the historical figure to target

]====]

local target_hf = -1

for _, arg in ipairs({...}) do
    if tonumber(arg) and target_hf == -1 then
        target_hf = tonumber(arg)
    else
        qerror('unrecognized argument: ' .. arg)
    end
end

local hf = df.historical_figure.find(target_hf)
    or qerror('histfig not found: ' .. target_hf)
local hf_name = dfhack.df2console(dfhack.TranslateName(hf.name))
local hf_desc = ('%i: %s (%s)'):format(target_hf, hf_name, dfhack.units.getRaceNameById(hf.race))

hf.old_year = df.global.cur_year
hf.old_seconds = df.global.cur_year_tick + 1
hf.died_year = -1
hf.died_seconds = -1
print('Revived histfig ' .. hf_desc)
