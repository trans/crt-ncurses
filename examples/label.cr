require "../src/cdk"

# Initialize ncurses
NCurses.start
NCurses.cbreak
NCurses.no_echo

# Initialize CDK colors
CDK::Draw.init_cdk_color

# Create a CDK screen
cdkscreen = CDK::Screen.new(NCurses.stdscr)

# Define the label message
mesg = [
  "</B>Welcome to CDK.cr",
  "",
  "A Crystal port of the",
  "Curses Development Kit",
  "",
  "</U>Press any key to exit...",
]

# Create the label widget
label = CDK::Label.new(cdkscreen, CDK::CENTER, CDK::CENTER,
  mesg, mesg.size, true, false)

# Draw the label
label.draw(true)

# Wait for input
label.wait

# Clean up
label.destroy
cdkscreen.destroy
CDK::Screen.end_cdk
