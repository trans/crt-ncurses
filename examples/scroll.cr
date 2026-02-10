require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

items = (1..20).map { |i| "Item number #{i}" }

scroll = CDK::Scroll.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  CDK::RIGHT, 15, 40,
  "</B>Pick an item",
  items, items.size, false,
  LibNCurses::Attribute::Reverse.value.to_i32,
  true, false)

selection = scroll.activate

scroll.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if selection >= 0
  puts "Selected: #{items[selection]}"
else
  puts "No selection made."
end
