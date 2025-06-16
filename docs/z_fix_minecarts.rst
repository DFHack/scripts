This DFHack script iterates over all minecart tool items in the current Dwarf Fortress world, clears their `in_job` flag if it’s set, and reports the total number of flags flipped from `true` to `false`.

## Features

* **Tool Scanning**: Identifies all items of subtype `ITEM_TOOL_MINECART`.
* **Flag Clearing**: Automatically clears the `in_job` flag on minecart tools that are currently marked in a job.
* **Summary Reporting**: Outputs the total count of flags flipped from `true` to `false`.
