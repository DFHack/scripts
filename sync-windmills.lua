local argparse = require('argparse')

local function process_windmills(rotate_fn, timer_fn)
    for _, bld in ipairs(df.global.world.buildings.other.WINDMILL) do
        if bld.is_working ~= 0 then
            bld.rotation = rotate_fn()
            bld.rotate_timer = timer_fn()
        end
    end
end

local opts = {}
argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() opts.help = true end },
    { 'q', 'quiet', handler = function() opts.quiet = true end },
    { 'r', 'randomize', handler = function() opts.randomize = true end },
    { 't', 'timing-only', handler = function() opts.timing = true end },
})

if opts.help then
    print(dfhack.script_help())
    return
end

process_windmills(
    (opts.randomize or opts.timing) and
        function() return math.random(0, 1) end or
        function() return 0 end,
    opts.randomize and not opts.timing and
        function() return math.random(0, 74) end or
        function() return 0 end)

if not opts.quiet then
    print(('%d windmills %s'):format(
        #df.global.world.buildings.other.WINDMILL,
        opts.randomize and 'randomized' or 'synchronized'))
end
