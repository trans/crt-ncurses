# CRT

A Crystal library of curses widgets for building terminal user interfaces.

CRT provides 23 ready-to-use widgets — from simple labels and buttons to
scrolling lists, text editors, menus, file selectors, and spreadsheet-style
grids — all rendered with ncurses.

Ported from [Ruby CDK](https://github.com/movitto/cdk).

## Widgets

| Widget | Description |
|--------|-------------|
| **Label** | Static text display |
| **Dialog** | Message box with buttons |
| **Entry** | Single-line text input |
| **Mentry** | Multi-line text editor |
| **Button** | Standalone push button |
| **ButtonBox** | Group of buttons |
| **Scale(T)** | Numeric input with arrow keys — generic over any number type |
| **Slider(T)** | Slider bar — generic over any number type |
| **Scroll** | Scrolling list |
| **Radio** | Radio button list |
| **Selection** | Multi-select checklist |
| **Itemlist** | Cycle through a list of values |
| **Template** | Formatted input with overlay template |
| **Histogram** | Horizontal/vertical bar chart |
| **Graph** | Line/plot graph |
| **Calendar** | Date picker |
| **Marquee** | Scrolling marquee text |
| **Swindow** | Scrolling text output window |
| **Viewer** | Text file viewer with buttons |
| **Menu** | Menu bar with pull-down submenus |
| **Alphalist** | Filterable alphabetical list |
| **Fselect** | File/directory selector |
| **Matrix** | Spreadsheet-style editable grid |

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     crt:
       github: trans/crt
   ```

2. Run `shards install`

**Requires** ncurses development headers (`libncurses-dev`, `ncurses-devel`,
or equivalent for your system).

## Usage

```crystal
require "crt"

# Initialize ncurses
NCurses.init
NCurses.cbreak
NCurses.no_echo
NCurses.start_color

# Create a screen
screen = CRT::Screen.new

# Display a label
label = CRT::Label.new(screen,
  CRT::CENTER, CRT::CENTER,
  ["</B>Hello, CRT!", "Press any key to exit."],
  box: true, shadow: true)

label.draw(true)
label.wait(0)

# Clean up
label.destroy
screen.destroy
NCurses.end_win
```

## Development

```sh
crystal spec          # Run tests
crystal build src/crt.cr --no-codegen  # Type-check without building
```

## Contributing

1. Fork it (<https://github.com/trans/crt/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT
