require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

months = ["January", "February", "March", "April", "May", "June",
          "July", "August", "September", "October", "November", "December"]

itemlist = CDK::Itemlist.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Pick a month", "Month: ", months, months.size, 0, true, false)

selection = itemlist.activate

itemlist.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if selection >= 0
  puts "Selected: #{months[selection]}"
else
  puts "No selection."
end
