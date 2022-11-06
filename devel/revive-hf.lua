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

hf.died_year = -1
hf.died_seconds = -1
print('Revived histfig ' .. hf_desc)
