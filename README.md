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
| **MultiEntry** | Multi-line text editor |
| **Button** | Standalone push button |
| **ButtonBox** | Group of buttons |
| **Scale(T)** | Numeric input with arrow keys — generic over any number type |
| **Slider(T)** | Slider bar — generic over any number type |
| **Scroll** | Scrolling list |
| **Radio** | Radio button list |
| **Selection** | Multi-select checklist |
| **ItemList** | Cycle through a list of values |
| **Template** | Formatted input with overlay template |
| **Histogram** | Horizontal/vertical bar chart |
| **Graph** | Line/plot graph |
| **Calendar** | Date picker |
| **Marquee** | Scrolling marquee text |
| **ScrollWindow** | Scrolling text output window |
| **Viewer** | Text file viewer with buttons |
| **Menu** | Menu bar with pull-down submenus |
| **AlphaList** | Filterable alphabetical list |
| **FileSelect** | File/directory selector |
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

## Format Strings

CRT provides a BBCode-style format string system for styled text. Use
`CRT.fmt` to convert a format string into a chtype array for display.

```crystal
# Bold text
CRT.fmt("[b]Hello![/]")

# Combined attributes and colors
CRT.fmt("[bold #0F]Status:[/] OK")

# Alignment (at string start)
CRT.fmt("[C][b]Centered Title[/]")
```

### Attributes

| Short | Long | Effect |
|-------|------|--------|
| `[b]` | `[bold]` | Bold |
| `[u]` | `[underline]` | Underline |
| `[dim]` | `[dim]` | Dim |
| `[rev]` | `[reverse]` | Reverse video |
| `[so]` | `[standout]` | Standout |
| `[bk]` | `[blink]` | Blink |

Multiple attributes can be combined in one tag: `[b u]`

### Colors

Colors use hex palette indices (00-FF, 256-color terminal palette):

| Notation | Meaning |
|----------|---------|
| `#XX` | Foreground color |
| `##XX` | Background color |
| `#XX/YY` | Foreground / background |
| `##YY/XX` | Background / foreground |

```crystal
CRT.fmt("[#0F]green text[/]")
CRT.fmt("[#FF/00]white on black[/]")
CRT.fmt("[b #0F/00]bold green on black[/]")
```

### Alignment

Place at the start of the string:

| Short | Long |
|-------|------|
| `[C]` | `[center]` |
| `[R]` | `[right]` |
| `[L]` | `[left]` |

### Style Stack

- `[/]` — pop the last style (restores previous attributes/colors)
- `[//]` — reset all styles
- `\[` — literal open bracket

### Named Styles

Register reusable styles with `CRT.style`:

```crystal
CRT.style("error", "bold #FF ##00")
CRT.style("header", "bold underline #0F")

CRT.fmt("[error]Oops![/] Something broke")
CRT.fmt("[header]Welcome[/]")
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
