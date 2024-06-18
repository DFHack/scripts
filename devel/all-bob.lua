-- Changes the first name of all units to "Bob"
--author expwnent

for _,v in ipairs(df.global.world.units.active) do
 v.name.first_name = "Bob"
end
