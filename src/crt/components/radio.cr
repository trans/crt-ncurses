module CRT
  class Radio < CRT::Scroller
    getter item : Array(Array(Int32)) = [] of Array(Int32)
    getter item_len : Array(Int32) = [] of Int32
    getter item_pos : Array(Int32) = [] of Int32
    getter highlight : Int32 = 0

    property scrollbar : Bool = false
    property scrollbar_placement : Position = Position::Right
    getter scrollbar_win : NCurses::Window? = nil
    property selected_item : Int32 = 0
    property choice_char : Int32 = 'X'.ord
    property left_box_char : Int32 = '['.ord
    property right_box_char : Int32 = ']'.ord
    getter widest_item : Int32 = 0
    getter parent : NCurses::Window? = nil
    getter toggle_pos : Int32 = 0

    @shadow : Bool = false
    @complete : Bool = false
    @return_data : Int32 = -1

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, list : Array(String),
                   splace : Position = Position::Right, title : String = "",
                   choice_char : Char = 'X', def_item : Int32 = 0,
                   highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = width
      box_height = height

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 5)
      box_width = set_title(title, box_width)

      # Set the box height
      if @title_lines > box_height
        box_height = @title_lines + {list.size, 8}.min + 2 * @border_size
      end

      # Adjust for scrollbar
      if splace.left? || splace.right?
        box_width += 1
        @scrollbar = true
      else
        @scrollbar = false
      end

      @box_width = {box_width, parent_width}.min
      @box_height = {box_height, parent_height}.min

      set_view_size(list.size)

      # Create list items
      widest = create_list(list, list.size, @box_width)
      if widest > 0
        update_view_width(widest)
      elsif list.size > 0
        return
      end

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, @box_width, @box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: @box_height, width: @box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      # Create scrollbar window
      if splace.right?
        @scrollbar_win = CRT.subwin(w, max_view_size, 1,
          screen_ypos(ypos), xpos + @box_width - @border_size - 1)
      elsif splace.left?
        @scrollbar_win = CRT.subwin(w, max_view_size, 1,
          screen_ypos(ypos), screen_xpos(xpos))
      else
        @scrollbar_win = nil
      end

      @screen = cdkscreen
      @parent = parent_window
      @scrollbar_placement = splace
      @widest_item = widest
      @left_char = 0
      @selected_item = def_item
      @highlight = highlight
      @choice_char = choice_char.ord
      @left_box_char = '['.ord
      @right_box_char = ']'.ord
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      self.current_item = 0

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width + 1,
          y: ypos + 1, x: xpos + 1)
      end

      # Key bindings
      remap_key(CRT::BACKCHAR, LibNCurses::Key::PageUp.value)
      remap_key(CRT::FORCHAR, LibNCurses::Key::PageDown.value)
      remap_key('g'.ord, LibNCurses::Key::Home.value)
      remap_key('1'.ord, LibNCurses::Key::Home.value)
      remap_key('G'.ord, LibNCurses::Key::End.value)
      remap_key('<'.ord, LibNCurses::Key::Home.value)
      remap_key('>'.ord, LibNCurses::Key::End.value)

      cdkscreen.register(object_type, self)
      register_framing
    end

    def fix_cursor_position
      scrollbar_adj = @scrollbar_placement.left? ? 1 : 0
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

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
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
        when ' '.ord
          @selected_item = @current_item
        when CRT::KEY_ESC
          set_exit_type(resolved)
          ret = -1
          @complete = true
        when CRT::KEY_TAB, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
          set_exit_type(resolved)
          ret = @selected_item
          @complete = true
        when CRT::REFRESH
          if scr = @screen
            scr.erase
            scr.refresh
          end
        end
      end

      unless @complete
        draw_list(@box)
        set_exit_type(0)
      end

      fix_cursor_position
      @return_data = ret
      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        draw_title(w)
      end

      draw_list(@box)
    end

    def draw_list(box : Bool)
      return unless w = @win

      scrollbar_adj = @scrollbar_placement.left? ? 1 : 0

      (0...@view_size).each do |j|
        k = j + @current_top
        if k < @list_size
          xpos = screen_xpos(0)
          ypos = screen_ypos(j)

          screen_pos = screenpos(k, scrollbar_adj)

          # Draw blank line
          Draw.write_blanks(w, xpos, ypos, CRT::HORIZONTAL, 0,
            @box_width - @border_size)

          # Draw the item text
          Draw.write_chtype(w,
            screen_pos >= 0 ? screen_pos : 1,
            ypos, @item[k], CRT::HORIZONTAL,
            screen_pos >= 0 ? 0 : 1 - screen_pos,
            @item_len[k])

          # Draw the selection box [ ] or [X]
          xpos += scrollbar_adj
          Draw.mvwaddch(w, ypos, xpos, @left_box_char)
          Draw.mvwaddch(w, ypos, xpos + 1,
            k == @selected_item ? @choice_char : ' '.ord)
          Draw.mvwaddch(w, ypos, xpos + 2, @right_box_char)
        end
      end

      # Highlight current item
      if @has_focus
        k = @current_item
        if k < @list_size
          screen_pos = screenpos(k, scrollbar_adj)
          ypos = screen_ypos(@current_high)

          Draw.write_chtype_attrib(w,
            screen_pos >= 0 ? screen_pos : 1 + scrollbar_adj,
            ypos, @item[k], @highlight, CRT::HORIZONTAL,
            screen_pos >= 0 ? 0 : 1 - screen_pos,
            @item_len[k])
        end
      end

      # Draw scrollbar
      if @scrollbar
        if sw = @scrollbar_win
          @toggle_pos = (@current_item * @step).floor.to_i32
          @toggle_pos = {_toggle_pos = @toggle_pos, sw.max_y - 1}.min

          Draw.draw_vline(sw, 0, 0,
            'a'.ord | LibNCurses::Attribute::AltCharSet.value.to_i32,
            sw.max_y)
          (0...@toggle_size).each do |i|
            pos = @toggle_pos + i
            break if pos >= sw.max_y
            Draw.mvwaddch(sw, pos, 0,
              ' '.ord | LibNCurses::Attribute::Reverse.value.to_i32)
          end
        end
      end

      # Box if needed
      Draw.draw_obj_box(w, self) if box

      fix_cursor_position
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
      clean_title
      CRT.delete_curses_window(@scrollbar_win)
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clear_key_bindings
      CRT::Screen.unregister(object_type, self)
    end

    def highlight=(highlight : Int32)
      @highlight = highlight
    end

    def choice_character=(character : Char)
      @choice_char = character.ord
    end

    def left_brace=(character : Char)
      @left_box_char = character.ord
    end

    def right_brace=(character : Char)
      @right_box_char = character.ord
    end

    def current_item=(item : Int32)
      set_position(item)
      @selected_item = item
    end

    def selected_item : Int32
      @selected_item
    end

    def selected_item=(item : Int32)
      @selected_item = item
    end

    def background=(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
      if sw = @scrollbar_win
        LibNCurses.wbkgd(sw, attrib.to_u32)
      end
    end

    def focus
      draw_list(@box)
    end

    def unfocus
      draw_list(@box)
    end

    def create_list(list : Array(String), list_size : Int32, box_width : Int32) : Int32
      widest_item = 0
      return 0 if list_size < 0

      new_list = [] of Array(Int32)
      new_len = [] of Int32
      new_pos = [] of Int32

      adjusted_width = box_width - 2 - @border_size
      list_size.times do |j|
        lentmp = [] of Int32
        postmp = [] of Int32
        new_list << char2chtype(list[j], lentmp, postmp)
        new_len << lentmp[0]
        new_pos << postmp[0]
        new_pos[j] = justify_string(adjusted_width, new_len[j], new_pos[j]) + 3
        widest_item = {widest_item, new_len[j]}.max
      end

      @item = new_list
      @item_len = new_len
      @item_pos = new_pos

      widest_item
    end

    # Available width accounts for the [X] selection box
    def available_width : Int32
      @box_width - 2 * @border_size - 3
    end

    def update_view_width(widest : Int32)
      @max_left_char = @box_width > widest ? 0 : widest - available_width
    end

    def widest_item_width : Int32
      @max_left_char + available_width
    end

    def screenpos(n : Int32, scrollbar_adj : Int32) : Int32
      @item_pos[n] - @left_char + scrollbar_adj + @border_size
    end

    def object_type : Symbol
      :RADIO
    end
  end
end
