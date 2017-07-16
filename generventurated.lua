--Use on the adventurer race selection screen to use generated creatures, and again on the entities screen to fill it out.
local vw = dfhack.gui.getCurViewscreen()
local current = df.global.world.raws.creatures.all
local gent = df.global.world.entities.all
local gcas
function generVent(gcas, vw)
if not df.viewscreen_setupadventurest:is_instance(vw) then
    qerror("Kinda needed to do this before you finished setting up an adventurer.")
elseif df.viewscreen_setupadventurest:is_instance(vw) then
    if vw.page==0 then 
        for m, n in ipairs(current) do
            if current[m].flags.GENERATED == true then
              if not current[m].flags.CASTE_FEATURE_BEAST then
                current[m].flags.CASTE_CAN_LEARN = true
                current[m].flags.CASTE_CAN_SPEAK = true
                s = df.new('string')
                s.value = '[LOCAL_POPS_PRODUCE_HEROES][OUTSIDER_CONTROLLABLE][LOCAL_POPS_CONTROLLABLE][CANOPENDOORS][CAN_LEARN][CAN_SPEAK]'
                current[m].raws:insert('#',s)
                for v = #vw.race_ids, m-#vw.race_ids, m do
                    vw.race_ids:resize(#vw.race_ids+1)
                    vw.race_ids[v] = m
                end
                gcas = current[m].caste
                for j, k in ipairs(gcas) do
                    gcas[j].flags.CAN_SPEAK = true
                    gcas[j].flags.CAN_LEARN = true
                    gcas[j].flags.CANOPENDOORS = true
                    gcas[j].flags.LOCAL_POPS_CONTROLLABLE = true
                    gcas[j].flags.OUTSIDER_CONTROLLABLE = true
                    gcas[j].flags.LOCAL_POPS_PRODUCE_HEROES = true
--                    if gcas[j].flags.FEATURE_BEAST == true then
--                        local s = "gcas[j].description"
--                        string.find (s, "%.")
--                        current[m].name = s
--                    end
                end
            end
        end
    end
    elseif vw.page==3 then
        for q, r in ipairs(gent) do
            if gent[q].type==0 then
                vw.home_entity_ids:resize(#vw.home_entity_ids+1)
                vw.home_entity_ids[#vw.home_entity_ids-1] = gent[q].id
                end
            end
        end
    end
end
generVent(gcas,vw)
