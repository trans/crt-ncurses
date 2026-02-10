require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

template = CDK::Template.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  "</B>Phone Number", "Number: ",
  "(###) ###-####",
  "(___) ___-____",
  true, false)

result = template.activate

mixed = template.mix

template.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

if result.size > 0
  puts "Input: #{result}"
  puts "Mixed: #{mixed}"
else
  puts "No input."
end
