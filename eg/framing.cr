require "../src/crt"

# Framing example — demonstrates both manual framing and widget-integrated
# framing with smart intersection resolution. Press any key to exit.

NCurses.start

begin
  screen = CRT::Screen.new(NCurses.stdscr)

  framing = CRT::Framing.new(screen)

  # Manual framing: two adjacent boxes sharing a vertical edge at x=30
  framing.add(x: 5, y: 2, h: 26, v: 12)   # left box:  cols 5-30, rows 2-13
  framing.add(x: 30, y: 2, h: 26, v: 12)  # right box: cols 30-55, rows 2-13

  # Horizontal divider across both boxes at row 8
  framing.add(x: 5, y: 8, h: 51)

  framing.draw

  # Place labels inside the framed regions (no box of their own)
  CRT::Label.open(screen,
    x: 7, y: 3,
    mesg: [
      "[b]Top Left",
      "",
      "This panel shares",
      "edges with others.",
    ]
  ) do |_l1|
    CRT::Label.open(screen,
      x: 32, y: 3,
      mesg: [
        "[b]Top Right",
        "",
        "Intersections are",
        "resolved smartly.",
      ]
    ) do |_l2|
      CRT::Label.open(screen,
        x: 7, y: 9,
        mesg: [
          "[b]Bottom Left",
          "",
          "Tees and crosses",
          "appear correctly.",
        ]
      ) do |_l3|
        # Widget-integrated framing: pass framing instance as box parameter.
        # The label registers itself with the framing, getting border spacing
        # without drawing its own box — the framing draws it with smart intersections.
        CRT::Label.open(screen,
          x: 32, y: 9,
          box: framing,
          mesg: [
            "[b]Bottom Right",
            "",
            "Press any key",
            "to exit.",
          ]
        ) do |l4|
          framing.draw
          l4.wait(0)
        end
      end
    end
  end
ensure
  NCurses.end
end
