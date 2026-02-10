require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

fscale = CDK::FScale.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Temperature", "Temp: ", 0,
  15, 98.6, 95.0, 105.0,
  0.1, 1.0, 1, true, false)

result = fscale.activate

fscale.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Selected: %.1f" % result
