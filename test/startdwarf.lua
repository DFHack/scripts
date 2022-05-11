local utils = require('utils')

local function with_patches(callback, custom_mocks)
    dfhack.with_temp_object(df.new('uint32_t'), function(temp_out)
        local mocks = {
            getAddress = mock.func(utils.addressof(temp_out)),
            patchMemory = mock.func(),
        }
        if custom_mocks then
            for k, v in pairs(custom_mocks) do
                mocks[k] = v
            end
        end
        mock.patch({
            {dfhack.internal, 'getAddress', mocks.getAddress},
            {dfhack.internal, 'patchMemory', mocks.patchMemory},
        }, function()
            callback(mocks, temp_out)
        end)
    end)
end

local function run_startdwarf(...)
    return dfhack.run_script('startdwarf', ...)
end

local function test_early_error(args, expected_message, custom_mocks)
    with_patches(function(mocks, temp_out)
        temp_out.value = 12345

        expect.error_match(expected_message, function()
            run_startdwarf(table.unpack(args))
        end)

        expect.eq(mocks.getAddress.call_count, 1, 'getAddress was not called')
        expect.table_eq(mocks.getAddress.call_args[1], {'start_dwarf_count'})

        expect.eq(mocks.patchMemory.call_count, 0, 'patchMemory was called unexpectedly')

        -- make sure the script didn't attempt to write in some other way
        expect.eq(temp_out.value, 12345, 'memory was changed unexpectedly')
    end, custom_mocks)
end

local function test_invalid_args(args, expected_message)
    test_early_error(args, expected_message)
end

local function test_patch_successful(expected_value)
    with_patches(function(mocks, temp_out)
        run_startdwarf(tostring(expected_value))
        -- temp_out doesn't change on success because our stub patchMemory() is a no-op

        expect.eq(mocks.getAddress.call_count, 1, 'getAddress was not called')
        expect.table_eq(mocks.getAddress.call_args[1], {'start_dwarf_count'})

        expect.eq(mocks.patchMemory.call_count, 1, 'patchMemory was not called')
        expect.eq(mocks.patchMemory.call_args[1][1], utils.addressof(temp_out),
            'patchMemory called with wrong destination')
        -- skip checking source (arg 2) because it has already been freed
        expect.eq(mocks.patchMemory.call_args[1][3], df.sizeof(temp_out),
            'patchMemory called with wrong length')
    end)
end

function test.no_arg()
    test_invalid_args({}, 'must be a number')
end

function test.not_number()
    test_invalid_args({'a'}, 'must be a number')
end

function test.too_small()
    test_invalid_args({'4'}, 'too small')
    test_invalid_args({'6'}, 'too small')
    test_invalid_args({'-1'}, 'too small')
end

function test.missing_address()
    test_early_error({}, 'address not available', {getAddress = mock.func(nil)})
    test_early_error({'8'}, 'address not available', {getAddress = mock.func(nil)})
end

function test.exactly_7()
    test_patch_successful(7)
end

function test.above_7()
    test_patch_successful(10)
end

function test.uint8_overflow()
    test_patch_successful(257)
end
