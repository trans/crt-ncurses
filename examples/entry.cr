require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

entry = CDK::Entry.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Enter your name", "Name: ",
  0, '_', CDK::DisplayType::MIXED,
  30, 1, 64,
  true, false)

result = entry.activate

entry.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "You entered: #{result}"
