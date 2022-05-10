local r = reqscript('internal/quickfort/reader').unit_test_hooks

function test.module()
    expect.error_match(
        'this script cannot be called directly',
        function() dfhack.run_script('internal/quickfort/reader') end)
end

function test.chomp()
    expect.nil_(r.chomp(nil))

    expect.eq('', r.chomp(''))
    expect.eq('a', r.chomp('a'))
    expect.eq('', r.chomp('\r'))
    expect.eq('', r.chomp('\n\r'))
    expect.eq('', r.chomp('\r\n'))
    expect.eq('', r.chomp('\n'))
    expect.eq('\r ', r.chomp('\r \n'))
    expect.eq('  message  ', r.chomp('  message  \n'))
    expect.eq(' \t message  ', r.chomp(' \t message  \n'))
end

MockFile = defclass(MockFile, nil)
MockFile.ATTRS{i=0,fname=DEFAULT_NIL}
function MockFile:close()
    self.close_called = (self.close_called or 0) + 1
end
function MockFile:read()
    self.i = self.i + 1
    return string.format('line %d\n', self.i)
end

local function mock_open(fname)
    return MockFile{fname=fname}
end

function test.TextReader()
    expect.error_match('failed to open "f"',
                       function()
                            r.TextReader{
                                filepath='f',
                                open_fn=function() return nil end}
                       end)

    local text_reader = r.TextReader{filepath='f', open_fn=mock_open}

    expect.eq('line 1', text_reader:get_next_row())
    expect.eq('line 2', text_reader:get_next_row())
    text_reader:redo()
    expect.eq('line 2', text_reader:get_next_row())
    expect.eq('line 3', text_reader:get_next_row())

    text_reader:cleanup()
    expect.eq(1, text_reader.source.close_called)
end

function test.CsvReader()
    local mock_tokenizer = function(line_fn, _) return {line_fn()} end

    expect.error_match('without a row_tokenizer',
                       function()
                           r.CsvReader{open_fn=function() return true end}
                       end)

    csvreader = r.CsvReader{
        filepath='f',
        row_tokenizer=mock_tokenizer,
        open_fn=mock_open}

    expect.table_eq({'line 1'}, csvreader:get_next_row_raw())
    expect.table_eq({'line 2'}, csvreader:get_next_row_raw())
end

MockXlsxioReader = defclass(MockXlsxioReader, nil)
MockXlsxioReader.ATTRS{i=0,lines={},filepath=DEFAULT_NIL}
function MockXlsxioReader:open_sheet() return self end
function MockXlsxioReader:get_row()
    self.i = self.i + 1
    return self.lines[self.i]
end
function MockXlsxioReader:reset(lines) self.i, self.lines = 0, lines end
function MockXlsxioReader:close()
    self.close_called = (self.close_called or 0) + 1
end
local function open_mock_xlsxio_reader(filepath)
    return MockXlsxioReader{filepath=filepath}
end

function test.XlsxReader()
    local xlsxreader = r.XlsxReader{open_fn=open_mock_xlsxio_reader}

    xlsxreader.source:reset({})
    expect.nil_(xlsxreader:get_next_row_raw())

    xlsxreader.source:reset({{'a','b1','b1.0','1c','1.0c','1','1.0'}})
    expect.table_eq({'a','b1','b1.0','1c','1.0c','1','1'},
                    xlsxreader:get_next_row_raw())

    -- expect close to be called 2 times since the mock is impersonating both
    -- the top-level reader and the sheet reader
    xlsxreader:cleanup()
    expect.eq(2, xlsxreader.source.close_called)
end
