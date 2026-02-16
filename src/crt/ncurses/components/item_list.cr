module CRT
  class ItemList < CRT::CRTObjs
    getter item : Array(Array(Int32)) = [] of Array(Int32)
    getter item_len : Array(Int32) = [] of Int32
    getter item_pos : Array(Int32) = [] of Int32

    getter current_item : Int32 = 0
    getter default_item : Int32 = 0
    getter list_size : Int32 = 0
    getter field_width : Int32 = 0
    getter parent : NCurses::Window? = nil

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @label : Array(Int32) = [] of Int32
    @label_len : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   items : Array(String), title : String = "", label : String = "",
                   default_item : Int32 = 0, box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      return unless create_list(items, items.size)

      set_box(box)
      box_height = @border_size * 2 + 1

      # Translate label
      @label = [] of Int32
      @label_len = 0
      @label_win = nil

      if !label.empty?
        @label, @label_len, _ = char2chtype(label)
      end

      # Set box width - allow extra char in field for cursor
      field_width = maximum_field_width + 1
      box_width = field_width + @label_len + 2 * @border_size
      box_width = set_title(title, box_width)
      box_height += @title_lines

      @box_width = {box_width, parent_width}.min
      @box_height = {box_height, parent_height}.min
      update_field_width

      # Align positions
      xpos, ypos = alignxy(parent_window, x, y, @box_width, @box_height)

      # Create main window
      @win = NCurses::Window.new(height: @box_height, width: @box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Create label window
      if @label.size > 0
        @label_win = CRT.subwin(w, 1, @label_len,
          ypos + @border_size + @title_lines,
          xpos + @border_size)
      end

      # Create field window
      create_field_win(
        ypos + @border_size + @title_lines,
        xpos + @label_len + @border_size)

      @screen = screen
      @parent = parent_window
      @shadow_win = nil
      @accepts_focus = true
      @shadow = shadow

      # Set default item
      if default_item >= 0 && default_item < @list_size
        @current_item = default_item
        @default_item = default_item
      else
        @current_item = 0
        @default_item = 0
      end

      if shadow
        @shadow_win = NCurses::Window.new(height: @box_height, width: @box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      ret = -1
      draw(@box)
      draw_field(true)

      if actions.nil? || actions.empty?
        loop do
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
      ret
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw_field(true)

      case input
      when LibNCurses::Key::Up.value, LibNCurses::Key::Right.value, ' '.ord, '+'.ord, 'n'.ord
        if @current_item < @list_size - 1
          @current_item += 1
        else
          @current_item = 0
        end
      when LibNCurses::Key::Down.value, LibNCurses::Key::Left.value, '-'.ord, 'p'.ord
        if @current_item > 0
          @current_item -= 1
        else
          @current_item = @list_size - 1
        end
      when 'd'.ord, 'D'.ord
        @current_item = @default_item
      when '0'.ord
        @current_item = 0
      when '$'.ord
        @current_item = @list_size - 1
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        set_exit_type(input)
        ret = @current_item
        @complete = true
      when CRT::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      else
        CRT.beep
      end

      unless @complete
        draw_field(true)
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        draw_title(w)

        if lw = @label_win
          Draw.write_chtype(lw, 0, 0, @label, CRT::HORIZONTAL, 0, @label.size)
          CRT::Screen.wrefresh(lw)
        end

        Draw.draw_obj_box(w, self) if box
        wrefresh
      end

      draw_field(false)
    end

    def draw_field(highlight : Bool)
      return unless fw = @field_win

      current = @current_item
      len = {@item_len[current], @field_width}.min

      fw.erase

      # Draw current item in field
      (0...len).each do |x|
        break if x >= @item[current].size
        c = @item[current][x]
        c = c | LibNCurses::Attribute::Reverse.value.to_i32 if highlight
        Draw.mvwaddch(fw, 0, x + @item_pos[current], c)
      end

      CRT::Screen.wrefresh(fw)
    end

    def erase
      CRT.erase_curses_window(@field_win)
      CRT.erase_curses_window(@label_win)
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
      clean_title
      @list_size = 0
      @item = [] of Array(Int32)
      CRT.delete_curses_window(@field_win)
      CRT.delete_curses_window(@label_win)
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clear_key_bindings
      CRT::Screen.unregister(object_type, self)
    end

    def current_item=(current_item : Int32)
      if current_item >= 0 && current_item < @list_size
        @current_item = current_item
      end
    end

    def default_item=(default_item : Int32)
      if default_item < 0
        @default_item = 0
      elsif default_item >= @list_size
        @default_item = @list_size - 1
      else
        @default_item = default_item
      end
    end

    def background=(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
      if fw = @field_win
        LibNCurses.wbkgd(fw, attrib.to_u32)
      end
      if lw = @label_win
        LibNCurses.wbkgd(lw, attrib.to_u32)
      end
    end

    def focus
      draw_field(true)
    end

    def unfocus
      draw_field(false)
    end

    def object_type : Symbol
      :ITEM_LIST
    end

    def create_list(items : Array(String), count : Int32) : Bool
      return true if count < 0

      new_items = [] of Array(Int32)
      new_pos = [] of Int32
      new_len = [] of Int32
      field_width = 0

      count.times do |x|
        chtype, len, pos = char2chtype(items[x])
        new_items << chtype
        new_len << len
        new_pos << pos
        field_width = {field_width, new_len[x]}.max
      end

      # Justify strings
      count.times do |x|
        new_pos[x] = justify_string(field_width + 1, new_len[x], new_pos[x])
      end

      @list_size = count
      @item = new_items
      @item_pos = new_pos
      @item_len = new_len

      true
    end

    def maximum_field_width : Int32
      max_width = 0
      @list_size.times do |x|
        max_width = {max_width, @item_len[x]}.max
      end
      max_width
    end

    def update_field_width
      want = maximum_field_width + 1
      have = @box_width - @label_len - 2 * @border_size
      @field_width = {want, have}.min
    end

    def create_field_win(ypos : Int32, xpos : Int32) : Bool
      return false unless w = @win
      @field_win = CRT.subwin(w, 1, @field_width, ypos, xpos)
      if fw = @field_win
        fw.keypad(true)
        @input_window = fw
        true
      else
        false
      end
    end
  end
end
