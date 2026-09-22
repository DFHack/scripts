--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local plugin = require('plugins.export-world-map')

---get folder to place output files
---@param by_world boolean
---@param by_date boolean
---@return string
function getOutputFolder(by_world, by_date)
    local by_world = by_world or by_date
    return ('%s/map-export/%s%s'):format(
        dfhack.getConfigPath(),
        by_world and plugin.getWorldFolderName()..'/' or '',
        by_date and plugin.getDateFolderName()..'/' or ''
    )
end
