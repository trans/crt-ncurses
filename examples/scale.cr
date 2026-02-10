require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

scale = CDK::Scale.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Select a value", "Value: ", 0,
  10, 50, 0, 100,
  1, 5, true, false)

result = scale.activate

scale.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Selected value: #{result}"
