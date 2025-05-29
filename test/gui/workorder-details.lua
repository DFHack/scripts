-- test -dhack/scripts/devel/tests -tworkorder%-details

config.mode = 'fortress'

local gui = require('gui')
local function send_keys(...)
    local keys = {...}
    for _,key in ipairs(keys) do
        gui.simulateInput(dfhack.gui.getCurViewscreen(true), key)
    end
end

local xtest = {} -- use to temporarily disable tests (change `function test.somename` to `function xtest.somename`)
local wait = function(n)
    --delay(n or 30) -- enable for debugging the tests
end

-- handle confirm: we may need to additionally confirm order removal
--[[
local confirm = require 'plugins.confirm'
local confirmRemove = function() end
if confirm.isEnabled() then
    for _, c in pairs(confirm.get_conf_data()) do
        if c.id == 'order-remove' then
            if c.enabled then
                confirmRemove = function()
                    wait()
                    -- only pause and resend key if we're not already paused
                    if not confirm.get_paused() then
                        send_keys('CUSTOM_P', 'MANAGER_REMOVE')
                    end
                end
            end
            break
        end
    end
end
]]

function test.changeOrderDetails()
    --[[ this is not needed because of how gui.simulateInput'D_JOBLIST' works
    -- verify expected starting state
    expect.eq(df.ui_sidebar_mode.Default, df.global.plotinfo.main.mode)
    expect.true_(df.viewscreen_dwarfmodest:is_instance(scr))
    --]]

    -- get into the orders screen
    send_keys('D_JOBLIST', 'UNITJOB_MANAGER')
    expect.true_(df.viewscreen_jobmanagementst:is_instance(dfhack.gui.getCurViewscreen(true)), "We need to be in the jobmanagement/Main screen")

    local ordercount = #df.global.world.manager_orders.all

    --- create an order
    dfhack.run_command [[workorder "{ \"frequency\" : \"OneTime\", \"job\" : \"CutGems\", \"material\" : \"INORGANIC:SLADE\" }"]]
    wait()
    send_keys('STANDARDSCROLL_UP') -- move cursor to newly created CUT SLADE
    wait()
    send_keys('MANAGER_DETAILS')
    expect.true_(df.viewscreen_workquota_detailsst:is_instance(dfhack.gui.getCurViewscreen(true)), "We need to be in the workquota_details screen")
    expect.eq(ordercount + 1, #df.global.world.manager_orders.all, "Test order should have been added")
    local job = dfhack.gui.getCurViewscreen(true).order
    local item = job.items[0]

    dfhack.run_command 'gui/workorder-details'
    --[[
    input item: boulder
    material:   slade
    traits:     none
    ]]
    expect.ne(-1, item.item_type, "Input should not be 'any item'")
    expect.ne(-1, item.mat_type, "Material should not be 'any material'")
    expect.false_(item.flags2.allow_artifact, "Trait allow_artifact should not be set")

    wait()
    send_keys('CUSTOM_I', 'SELECT') -- change input to 'any item'
    wait()
    send_keys('CUSTOM_M', 'SELECT') -- change material to 'any material'
    wait()
    send_keys('CUSTOM_T', 'STANDARDSCROLL_DOWN', 'STANDARDSCROLL_DOWN', 'SELECT', 'LEAVESCREEN') -- change traits to 'allow_artifact'
    --[[
    input item: any item
    material:   any material
    traits:     allow_artifact
    ]]
    expect.eq(-1, item.item_type, "Input item should change to 'any item'")
    expect.eq(-1, item.mat_type, "Material should change to 'any material'")
    expect.true_(item.flags2.allow_artifact, "Trait allow_artifact should change to set")

    -- cleanup
    wait()
    send_keys('LEAVESCREEN', 'LEAVESCREEN', 'MANAGER_REMOVE')
    confirmRemove()
    expect.eq(ordercount, #df.global.world.manager_orders.all, "Test order should've been removed")
    -- go back to map screen
    wait()
    send_keys('LEAVESCREEN', 'LEAVESCREEN')
end

-- where flags is a table of key-boolean
local function any_flag(flags)
    for f, v in pairs(flags) do
        if v then return f end
    end
    return false
end

function test.unsetAllItemTraits()
    -- get into the orders screen
    send_keys('D_JOBLIST', 'UNITJOB_MANAGER')
    expect.true_(df.viewscreen_jobmanagementst:is_instance(dfhack.gui.getCurViewscreen(true)), "We need to be in the jobmanagement/Main screen")

    local ordercount = #df.global.world.manager_orders.all

    --- create an order
    dfhack.run_command [[workorder "{ \"frequency\" : \"OneTime\", \"job\" : \"CutGems\", \"material\" : \"INORGANIC:SLADE\" }"]]
    expect.eq(ordercount + 1, #df.global.world.manager_orders.all, "Test order should have been added")
    wait()
    send_keys('STANDARDSCROLL_UP') -- move cursor to newly created CUT SLADE
    wait()
    send_keys('MANAGER_DETAILS')
    expect.true_(df.viewscreen_workquota_detailsst:is_instance(dfhack.gui.getCurViewscreen(true)), "We need to be in the workquota_details screen")
    local job = dfhack.gui.getCurViewscreen(true).order
    local item = job.items[0]

    dfhack.run_command 'gui/workorder-details'

    -- manually set some traits
    item.flags1.improvable = true
    item.flags2.allow_artifact = true
    item.flags3.unimproved = true
    item.has_tool_use = 0 -- LIQUID_COOKING
    item.has_material_reaction_product = 'BAG_ITEM'
    item.metal_ore = 0 -- iron
    item.reaction_class = 'CALCIUM_CARBONATE'

    wait()
    send_keys('CUSTOM_T')
    wait()
    send_keys('SELECT') -- cursor is at 'no traits'
    wait()
    send_keys('LEAVESCREEN')

    expect.false_(any_flag(item.flags1), "A flag in item.flags1 is set")
    expect.false_(any_flag(item.flags2), "A flag in item.flags2 is set")
    expect.false_(any_flag(item.flags3), "A flag in item.flags3 is set")
    expect.eq(-1, item.has_tool_use, "Tool use is not reset")
    expect.eq('', item.has_material_reaction_product, "Material reaction product is not reset")
    expect.eq(-1, item.metal_ore, "Metal ore is not reset")
    expect.eq('', item.reaction_class, "Reaction class is not reset")

    -- cleanup
    wait()
    send_keys('LEAVESCREEN', 'LEAVESCREEN', 'MANAGER_REMOVE')
    confirmRemove()
    expect.eq(ordercount, #df.global.world.manager_orders.all, "Test order should've been removed")
    -- go back to map screen
    wait()
    send_keys('LEAVESCREEN', 'LEAVESCREEN')
end
