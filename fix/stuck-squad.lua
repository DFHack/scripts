--@ module=true

local utils = require('utils')

-- from observing bugged saves, this condition appears to be unique to stuck armies
local function is_army_stuck(army)
    return army.controller_id ~= 0 and not army.controller
end

-- if army is currently camping, we'll need to go up the chain
local function get_top_controller(controller)
    if not controller then return end
    if controller.master_id == controller.id then return controller end
    return df.army_controller.find(controller.master_id)
end

local function is_army_valid_and_returning(army)
    local controller = get_top_controller(army.controller)
    if not controller then return false, false end
    if controller.goal == df.army_controller_goal_type.SITE_INVASION then
        return true, controller.data.goal_site_invasion.flag.RETURNING_HOME
    elseif controller.goal == df.army_controller_goal_type.MAKE_REQUEST then
        return true, controller.data.goal_make_request.flag.RETURNING_HOME
    end
    return false, false
end

local function get_hf_army(hf)
    if not hf then return end
    return df.army.find(hf.info and hf.info.whereabouts and hf.info.whereabouts.army_id or -1)
end

-- need to check all squad positions since some members may have died
local function get_squad_army(squad)
    if not squad then return end
    for _,sp in ipairs(squad.positions) do
        local hf = df.historical_figure.find(sp.occupant)
        if not hf then goto continue end
        local army = get_hf_army(hf)
        if army then return army end
        ::continue::
    end
end

-- called by gui/notify notification
function scan_fort_armies()
    local stuck_armies, outbound_army, returning_army = {}, nil, nil
    local govt = df.historical_entity.find(df.global.plotinfo.group_id)
    if not govt then return stuck_armies, outbound_army, returning_army end

    for _,squad_id in ipairs(govt.squads) do
        local squad = df.squad.find(squad_id)
        local army = get_squad_army(squad)
        if not army then goto continue end
        if is_army_stuck(army) then
            table.insert(stuck_armies, {squad=squad, army=army})
        elseif not returning_army then
            local valid, returning = is_army_valid_and_returning(army)
            if valid then
                if returning then
                    returning_army = {squad=squad, army=army}
                else
                    outbound_army = {squad=squad, army=army}
                end
            end
        end
        ::continue::
    end

    if #stuck_armies == 0 then return stuck_armies, nil, nil end

    -- prefer returning with a messenger if one is readily available
    for _,messenger in ipairs(dfhack.units.getUnitsByNobleRole('Messenger')) do
        local army = get_hf_army(df.historical_figure.find(messenger.hist_figure_id))
        if not army then goto continue end
        local valid, returning = is_army_valid_and_returning(army)
        if valid then
            if returning then
                returning_army = {army=army}
            else
                outbound_army = {army=army}
            end
        end
        ::continue::
    end

    return stuck_armies, outbound_army, returning_army
end

local function unstick_armies()
    local stuck_armies, outbound_army, returning_army = scan_fort_armies()
    if #stuck_armies == 0 then return end
    if not returning_army then
        local instructions = outbound_army
            and ('Please wait for %s to complete their objective and run this command again when they are on their way home.'):format(
                outbound_army.squad and dfhack.df2console(dfhack.military.getSquadName(outbound_army.squad.id)) or 'the messenger')
            or 'Please send a squad or a messenger out on a mission that will return to the fort, and'..
            ' run this command again when they are on the way home.'
        qerror(('%d stuck squad%s found, but no returning squads or messengers are available to rescue them!\n%s'):format(
            #stuck_armies, #stuck_armies == 1 and '' or 's', instructions))
        return
    end
    local returning_squad_name = returning_army.squad and dfhack.df2console(dfhack.military.getSquadName(returning_army.squad.id)) or 'the messenger'
    for _,stuck in ipairs(stuck_armies) do
        print(('fix/stuck-squad: Squad rescue operation underway! %s is rescuing %s'):format(
            returning_squad_name, dfhack.military.getSquadName(stuck.squad.id)))
        for _,member in ipairs(stuck.army.members) do
            local nemesis = df.nemesis_record.find(member.nemesis_id)
            if not nemesis or not nemesis.figure then goto continue end
            local hf = nemesis.figure
            if hf.info and hf.info.whereabouts then
                hf.info.whereabouts.army_id = returning_army.army.id
            end
            utils.insert_sorted(returning_army.army.members, member, 'nemesis_id')
            ::continue::
        end
        stuck.army.members:resize(0)
        utils.insert_sorted(get_top_controller(returning_army.army.controller).assigned_squads, stuck.squad.id)
    end
end

if dfhack_flags.module then
    return
end

unstick_armies()
