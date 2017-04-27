# Unforbid all items
=begin

unforbid
========

unforbid all

Options available: ``all``, ```help```

=end

help = <<HELP
unforbid {all|help}

  all  - unforbid all items
  help - help
HELP

case $script_args[0]
when 'all'
    puts "Unforbidding all items..."
when 'help'
    puts help
    throw :script_finished
else
    puts "Error!"
    puts help
    throw :script_finished
end

DFHack.world.items.all.each { |item|
    if item.flags.forbid then
        puts "Unforbid: #{item}"
	      item.flags.forbid = false
   end
}
