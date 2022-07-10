
light-aquifers-only
===================
This script behaves differently depending on whether it's called pre embark or post
embark. Pre embark it changes all aquifers in the world to light ones, while post
embark it only changes the ones at the embark to light ones, leaving the rest of the
world unchanged.

Pre embark:
Changes the Drainage of all world tiles that would generate Heavy aquifers into
a value that results in Light aquifers instead.

This script is based on logic revealed by ToadyOne in a FotF answer:
http://www.bay12forums.com/smf/index.php?topic=169696.msg8099138#msg8099138
Basically the Drainage is used as an "RNG" to cause an aquifer to be heavy
about 5% of the time. The script shifts the matching numbers to a neighboring
one, which does not result in any change of the biome.

Post embark:
Clears the flags that mark aquifer tiles as heavy, converting them to light.
