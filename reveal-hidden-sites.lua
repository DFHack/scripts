local count = 0
for _, site in ipairs(df.global.world.world_data.sites) do
  if site.flag.HIDDEN then
    site.flag.HIDDEN = false
    count = count + 1
  end
end

if count == 0 then
  print("No hidden sites detected!")
else
  print("Exposed " .. count .. " site" .. (count == 1 and "" or "s") .. "!")
end
