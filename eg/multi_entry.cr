require "../src/crt"

# Multi-line text entry — type some notes and press Tab to finish.

notes = nil

NCurses.start
begin
  screen = CRT::Screen.new(NCurses.stdscr)

  CRT::MultiEntry.open(screen,
    x: CRT::CENTER, y: CRT::CENTER,
    box: true,
    title: "[b]Enter Notes",
    label: "Notes: ",
    field_width: 40,
    field_rows: 8,
    logical_rows: 100,
    min: 0,
  ) do |mentry|
    mentry.activate
    notes = mentry.info if mentry.exit_type.normal?
  end
ensure
  NCurses.end
end

if n = notes
  puts "You wrote:\n#{n}"
else
  puts "Cancelled."
end
