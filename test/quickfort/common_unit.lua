local quickfort_common = reqscript('internal/quickfort/common')

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/common') end)
end

function test.log()
    local mock_print = mock.func()
    mock.patch(
        {
            {quickfort_common, 'verbose', false},
            {quickfort_common, 'print', mock_print},
        },
        function()
            quickfort_common.log('should not log')
            expect.eq(0, mock_print.call_count)
            quickfort_common.verbose = true
            quickfort_common.log('should log')
            expect.eq(1, mock_print.call_count)
            quickfort_common.verbose = false
            quickfort_common.log('should not log')
            expect.eq(1, mock_print.call_count)
        end)
end

function test.logfn()
    local mock_print = mock.func()
    mock.patch(
        {
            {quickfort_common, 'verbose', false},
            {quickfort_common, 'print', mock_print},
        },
        function()
            quickfort_common.logfn(mock_print, 'should not log')
            expect.eq(0, mock_print.call_count)
            quickfort_common.verbose = true
            quickfort_common.logfn(mock_print, 'should log')
            expect.eq(1, mock_print.call_count)
            quickfort_common.verbose = false
            quickfort_common.logfn(mock_print, 'should not log')
            expect.eq(1, mock_print.call_count)
        end)
end
