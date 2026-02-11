require "../src/crt"

# Numeric scale — pick a value between 0 and 100.

volume = nil

NCurses.start
begin
  screen = CRT::Screen.new(NCurses.stdscr)

  CRT::Scale(Int32).open(screen,
    x: CRT::CENTER, y: CRT::CENTER,
    low: 0, high: 100, step: 1, page: 10,
    title: "</B>Volume",
    label: "Level: ",
    start: 50,
    field_width: 5,
  ) do |scale|
    scale.activate
    volume = scale.current if scale.exit_type.normal?
  end
ensure
  NCurses.end
end

if v = volume
  puts "Volume set to: #{v}"
else
  puts "Cancelled."
end
