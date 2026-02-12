require "../src/crt"

# Simple label display — press any key to exit.

NCurses.start

begin
  screen = CRT::Screen.new(NCurses.stdscr)

  CRT::Label.open(screen,
    x: CRT::CENTER, y: CRT::CENTER,
    box: true,
    mesg: [
      "",
      " [b]CRT Label Example[/] ",
      "",
      " A simple boxed label widget. ",
      " Press any key to exit.       ",
      "",
    ]
  ) do |label|
    label.draw
    label.wait(0)
  end
ensure
  NCurses.end
end
