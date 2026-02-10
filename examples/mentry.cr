require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

mentry = CDK::Mentry.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Enter Notes", "Notes: ", 0, '.', CDK::DisplayType::MIXED,
  30, 5, 20, 0, true, false)

result = mentry.activate

mentry.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Entered: #{result}"
