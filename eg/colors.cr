require "../src/crt"

# Format string showcase — demonstrates CRT.fmt with colors, attributes,
# and named styles. Press any key to exit.

NCurses.start

begin
  screen = CRT::Screen.new(NCurses.stdscr)
  win = screen.window.not_nil!

  # Register some named styles
  CRT.style("error", "bold #C4/00")
  CRT.style("ok", "bold #2A/00")
  CRT.style("warn", "#E0/00")
  CRT.style("heading", "bold underline #FE")
  CRT.style("muted", "dim")

  lines = [
    CRT.fmt("[heading]CRT Format String Demo[/]"),
    CRT.fmt(""),
    CRT.fmt("[b]Bold[/]  [u]Underline[/]  [dim]Dim[/]  [rev]Reverse[/]  [bk]Blink[/]"),
    CRT.fmt("[b u]Bold + Underline[/]  [b rev]Bold + Reverse[/]"),
    CRT.fmt(""),
    CRT.fmt("[#C4]Red[/]  [#2A]Green[/]  [#15]Blue[/]  [#E0]Yellow[/]  [#CB]Magenta[/]  [#2D]Cyan[/]"),
    CRT.fmt("[#FF/04]White on Blue[/]  [#00/E0]Black on Yellow[/]  [##2A/FE]Green bg, White fg[/]"),
    CRT.fmt(""),
    CRT.fmt("[error]Error: something broke[/]"),
    CRT.fmt("[ok]Success: all clear[/]"),
    CRT.fmt("[warn]Warning: check this[/]"),
    CRT.fmt("[muted]This is dimmed text[/]"),
    CRT.fmt(""),
    CRT.fmt("[b]Nested:[/] [#C4]red [b]bold red [u]bold underline red[/] bold red[/] red[/] plain"),
    CRT.fmt(""),
    CRT.fmt("[muted]Press any key to exit.[/]"),
  ]

  # Draw each line
  y_start = 1
  lines.each_with_index do |line, i|
    len = line.size
    CRT::Draw.write_chtype(win, 2, y_start + i, line, CRT::HORIZONTAL, 0, len)
  end

  CRT::Screen.wrefresh(win)

  # Wait for a key
  LibNCurses.curs_set(0)
  win.get_char
ensure
  NCurses.end
end
