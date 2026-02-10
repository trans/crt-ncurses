module CRT
  class Scroll < CRT::Scroller
    include CommonControls

    getter item : Array(Array(Int32)) = [] of Array(Int32)
    getter item_len : Array(Int32) = [] of Int32
    getter item_pos : Array(Int32) = [] of Int32
    getter highlight : Int32 = 0

    property scrollbar : Bool = false
    property scrollbar_placement : Int32 = CRT::RIGHT
    property scrollbar_win : NCurses::Window? = nil
    property list_win : NCurses::Window? = nil
    property toggle_pos : Int32 = 0
    property numbers : Bool = false
    property parent : NCurses::Window? = nil

    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, list : Array(String),
                   splace : Int32 = CRT::RIGHT, title : String = "",
                   numbers : Bool = false,
                   highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = width
      box_height = height
      scroll_adjust = 0

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)
      box_width = set_title(title, box_width)

      # Set the box height
      if @title_lines > box_height
        box_height = @title_lines + {list.size, 8}.min + 2 * @border_size
      end

      # Adjust box width for scrollbar
      if splace == CRT::LEFT || splace == CRT::RIGHT
        @scrollbar = true
        box_width += 1
      else
        @scrollbar = false
      end

      # Clamp dimensions
      @box_width = {box_width, parent_width}.min
      @box_height = {box_height, parent_height}.min

      set_view_size(list.size)

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      # Create the scrolling window
      @win = NCurses::Window.new(height: @box_height, width: @box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Create the scrollbar window
      if splace == CRT::RIGHT
        @scrollbar_win = CRT.subwin(w, max_view_size, 1,
          screen_ypos(ypos), xpos + box_width - @border_size - 1)
      elsif splace == CRT::LEFT
        @scrollbar_win = CRT.subwin(w, max_view_size, 1,
          screen_ypos(ypos), screen_xpos(xpos))
      else
        @scrollbar_win = nil
      end

      # Create the list window
      scrollbar_offset = splace == CRT::LEFT ? 1 : 0
      @list_win = CRT.subwin(w, max_view_size,
        box_width - (2 * @border_size) - scroll_adjust,
        screen_ypos(ypos),
        screen_xpos(xpos) + scrollbar_offset)

      # Set the rest of the variables
      @screen = cdkscreen
      @parent = parent_window
      @shadow_win = nil
      @scrollbar_placement = splace
      @max_left_char = 0
      @left_char = 0
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow

      set_position(0)

      # Create the scrolling list items
      if create_item_list(numbers, list, list.size) <= 0
        return
      end

      # Shadow window
      if shadow
        @shadow_win = NCurses::Window.new(
          height: @box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      # Set up key bindings
      bind(:SCROLL, CRT::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)
      bind(:SCROLL, CRT::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(:SCROLL, 'g'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SCROLL, '1'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SCROLL, 'G'.ord, :getc, LibNCurses::Key::End.value)
      bind(:SCROLL, '<'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:SCROLL, '>'.ord, :getc, LibNCurses::Key::End.value)

      cdkscreen.register(:SCROLL, self)
    end

    def object_type : Symbol
      :SCROLL
    end

    def fix_cursor_position
      scrollbar_adj = @scrollbar_placement == CRT::LEFT ? 1 : 0
      ypos = screen_ypos(@current_item - @current_top)
      xpos = screen_xpos(0) + scrollbar_adj

      if iw = @input_window
        iw.move(ypos, xpos)
        CRT::Screen.wrefresh(iw)
      end
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          fix_cursor_position
          input = getch([] of Bool)
          ret = inject(input)
          return ret if @exit_type != CRT::ExitType::EARLY_EXIT
        end
      else
        actions.each do |action|
          ret = inject(action)
          return ret if @exit_type != CRT::ExitType::EARLY_EXIT
        end
      end

      set_exit_type(0)
      -1
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw_list(@box)

      case input
      when LibNCurses::Key::Up.value
        key_up
      when LibNCurses::Key::Down.value
        key_down
      when LibNCurses::Key::Right.value
        key_right
      when LibNCurses::Key::Left.value
        key_left
      when LibNCurses::Key::PageUp.value
        key_ppage
      when LibNCurses::Key::PageDown.value
        key_npage
      when LibNCurses::Key::Home.value
        key_home
      when LibNCurses::Key::End.value
        key_end
      when '$'.ord
        @left_char = @max_left_char
      when '|'.ord
        @left_char = 0
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      when CRT::KEY_TAB, LibNCurses::Key::Enter.value, CRT::KEY_RETURN
        if quit_on_enter?
          set_exit_type(input)
          ret = @current_item
          @complete = true
        end
      end

      unless @complete
        draw_list(@box)
        set_exit_type(0)
      end

      fix_cursor_position
      @result_data = ret
      ret
    end

    def get_current_top : Int32
      @current_top
    end

    def set_current_top(item : Int32)
      item = 0 if item < 0
      item = @max_top_item if item > @max_top_item
      @current_top = item
      set_position(item)
    end

    def draw(box : Bool)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        draw_title(w)
      end

      draw_list(box)
    end

    def draw_current
      return unless lw = @list_win

      screen_pos = @item_pos[@current_item] - @left_char
      hl = has_focus ? @highlight : 0

      Draw.write_chtype_attrib(lw,
        screen_pos >= 0 ? screen_pos : 0,
        @current_high, @item[@current_item], hl, CRT::HORIZONTAL,
        screen_pos >= 0 ? 0 : 1 - screen_pos,
        @item_len[@current_item])
    end

    def draw_list(box : Bool)
      return unless lw = @list_win

      if @list_size > 0
        (0...@view_size).each do |j|
          k = j + @current_top

          Draw.write_blanks(lw, 0, j, CRT::HORIZONTAL, 0,
            @box_width - (2 * @border_size))

          if k < @list_size
            screen_pos = @item_pos[k] - @left_char
            Draw.write_chtype(lw,
              screen_pos >= 0 ? screen_pos : 1,
              j, @item[k], CRT::HORIZONTAL,
              screen_pos >= 0 ? 0 : 1 - screen_pos,
              @item_len[k])
          end
        end

        draw_current

        # Draw scrollbar
        if sw = @scrollbar_win
          @toggle_pos = (@current_item * @step).floor.to_i32
          @toggle_pos = sw.max_y - 1 if @toggle_pos >= sw.max_y

          # Draw the scrollbar track
          Draw.draw_vline(sw, 0, 0,
            'a'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32, # ACS_CKBOARD
            sw.max_y)
          # Draw the toggle
          (0...@toggle_size).each do |i|
            pos = @toggle_pos + i
            break if pos >= sw.max_y
            Draw.mvwaddch(sw, pos, 0,
              ' '.ord | LibNCurses::Attribute::Reverse.value.to_i32)
          end
        end
      end

      # Box it if needed
      if box
        if w = @win
          Draw.draw_obj_box(w, self)
        end
      end

      wrefresh
    end

    def set_bk_attr(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
      if lw = @list_win
        LibNCurses.wbkgd(lw, attrib.to_u32)
      end
      if sw = @scrollbar_win
        LibNCurses.wbkgd(sw, attrib.to_u32)
      end
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CRT.delete_curses_window(@scrollbar_win)
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@list_win)
      CRT.delete_curses_window(@win)
      clean_bindings(:SCROLL)
      CRT::Screen.unregister(:SCROLL, self)
    end

    def alloc_list_item(which : Int32, number : Int32, value : String) : Bool
      display_value = number > 0 ? "%4d. %s" % [number, value] : value

      item_len = [] of Int32
      item_pos = [] of Int32
      @item[which] = char2chtype(display_value, item_len, item_pos)
      @item_len[which] = item_len[0]
      @item_pos[which] = item_pos[0]
      @item_pos[which] = justify_string(@box_width, @item_len[which], @item_pos[which])
      true
    end

    def create_item_list(numbers : Bool, list : Array(String), list_size : Int32) : Int32
      return 1 if list_size <= 0

      widest_item = 0
      @item = Array(Array(Int32)).new(list_size) { [] of Int32 }
      @item_len = Array(Int32).new(list_size, 0)
      @item_pos = Array(Int32).new(list_size, 0)

      list_size.times do |x|
        number = numbers ? x + 1 : 0
        return 0 unless alloc_list_item(x, number, list[x])
        widest_item = {@item_len[x], widest_item}.max
      end

      update_view_width(widest_item)
      @numbers = numbers
      1
    end

    def set_items(list : Array(String), list_size : Int32, numbers : Bool)
      return if create_item_list(numbers, list, list_size) <= 0

      set_view_size(list_size)
      set_position(0)
      @left_char = 0
    end

    def get_items : Array(String)
      (0...@list_size).map do |x|
        chtype2char(@item[x])
      end
    end

    def set_highlight(highlight : Int32)
      @highlight = highlight
    end

    def add_item(item : String)
      item_number = @list_size
      widest_item = widest_item_width

      @item << [] of Int32
      @item_len << 0
      @item_pos << 0

      number = @numbers ? item_number + 1 : 0
      if alloc_list_item(item_number, number, item)
        widest_item = {@item_len[item_number], widest_item}.max
        update_view_width(widest_item)
        set_view_size(@list_size + 1)
      end
    end

    def delete_item(position : Int32)
      return unless position >= 0 && position < @list_size

      @item.delete_at(position)
      @item_len.delete_at(position)
      @item_pos.delete_at(position)

      set_view_size(@list_size - 1)

      if @list_size > 0
        resequence
      end

      set_position(@current_item)
    end

    def focus
      draw_current
      if lw = @list_win
        CRT::Screen.wrefresh(lw)
      end
    end

    def unfocus
      draw_current
      if lw = @list_win
        CRT::Screen.wrefresh(lw)
      end
    end

    def available_width : Int32
      @box_width - (2 * @border_size)
    end

    def update_view_width(widest : Int32)
      @max_left_char = @box_width > widest ? 0 : widest - available_width
    end

    def widest_item_width : Int32
      @max_left_char + available_width
    end

    private def resequence
      return unless @numbers
      @list_size.times do |j|
        number = @numbers ? j + 1 : 0
        value = chtype2char(@item[j]).lstrip("0123456789. ")
        alloc_list_item(j, number, value)
      end
    end
  end
end
