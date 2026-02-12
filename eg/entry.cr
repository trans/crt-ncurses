require "../src/crt"

# Text entry — type your name and press Enter.

name = nil

NCurses.start
begin
  screen = CRT::Screen.new(NCurses.stdscr)

  CRT::Entry.open(screen,
    x: CRT::CENTER, y: CRT::CENTER,
    box: true,
    title: "[b]Enter Your Name",
    label: "Name: ",
    field_width: 30,
    min: 1, max: 256,
  ) do |entry|
    entry.activate
    name = entry.info if entry.exit_type.normal?
  end
ensure
  NCurses.end
end

if n = name
  puts "Hello, #{n}!"
else
  puts "Cancelled."
end
