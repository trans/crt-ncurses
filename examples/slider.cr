require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

filler = ' '.ord | LibNCurses::Attribute::Reverse.value.to_i32

slider = CDK::Slider.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Select a value", "Value: ", filler,
  20, 50, 0, 100,
  1, 5, true, false)

result = slider.activate

slider.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Selected value: #{result}"
