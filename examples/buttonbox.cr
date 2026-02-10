require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

buttons = ["</B>  OK  ", "Cancel", " Help "]

bbox = CDK::Buttonbox.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  5, 40, "</B>Choose an action",
  1, 3, buttons, buttons.size,
  LibNCurses::Attribute::Reverse.value.to_i32,
  true, false)

result = bbox.activate

bbox.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if result >= 0
  puts "Selected button: #{buttons[result].gsub(/<[^>]*>/, "").strip}"
else
  puts "Cancelled."
end
