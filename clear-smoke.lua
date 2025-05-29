--@module = true

function removeFlow(flow) --have DF remove the flow
    if not flow then
        return
    end
    flow.flags.DEAD = true

    local block = dfhack.maps.getTileBlock(flow.pos)
    if block then
        block.flow_pool.flags.active = true
    else
        df.global.world.orphaned_flow_pool.flags.active = true
    end
end

function removeFlows(flow_type) --remove all if flow_type is nil
    local count = 0
    for _,flow in ipairs(df.global.flows) do
        if not flow.flags.DEAD and (flow_type == nil or flow.type == flow_type) then
            removeFlow(flow)
            count = count + 1
        end
    end

    return count
end

function clearSmoke()
    if dfhack.isWorldLoaded() then
        print(('%d smoke flows removed.'):format(removeFlows(df.flow_type.Smoke)))
    else
        qerror('World not loaded!')
    end
end

if not dfhack_flags.module then
    clearSmoke()
end
