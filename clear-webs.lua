-- Removes webs and frees webbed units.
-- Author: Atomic Chicken

local utils = require('utils')
local validArgs = utils.invert({
  'unitsOnly',
  'websOnly',
  'help'
})
local args = utils.processArgs({...}, validArgs)

if args.help then
  print(dfhack.script_help())
  return
end

if args.unitsOnly and args.websOnly then
  qerror("You have specified both --unitsOnly and --websOnly. These cannot be used together.")
end

local webCount = 0
if not args.unitsOnly then
  for i = #df.global.world.items.other.ANY_WEBS-1, 0, -1 do
    dfhack.items.remove(df.global.world.items.other.ANY_WEBS[i])
    webCount = webCount + 1
  end
end

local unitCount = 0
if not args.websOnly then
  for _, unit in ipairs(df.global.world.units.active) do
    if unit.counters.webbed > 0 and not unit.flags2.killed and not unit.flags1.inactive then -- the webbed status is retained in death
      unitCount = unitCount + 1
      unit.counters.webbed = 0
    end
  end
end

if not args.unitsOnly then
  if webCount == 0 then
    print("No webs detected!")
  else
    print("Removed " .. webCount .. " web" .. (webCount == 1 and "" or "s") .. "!")
  end
end

if not args.websOnly then
  if unitCount == 0 then
    print("No captured units detected!")
  else
    print("Freed " .. unitCount .. " unit" .. (unitCount == 1 and "" or "s") .. "!")
  end
end
