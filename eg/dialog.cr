require "../src/crt"

# Dialog with buttons — choose Yes, No, or Maybe.

choices = ["Yes", "No", "Maybe"]
picked = nil

NCurses.start
begin
  screen = CRT::Screen.new(NCurses.stdscr)

  CRT::Dialog.open(screen,
    x: CRT::CENTER, y: CRT::CENTER,
    mesg: [
      "",
      "  </B>Do you like terminal UIs?  ",
      "",
    ],
    buttons: [" Yes ", " No ", " Maybe "],
  ) do |dialog|
    dialog.activate
    picked = choices[dialog.current_button] if dialog.exit_type.normal?
  end
ensure
  NCurses.end
end

if p = picked
  puts "You chose: #{p}"
else
  puts "Cancelled."
end
