
fix/fat-dwarves
===============
Avoids 5-10% FPS loss due to constant recalculation of insulation for dwarves at
maximum fatness, by reducing the cap from 1,000,000 to 999,999.
Recalculation is triggered in steps of 250 units, and very fat dwarves
constantly bounce off the maximum value while eating.

