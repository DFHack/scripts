-- Changes heavy aquifers to light pre embark
local help = [====[

lightaqonly
===========
Changes the Drainage of all world tiles that would generate Heavy aquifers into
a value that results in Light aquifers instead.

Note that the script has to be run before embarking to have any effect on an embark.

This script is based on logic revealed by Toady in a FotF answer:
http://www.bay12forums.com/smf/index.php?topic=169696.msg8099138#msg8099138
Basically the Drainage is used as an "RNG" to cause an aquifer to be heavy
about 5% of the time. The script shifts the matching numbers to a neighboring
one, which does not result in any change of the biome.
]====]
function lightaqonly ()
  if not dfhack.isWorldLoaded () then
    qerror ("Error: This script requires a world to be loaded.")
  end

  if dfhack.isMapLoaded () then
    qerror ("Error: This script requires a world to be loaded, but not a map.")
  end

  for i = 0, df.global.world.world_data.world_width - 1 do
    for k = 0, df.global.world.world_data.world_height - 1 do
      local tile = df.global.world.world_data.region_map [i]:_displace (k)
      
      if tile.drainage % 20 == 7 then
        tile.drainage = tile.drainage + 1
      end
    end
  end
end

lightaqonly ()