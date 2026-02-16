require "../src/crt"

# Format string showcase — demonstrates CRT::Ncurses.fmt with colors, attributes,
# and named styles. Press any key to exit.

NCurses.start

begin
  screen = CRT::Ncurses::Screen.new(NCurses.stdscr)
  win = screen.window.not_nil!

  # Register some named styles
  CRT::Ncurses.style("error", "bold #C4/00")
  CRT::Ncurses.style("ok", "bold #2A/00")
  CRT::Ncurses.style("warn", "#E0/00")
  CRT::Ncurses.style("heading", "bold underline #FE")
  CRT::Ncurses.style("muted", "dim")

  lines = [
    CRT::Ncurses.fmt("[heading]CRT Format String Demo[/]"),
    CRT::Ncurses.fmt(""),
    CRT::Ncurses.fmt("[b]Bold[/]  [u]Underline[/]  [dim]Dim[/]  [rev]Reverse[/]  [bk]Blink[/]"),
    CRT::Ncurses.fmt("[b u]Bold + Underline[/]  [b rev]Bold + Reverse[/]"),
    CRT::Ncurses.fmt(""),
    CRT::Ncurses.fmt("[#C4]Red[/]  [#2A]Green[/]  [#15]Blue[/]  [#E0]Yellow[/]  [#CB]Magenta[/]  [#2D]Cyan[/]"),
    CRT::Ncurses.fmt("[#FF/04]White on Blue[/]  [#00/E0]Black on Yellow[/]  [##2A/FE]Green bg, White fg[/]"),
    CRT::Ncurses.fmt(""),
    CRT::Ncurses.fmt("[error]Error: something broke[/]"),
    CRT::Ncurses.fmt("[ok]Success: all clear[/]"),
    CRT::Ncurses.fmt("[warn]Warning: check this[/]"),
    CRT::Ncurses.fmt("[muted]This is dimmed text[/]"),
    CRT::Ncurses.fmt(""),
    CRT::Ncurses.fmt("[b]Nested:[/] [#C4]red [b]bold red [u]bold underline red[/] bold red[/] red[/] plain"),
    CRT::Ncurses.fmt(""),
    CRT::Ncurses.fmt("[muted]Press any key to exit.[/]"),
  ]

  # Draw each line
  y_start = 1
  lines.each_with_index do |line, i|
    len = line.size
    CRT::Ncurses::Draw.write_chtype(win, 2, y_start + i, line, CRT::Ncurses::HORIZONTAL, 0, len)
  end

  CRT::Ncurses::Screen.wrefresh(win)

  # Test CRT::Ncurses.color for background
  label = CRT::Ncurses::Label.new(screen,
    x: 2, y: lines.size + 2,
    mesg: ["  CRT::Ncurses.color demo — white on blue  "])
  label.background = CRT::Ncurses.color(7, 4)
  label.draw

  # Wait for a key
  LibNCurses.curs_set(0)
  win.get_char
ensure
  NCurses.end
end
