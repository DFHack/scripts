-- use the quickfort script as a guinnea pig so we can easily intercept
-- its output and detect how many times it was run
local quickfort = reqscript('quickfort')

local mock_print

local function test_wrapper(test_fn)
    mock_print = mock.func()
    mock.patch(quickfort, 'print', mock_print, test_fn)
end
config.wrapper = test_wrapper

function test.empty()
    dfhack.run_script('multicmd')
    expect.eq(0, mock_print.call_count)
end

function test.single()
    dfhack.run_script('multicmd', 'quickfort')
    expect.eq(1, mock_print.call_count)
end

function test.double_no_spaces()
    dfhack.run_script('multicmd', 'quickfort;quickfort')
    expect.eq(2, mock_print.call_count)
end

function test.double_space_after()
    dfhack.run_script('multicmd', 'quickfort; quickfort')
    expect.eq(2, mock_print.call_count)
end

function test.double_space_before_and_after()
    dfhack.run_script('multicmd', 'quickfort ; quickfort')
    expect.eq(2, mock_print.call_count)
end

function test.adjacent_semicolons()
    dfhack.run_script('multicmd', 'quickfort;;;quickfort')
    expect.eq(2, mock_print.call_count)
end

function test.long_chain()
    dfhack.run_script('multicmd',
                      'quickfort;quickfort;quickfort;quickfort')
    expect.eq(4, mock_print.call_count)
end
