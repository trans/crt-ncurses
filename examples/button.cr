require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

callback = ->(button : CDK::Button) { nil }

button = CDK::Button.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>  Click Me!  ", callback, true, false)

result = button.activate

button.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Button returned: #{result}"
