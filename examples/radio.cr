require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

items = ["Red", "Green", "Blue", "Yellow", "Magenta", "Cyan"]

radio = CDK::Radio.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  CDK::RIGHT, 12, 30,
  "</B>Pick a color",
  items, items.size, 'X', 0,
  LibNCurses::Attribute::Reverse.value.to_i32,
  true, false)

selection = radio.activate

radio.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if selection >= 0
  puts "Selected: #{items[selection]}"
else
  puts "No selection."
end
