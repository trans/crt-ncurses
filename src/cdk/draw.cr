module CDK
  module Draw
    ACS_ULCORNER = 'l'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_URCORNER = 'k'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_LLCORNER = 'm'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_LRCORNER = 'j'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_HLINE    = 'q'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_VLINE    = 'x'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_PLUS     = 'n'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_LTEE     = 't'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_RTEE     = 'u'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_BTEE     = 'v'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32
    ACS_TTEE     = 'w'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32

    # Set up basic color pairs
    def self.init_cdk_color
      if NCurses.has_colors?
        NCurses.start_color
        color = [
          LibNCurses::Color::White, LibNCurses::Color::Red,
          LibNCurses::Color::Green, LibNCurses::Color::Yellow,
          LibNCurses::Color::Blue, LibNCurses::Color::Magenta,
          LibNCurses::Color::Cyan, LibNCurses::Color::Black,
        ]
        limit = {LibNCurses.colors, 8}.min
        pair = 1_i16
        (0...limit).each do |fg|
          (0...limit).each do |bg|
            LibNCurses.init_pair(pair, color[fg].to_i16, color[bg].to_i16)
            pair += 1
          end
        end
      end
    end

    # Print a box around a window with attributes
    def self.box_window(window : NCurses::Window, attr : Int32)
      brx = window.max_x - 1
      bry = window.max_y - 1

      # Draw horizontal lines
      draw_hline(window, 0, 0, ACS_HLINE | attr, window.max_x)
      draw_hline(window, 0, bry, ACS_HLINE | attr, window.max_x)

      # Draw vertical lines
      draw_vline(window, 0, 0, ACS_VLINE | attr, window.max_y)
      draw_vline(window, brx, 0, ACS_VLINE | attr, window.max_y)

      # Draw corners
      mvwaddch(window, 0, 0, ACS_ULCORNER | attr)
      mvwaddch(window, 0, brx, ACS_URCORNER | attr)
      mvwaddch(window, bry, 0, ACS_LLCORNER | attr)
      mvwaddch(window, bry, brx, ACS_LRCORNER | attr)

      CDK::Screen.wrefresh(window)
    end

    # Draw a box with custom characters
    def self.attrbox(win : NCurses::Window, tlc : Int32, trc : Int32,
                     blc : Int32, brc : Int32, horz : Int32, vert : Int32, attr : Int32)
      y2 = win.max_y - 1
      x2 = win.max_x - 1
      count = 0

      if horz != 0
        draw_hline(win, 0, 0, horz | attr, win.max_x)
        draw_hline(win, 0, y2, horz | attr, win.max_x)
        count += 1
      end

      if vert != 0
        draw_vline(win, 0, 0, vert | attr, win.max_y)
        draw_vline(win, x2, 0, vert | attr, win.max_y)
        count += 1
      end

      if tlc != 0
        mvwaddch(win, 0, 0, tlc | attr)
        count += 1
      end
      if trc != 0
        mvwaddch(win, 0, x2, trc | attr)
        count += 1
      end
      if blc != 0
        mvwaddch(win, y2, 0, blc | attr)
        count += 1
      end
      if brc != 0
        mvwaddch(win, y2, x2, brc | attr)
        count += 1
      end

      CDK::Screen.wrefresh(win) if count != 0
    end

    # Draw a box using the object's defined line-drawing characters
    def self.draw_obj_box(win : NCurses::Window, object)
      attrbox(win,
        object.ul_char, object.ur_char, object.ll_char, object.lr_char,
        object.hz_char, object.vt_char, object.bx_attr)
    end

    # Draw a shadow around a window
    def self.draw_shadow(shadow_win : NCurses::Window?)
      return if shadow_win.nil?
      win = shadow_win.not_nil!

      x_hi = win.max_x - 1
      y_hi = win.max_y - 1

      dim = LibNCurses::Attribute::Dim.value.to_i32

      draw_hline(win, 1, y_hi, ACS_HLINE | dim, x_hi)
      draw_vline(win, x_hi, 0, ACS_VLINE | dim, y_hi)

      mvwaddch(win, 0, x_hi, ACS_URCORNER | dim)
      mvwaddch(win, y_hi, 0, ACS_LLCORNER | dim)
      mvwaddch(win, y_hi, x_hi, ACS_LRCORNER | dim)

      CDK::Screen.wrefresh(win)
    end

    # Write a string of blanks
    def self.write_blanks(window : NCurses::Window, xpos : Int32, ypos : Int32,
                          align : Int32, start : Int32, endn : Int32)
      if start < endn
        want = (endn - start) + 1000
        blanks = " " * (want - 1)
        write_char(window, xpos, ypos, blanks, align, start, endn)
      end
    end

    # Write a char string with no attributes
    def self.write_char(window : NCurses::Window, xpos : Int32, ypos : Int32,
                        string : String, align : Int32, start : Int32, endn : Int32)
      write_char_attrib(window, xpos, ypos, string, 0, align, start, endn)
    end

    # Write a char string with attributes
    def self.write_char_attrib(window : NCurses::Window, xpos : Int32, ypos : Int32,
                               string : String, attr : Int32, align : Int32,
                               start : Int32, endn : Int32)
      display = endn - start

      if align == CDK::HORIZONTAL
        display = {display, window.max_x - 1}.min
        (0...display).each do |x|
          idx = x + start
          break if idx >= string.size
          mvwaddch(window, ypos, xpos + x, string[idx].ord | attr)
        end
      else
        display = {display, window.max_y - 1}.min
        (0...display).each do |x|
          idx = x + start
          break if idx >= string.size
          mvwaddch(window, ypos + x, xpos, string[idx].ord | attr)
        end
      end
    end

    # Write a chtype (Int32) array
    def self.write_chtype(window : NCurses::Window, xpos : Int32, ypos : Int32,
                          string : Array(Int32), align : Int32, start : Int32, endn : Int32)
      write_chtype_attrib(window, xpos, ypos, string, 0, align, start, endn)
    end

    # Write a chtype array with given attributes added
    def self.write_chtype_attrib(window : NCurses::Window, xpos : Int32, ypos : Int32,
                                 string : Array(Int32), attr : Int32, align : Int32,
                                 start : Int32, endn : Int32)
      diff = endn - start

      if align == CDK::HORIZONTAL
        display = {diff, window.max_x - xpos}.min
        (0...display).each do |x|
          idx = x + start
          break if idx >= string.size
          mvwaddch(window, ypos, xpos + x, string[idx] | attr)
        end
      else
        display = {diff, window.max_y - ypos}.min
        (0...display).each do |x|
          idx = x + start
          break if idx >= string.size
          mvwaddch(window, ypos + x, xpos, string[idx] | attr)
        end
      end
    end

    # Draw a line on the given window
    def self.draw_line(window : NCurses::Window, startx : Int32, starty : Int32,
                       endx : Int32, endy : Int32, line : Int32)
      xdiff = endx - startx
      ydiff = endy - starty

      if ydiff == 0
        draw_hline(window, startx, starty, line, xdiff) if xdiff > 0
      elsif xdiff == 0
        draw_vline(window, startx, starty, line, ydiff) if ydiff > 0
      end
    end

    # Low-level helpers that write individual characters via LibNCurses

    def self.mvwaddch(window : NCurses::Window, y : Int32, x : Int32, ch : Int32)
      # Write the character byte and attribute separately via the ncurses lib
      char_byte = (ch & 0xFF).to_u8.unsafe_chr
      attr = LibNCurses::Attribute.new((ch & ~0xFF).to_u32)
      LibNCurses.wattron(window, attr)
      LibNCurses.mvwaddch(window, y, x, char_byte.ord.to_i8)
      LibNCurses.wattroff(window, attr)
    end

    def self.draw_hline(window : NCurses::Window, x : Int32, y : Int32, ch : Int32, len : Int32)
      char_byte = (ch & 0xFF).to_u8.unsafe_chr
      attr = LibNCurses::Attribute.new((ch & ~0xFF).to_u32)
      LibNCurses.wattron(window, attr)
      LibNCurses.wmove(window, y, x)
      LibNCurses.whline(window, char_byte.ord.to_i8, len)
      LibNCurses.wattroff(window, attr)
    end

    def self.draw_vline(window : NCurses::Window, x : Int32, y : Int32, ch : Int32, len : Int32)
      char_byte = (ch & 0xFF).to_u8.unsafe_chr
      attr = LibNCurses::Attribute.new((ch & ~0xFF).to_u32)
      LibNCurses.wattron(window, attr)
      LibNCurses.wmove(window, y, x)
      LibNCurses.wvline(window, char_byte.ord.to_i8, len)
      LibNCurses.wattroff(window, attr)
    end
  end
end
