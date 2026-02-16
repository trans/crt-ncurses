require "../src/crt"

# Scrollable list — pick a language.

languages = [
  "Crystal",
  "Ruby",
  "Python",
  "Rust",
  "Go",
  "Haskell",
  "Elixir",
  "C",
  "C++",
  "Zig",
  "Nim",
  "OCaml",
  "Lua",
  "JavaScript",
  "TypeScript",
]

picked = nil

NCurses.start
begin
  screen = CRT::Ncurses::Screen.new(NCurses.stdscr)

  CRT::Ncurses::Scroll.open(screen,
    x: CRT::Ncurses::CENTER, y: CRT::Ncurses::CENTER,
    box: true,
    height: 12, width: 30,
    title: "[b]Pick a Language",
    list: languages,
  ) do |scroll|
    scroll.activate
    picked = languages[scroll.current_item] if scroll.exit_type.normal?
  end
ensure
  NCurses.end
end

if p = picked
  puts "You picked: #{p}"
else
  puts "Cancelled."
end
