config = {
    mode = 'fortress',
    target = 'source',
}

local guidm = require('gui.dwarfmode')
local source = reqscript('source')

function test.delete_requires_cursor()
    mock.patch(guidm, 'getCursorPos', function() end, function()
        expect.error_match(
            'Please place the cursor where there is a source to delete',
            function() source.main{'delete'} end)
    end)
end

function test.add_requires_cursor()
    mock.patch(guidm, 'getCursorPos', function() end, function()
        expect.error_match(
            'Please place the cursor where you would like a source',
            function() source.main{'add', 'water'} end)
    end)
end
