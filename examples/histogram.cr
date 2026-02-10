require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

histogram = CDK::Histogram.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  10, 50, CDK::HORIZONTAL,
  "</B>Disk Usage", true, false)

filler = ' '.ord | LibNCurses::Attribute::Reverse.value.to_i32

histogram.set(CDK::HistViewType::PERCENT, CDK::TOP, 0,
  0, 100, 73, filler, true)

histogram.draw(true)

# Wait for a keypress
NCurses.stdscr.get_char

histogram.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Histogram displayed successfully."
