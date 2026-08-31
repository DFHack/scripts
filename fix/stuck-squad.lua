--Rescue stranded squads. (Also contains functions for messing with armies.)
--@ module=true

local argparse = require('argparse')
local plotinfo = df.global.plotinfo

function new_controller(site_id) --Create army controller aimed at site
    local controllers = df.global.world.army_controllers.all
    local cid = df.global.army_controller_next_id

    controllers:insert('#', {
        new = true,
        id = cid,
        site_id = site_id,
        pos_x = -1, --DF will assign to site center
        pos_y = -1,
        year = df.global.cur_year,
        year_tick = df.global.cur_year_tick,
        master_id = cid,
        origin_task_id = -1,
        origin_plot_id = -1,
        data = {goal_move_to_site = {new = true, flag = {RETURNING_TO_CURRENT_HOME = true}}},
        goal = df.army_controller_goal_type.MOVE_TO_SITE,
    })
    df.global.army_controller_next_id = cid+1
    return cid, controllers[#controllers-1]
end

function rescue_army(army, site, verbose) --Migrate stranded army to site
    site = site or df.world_site.find(plotinfo.site_id)
    if not army or not site then
        qerror('Invalid army or destination site')
    elseif verbose then
        print(('Rescuing army #%d to site #%d'):format(army.id, site.id))
    end

    if df.army_controller.find(army.controller_id) then --Controller still exists
        if verbose then
            print(('Army controller #%d still exists. Aborting.'):format(army.controller_id))
        end
        return false --Don't mess with anything; DF may re-create the army rather than reattach
    end

    army.controller_id, army.controller = new_controller(site.id)
    if verbose then
        print(('Attached new controller #%d to army.'):format(army.controller_id))
    end
    return true
end

local function get_hf_army(hfid) --Return army ID of HF or -1
    local hf = df.historical_figure.find(hfid)
    return hf and hf.info and hf.info.whereabouts and hf.info.whereabouts.army_id or -1
end

function get_fort_armies(govt) --Return a set of all squad armies; squads can share armies
    govt = govt or df.historical_entity.find(plotinfo.group_id)
    local armies = {}
    for _,sqid in ipairs(govt.squads) do --Iterate squads
        local squad = df.squad.find(sqid)
        if squad then
            for _,sp in ipairs(squad.positions) do --Iterate positions
                local army = df.army.find(get_hf_army(sp.occupant))
                --HF doesn't update while camping. If it's possible for the army to get
                --stuck in that state, we'd probably have to scan all armies to find it.
                if army then
                    armies[army] = true
                    break --Likely only one valid army per squad
                end
            end
        end
    end
    return armies
end

--From observing bugged saves, this condition appears to be unique to stuck armies
local function is_army_stuck(army)
    return army and not army.flags.dwarf_mode_preparing and --Let DF handle cancelled missions
        army.controller_id ~= 0 and not army.controller
end

function scan_fort_armies(govt) --Return a list of all squad armies that are stuck
    govt = govt or df.historical_entity.find(plotinfo.group_id)
    if not govt then
        qerror('No site entity. Is fort loaded?')
    end
    local stuck = {}
    for army in pairs(get_fort_armies(govt)) do --Check each army from the set
        if is_army_stuck(army) then
            table.insert(stuck, army)
        end
    end
    return stuck
end

function unstick_armies(verbose, quiet_result) --Recover all stuck squads for the current fort
    local site = df.world_site.find(plotinfo.site_id)
    local govt = df.historical_entity.find(plotinfo.group_id)
    if not site or not govt then
        qerror('No fort loaded')
    end
    local stuck = scan_fort_armies(govt)
    if not next(stuck) then --No problems
        if not quiet_result then
            print('No stuck squads.')
        end
        return 0
    elseif verbose then
        print(('Unsticking armies for player site #%d, entity #%d'):format(site.id, govt.id))
    end
    local count = 0
    for _,army in ipairs(stuck) do
        count = count + (rescue_army(army, site, verbose) and 1 or 0)
    end
    if verbose or not quiet_result then
        print(('Rescued %d of %d stuck armies.'):format(count, #stuck))
    end
    return count
end

if dfhack_flags.module then
    return
end

local quiet, verbose = false, false
argparse.processArgsGetopt({...}, {
    {'q', 'quiet', handler=function() quiet = true end},
    {'v', 'verbose', handler=function() verbose = true end},
})

unstick_armies(verbose, quiet)
