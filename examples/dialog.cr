require "../src/cdk"

NCurses.start
NCurses.cbreak
NCurses.no_echo
CDK::Draw.init_cdk_color

cdkscreen = CDK::Screen.new(NCurses.stdscr)

mesg = [
  "</B>Save changes?",
  "",
  "Your file has been modified.",
  "Do you want to save it?",
]

buttons = ["</B>Yes", "No", "Cancel"]

dialog = CDK::Dialog.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  mesg, mesg.size, buttons, buttons.size,
  LibNCurses::Attribute::Reverse.value.to_i32, true, true, false)

selection = dialog.activate

dialog.destroy
cdkscreen.destroy
CDK::Screen.end_cdk

puts "Selected button: #{selection}"
