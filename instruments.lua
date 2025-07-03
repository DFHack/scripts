local argparse = require('argparse')
local workorder = reqscript('workorder')

-- civilization ID of the player civilization
local civ_id = df.global.plotinfo.civ_id
local raws = df.global.world.raws

---@type instrument itemdef_instrumentst
---@return reaction|nil
function getAssemblyReaction(instrument_id)
    for _, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and
            reaction.category == 'INSTRUMENT' and
            reaction.code:find(instrument_id, 1, true)
        then
            return reaction
        end
    end
    return nil
end

-- patch in thread type
---@type reagent reaction_reagent_itemst
---@return string
function reagentString(reagent)
    if reagent.code == 'thread' then
        local silk = reagent.flags2.silk and "silk " or ""
        local yarn = reagent.flags2.yarn and "yarn " or ""
        local plant = reagent.flags2.plant and "plant " or ""
        return silk .. yarn .. plant .. "thread"
    else
        return reagent.code
    end
end

---@type reaction reaction
---@return string
function describeReaction(reaction)
    local skill = df.job_skill[reaction.skill]
    local reagents = {}
    for _, reagent in ipairs(reaction.reagents) do
        table.insert(reagents, reagentString(reagent))
    end
    return skill .. ": " .. table.concat(reagents, ", ")
end

function collect_unique_instrument_names()
    local civ_id = df.global.plotinfo.civ_id
    local instruments = {}
    local seen = {}

    for _, instr in ipairs(df.global.world.raws.itemdefs.instruments) do
        if instr.source_enid == civ_id then
            local name = instr.name
            local normalized = dfhack.toSearchNormalized(name)
            if not seen[normalized] then
                seen[normalized] = true
                local type = instr.flags.PLACED_AS_BUILDING and "building" or "handheld"
                table.insert(instruments, { name = name, type = type })
            end
        end
    end

    return instruments
end

function place_instrument_work_orders(count, quiet, type_filter)
    local instruments = collect_unique_instrument_names()
    local counts = { building = 0, handheld = 0, total = 0 }

    for _, instrument in ipairs(instruments) do
        local name = instrument.name
        local type = instrument.type

        if type_filter and type ~= type_filter then goto continue end

        if not quiet then
            print("------------------------------")
            print("Placing order for: " .. name .. " (x" .. count .. ") [" .. type .. "]")
            print("------------------------------")
        end

        local success, err = pcall(function()
            order_instrument(name, count, quiet)
        end)

        if not success then
            dfhack.printerr("Failed to place order for '" .. name .. "': " .. tostring(err))
        else
            counts[type] = counts[type] + count
            counts.total = counts.total + count
        end

        ::continue::
    end

    if not quiet then
        print("\n==== Instrument Order Summary ====")
        print("Total instruments ordered: " .. counts.total)
        print("  Handheld: " .. counts.handheld)
        print("  Building: " .. counts.building)
        print("==================================\n")
    end
end

local function print_list()
    -- gather instrument piece reactions and index them by the instrument they are part of
    local instruments = {}
    for _, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and reaction.category == 'INSTRUMENT_PIECE' then
            local iname = reaction.name:match("[^ ]+ ([^ ]+)")
            table.insert(ensure_key(instruments, iname),
                reaction.name .. " (" .. describeReaction(reaction) .. ")")
        end
    end

    -- go over instruments
    for _, instrument in ipairs(raws.itemdefs.instruments) do
        if not (instrument.source_enid == civ_id) then goto continue end

        local building_tag = instrument.flags.PLACED_AS_BUILDING and " (building, " or " (handheld, "
        local reaction = getAssemblyReaction(instrument.id)
        dfhack.print(dfhack.df2console(instrument.name .. building_tag))
        if #instrument.pieces == 0 then
            print(dfhack.df2console(describeReaction(reaction) .. ")"))
        else
            print(dfhack.df2console(df.job_skill[reaction.skill] .. "/assemble)"))
            for _, str in pairs(instruments[instrument.name]) do
                print(dfhack.df2console("  " .. str))
            end
        end
        print()
        ::continue::
    end
end

function order_instrument(name, amount, quiet)
    local instrument = nil
    local civ_id = df.global.plotinfo.civ_id
    local normalized_input = dfhack.toSearchNormalized(name)

    for _, instr in ipairs(raws.itemdefs.instruments) do
        if instr.source_enid == civ_id and
            dfhack.toSearchNormalized(instr.name) == normalized_input then
            instrument = instr
            break
        end
    end

    if not instrument then
        qerror("Could not find instrument " .. name)
    end

    local orders = {}

    for i, reaction in ipairs(raws.reactions.reactions) do
        if reaction.source_enid == civ_id and reaction.category == 'INSTRUMENT_PIECE' and reaction.code:find(instrument.id, 1, true) then
            local part_order = {
                id=i,
                amount_total=amount,
                reaction=reaction.code,
                job="CustomReaction",
            }
            table.insert(orders, part_order)
        end
    end

    if #orders < #instrument.pieces then
        print("Warning: Could not find reactions for all instrument pieces")
    end

    local assembly_reaction = getAssemblyReaction(instrument.id)
    if not assembly_reaction then
        qerror("No assembly reaction found for instrument '" .. name .. "'")
    end

    local assembly_order = {
        id=-1,
        amount_total=amount,
        reaction=assembly_reaction.code,
        job="CustomReaction",
        order_conditions={}
    }

    for _, order in ipairs(orders) do
        table.insert(
            assembly_order.order_conditions,
            {
                condition="Completed",
                order=order.id
            }
        )
    end

    table.insert(orders, assembly_order)

    orders = workorder.preprocess_orders(orders)
    workorder.fillin_defaults(orders)
    workorder.create_orders(orders, quiet)

    if not quiet then
        print("\nCreated " .. #orders .. " work orders")
    end
end

local help = false
local quiet = false
local positionals = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() help = true end},
    {'q', 'quiet', handler=function() quiet = true end},
})

if help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

if #positionals == 0 or positionals[1] == "list" then
    print_list()
elseif positionals[1] == "order" then
    local target = positionals[2]
    if not target then
        qerror("Usage: instruments order <instrument_name|all> [<amount>] [handheld|building]")
    end

    local amount = 1
    local type_filter = nil

    for i = 3, #positionals do
        local arg = positionals[i]:lower()
        if tonumber(arg) then
            amount = tonumber(arg)
        elseif arg == "handheld" or arg == "building" then
            type_filter = arg
        else
            qerror("Invalid argument: " .. positionals[i])
        end
    end

    if amount < 1 then
        qerror("Amount must be a positive number")
    end

    if target == "all" then
        place_instrument_work_orders(amount, quiet, type_filter)
    else
        order_instrument(target, amount, quiet)
    end
end
