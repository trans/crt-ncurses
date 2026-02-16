module CRT::Ncurses
  # Safely erase a given window
  def self.erase_curses_window(window : NCurses::Window?)
    return if window.nil?
    win = window.not_nil!
    win.erase
    CRT::Ncurses::Screen.wrefresh(win)
  end

  # Safely delete a given window
  def self.delete_curses_window(window : NCurses::Window?)
    return if window.nil?
    win = window.not_nil!
    erase_curses_window(win)
    win.delete_window
  end

  # Move a given window to an absolute position
  def self.move_curses_window(window : NCurses::Window?, xpos : Int32, ypos : Int32)
    return if window.nil?
    win = window.not_nil!
    win.erase
    win.move_window(ypos, xpos)
  end

  # If the dimension is a negative value, the dimension will be the full
  # height/width of the parent window minus the absolute value. Otherwise,
  # the dimension will be the given value.
  def self.set_widget_dimension(parent_dim : Int32, proposed_dim : Int32, adjustment : Int32) : Int32
    if proposed_dim == FULL || proposed_dim == 0
      parent_dim
    elsif proposed_dim >= 0
      if proposed_dim >= parent_dim
        parent_dim
      else
        proposed_dim + adjustment
      end
    else
      if parent_dim + proposed_dim < 0
        parent_dim
      else
        parent_dim + proposed_dim
      end
    end
  end

  # Beep and flush
  def self.beep
    LibNCurses.beep
    STDOUT.flush
  end

  # Create a subwindow
  def self.subwin(parent : NCurses::Window, height : Int32, width : Int32,
                  y : Int32, x : Int32) : NCurses::Window
    NCurses::Window.new(LibNCurses.subwin(parent, height, width, y, x))
  end
end

# Additional LibNCurses bindings needed by CRT
lib LibNCurses
  fun beep : LibC::Int
  fun touchwin(window : Window) : LibC::Int
  fun noutrefresh = wnoutrefresh(window : Window) : LibC::Int
  fun getbegx(window : Window) : LibC::Int
  fun getbegy(window : Window) : LibC::Int
  fun subwin(window : Window, height : LibC::Int, width : LibC::Int,
             row : LibC::Int, col : LibC::Int) : Window
  fun mvwinch(window : Window, y : LibC::Int, x : LibC::Int) : LibC::UInt
  fun napms(ms : LibC::Int) : LibC::Int
  fun wclrtoeol(window : Window) : LibC::Int
  fun mvwdelch(window : Window, y : LibC::Int, x : LibC::Int) : LibC::Int
  fun mvwinsch(window : Window, y : LibC::Int, x : LibC::Int, ch : LibC::Char) : LibC::Int
  fun curs_set(visibility : LibC::Int) : LibC::Int
end
