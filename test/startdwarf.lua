config.target = 'startdwarf'

local function run_startdwarf(...)
    return dfhack.run_script('startdwarf', ...)
end

function test.no_arg()
    expect.error_match('expected positive integer', run_startdwarf)
end

function test.not_number()
    expect.error_match('expected positive integer', curry(run_startdwarf, 'a'))
end

function test.too_small()
    expect.error_match('expected positive integer', curry(run_startdwarf, '0'))
    expect.error_match('expected positive integer', curry(run_startdwarf, '-1'))
end

function test.too_big()
    expect.error_match('value must be no more than', curry(run_startdwarf, '32768'))
end
