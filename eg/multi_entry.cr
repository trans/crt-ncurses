require "../src/crt"

# Multi-line text entry — Enter inserts newlines, Tab to finish.

notes = nil

NCurses.start
begin
  screen = CRT::Ncurses::Screen.new(NCurses.stdscr)

  CRT::Ncurses::MultiEntry.open(screen,
    x: CRT::Ncurses::CENTER, y: CRT::Ncurses::CENTER,
    title: "[b]Enter Notes",
    label: "Notes: ",
    field_width: 40,
    field_rows: 8,
    logical_rows: 100,
    min: 0,
  ) do |mentry|
    mentry.newline_on_enter = true
    mentry.background = CRT::Ncurses.color("#FF/04")  # white on blue
    mentry.draw
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
