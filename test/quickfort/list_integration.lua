local quickfort_list = reqscript('internal/quickfort/list')

local input_dir = 'library/test/quickfort/list/'

function test.parse_library_no_errors()
    local mock_print = mock.func()
    mock.patch(quickfort_list, 'print', mock_print,
        function()
            dfhack.run_script('quickfort', 'list', '--library', '--hidden')
        end)
    expect.lt(1, mock_print.call_count, 'ensure library is detected')
    for i = 1,mock_print.call_count do
        local actual = mock_print.call_args[1][1]
        -- ensure there is no unexpected output (like warning messages)
        expect.true_(mock_print.call_args[1][1]:find('^%d+%) '))
    end
end

local function test_modes(fname, modes_and_labels)
    local mock_print = mock.func()
    mock.patch(quickfort_list, 'print', mock_print,
        function()
            dfhack.run_script('quickfort', 'list', fname, '-hl')
        end)
    -- ensure we only see lines for the modes we expect (the +1 is for the
    -- trailing "<num> blueprints did not match filter" line)
    local num_modes = 0
    for _,_ in pairs(modes_and_labels) do num_modes = num_modes + 1 end
    expect.eq(num_modes+1, mock_print.call_count, 'no unexpected lines')
    -- trim off the trailing status line
    table.remove(mock_print.call_args)
    for _,args in ipairs(mock_print.call_args) do
        local line = args[1]
        local _,_,mode = line:find('%(([%a]+)')
        local label, label_str = modes_and_labels[mode], ''
        if not label then
            expect.fail('duplicate or bad mode found: ' .. tostring(line))
            break
        end
        if #label > 0 then label_str = ('-n %s '):format(label) end
        local expected = ('%s %s(%s)'):format(fname, label_str, mode)
        -- ignore the variable list ordinal prefix (e.g. '204) ')
        expect.eq(expected, line:sub(line:find(' ')+1))
        -- remove the mode from the map so we can detect duplicates
        modes_and_labels[mode] = nil
    end
end

function test.all_modes()
    local fname = input_dir .. 'all_modes.csv'
    local modes_and_labels = {
        dig='',
        build='/2',
        place='/3',
        zone='/4',
        query='/5',
        config='/6',
        meta='/7',
        notes='/8',
    }
    test_modes(fname, modes_and_labels)
end

function test.all_modes_separate_sheets()
    local fname = input_dir .. 'all_modes_separate_sheets.xlsx'
    local modes_and_labels = {
        dig='dig_sheet',
        build='build_sheet',
        place='place_sheet',
        zone='zone_sheet',
        query='query_sheet',
        config='config_sheet',
        meta='meta_sheet',
        notes='notes_sheet',
    }
    test_modes(fname, modes_and_labels)
end

function test.all_modes_single_sheet()
    local fname = input_dir .. 'all_modes_single_sheet.xlsx'
    local modes_and_labels = {
        dig='Sheet1',
        build='Sheet1/2',
        place='Sheet1/3',
        zone='Sheet1/4',
        query='Sheet1/5',
        config='Sheet1/6',
        meta='Sheet1/7',
        notes='Sheet1/8',
    }
    test_modes(fname, modes_and_labels)
end
