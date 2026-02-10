module CDK
  class Buttonbox < CDK::CDKObjs
    getter current_button : Int32 = 0
    property button_count : Int32 = 0
    property rows : Int32 = 0
    property cols : Int32 = 0
    property highlight : Int32 = 0
    property parent : NCurses::Window? = nil

    @button : Array(Array(Int32)) = [] of Array(Int32)
    @button_len : Array(Int32) = [] of Int32
    @button_pos : Array(Int32) = [] of Int32
    @column_widths : Array(Int32) = [] of Int32
    @row_adjust : Int32 = 0
    @col_adjust : Int32 = 0
    @button_attrib : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1

    def initialize(cdkscreen : CDK::Screen, xplace : Int32, yplace : Int32,
                   height : Int32, width : Int32, title : String,
                   rows : Int32, cols : Int32,
                   buttons : Array(String), button_count : Int32,
                   highlight : Int32, box : Bool, shadow : Bool)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      col_width = 0
      current_button = 0

      @button = [] of Array(Int32)
      @button_len = [] of Int32
      @button_pos = [] of Int32
      @column_widths = [] of Int32

      return if button_count <= 0

      set_box(box)

      @row_adjust = 0
      @col_adjust = 0

      box_height = CDK.set_widget_dimension(parent_height, height, rows + 1)
      box_width = CDK.set_widget_dimension(parent_width, width, 0)
      box_width = set_title(title, box_width)

      # Translate buttons to chtype arrays
      button_count.times do |x|
        button_len = [] of Int32
        @button << char2chtype(buttons[x], button_len, [] of Int32)
        @button_len << button_len[0]
      end

      # Set button positions and column widths
      cols.times do |x|
        max_col_width = 0
        rows.times do |y|
          if current_button < button_count
            max_col_width = {max_col_width, @button_len[current_button]}.max
            current_button += 1
          end
        end
        @column_widths << max_col_width
        col_width += max_col_width
      end
      box_width += 1

      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      xtmp = [xplace]
      ytmp = [yplace]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @screen = cdkscreen
      @parent = parent_window
      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @shadow_win = nil
      @button_count = button_count
      @current_button = 0
      @rows = rows
      @cols = {button_count, cols}.min
      @box_height = box_height
      @box_width = box_width
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @shadow = shadow
      @button_attrib = 0

      # Row adjustment
      if box_height - rows - @title_lines > 0
        @row_adjust = (box_height - rows - @title_lines) // @rows
      end

      # Col adjustment
      if box_width - col_width > 0
        @col_adjust = (box_width - col_width) // @cols - 1
      end

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      cdkscreen.register(:BUTTONBOX, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          input = getch([] of Bool)
          ret = inject(input)
          return ret if @exit_type != CDK::ExitType::EARLY_EXIT
        end
      else
        actions.each do |action|
          ret = inject(action)
          return ret if @exit_type != CDK::ExitType::EARLY_EXIT
        end
      end

      set_exit_type(0)
      -1
    end

    def inject(input : Int32) : Int32
      first_button = 0
      last_button = @button_count - 1
      ret = -1
      @complete = false

      set_exit_type(0)

      case input
      when LibNCurses::Key::Left.value, LibNCurses::Key::Backspace.value
        if @current_button - @rows < first_button
          @current_button = last_button
        else
          @current_button -= @rows
        end
      when LibNCurses::Key::Right.value, CDK::KEY_TAB, ' '.ord
        if @current_button + @rows > last_button
          @current_button = first_button
        else
          @current_button += @rows
        end
      when LibNCurses::Key::Up.value
        if @current_button - 1 < first_button
          @current_button = last_button
        else
          @current_button -= 1
        end
      when LibNCurses::Key::Down.value
        if @current_button + 1 > last_button
          @current_button = first_button
        else
          @current_button += 1
        end
      when CDK::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      when CDK::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CDK::KEY_RETURN, LibNCurses::Key::Enter.value
        set_exit_type(input)
        ret = @current_button
        @complete = true
      end

      unless @complete
        draw_buttons
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def draw(box : Bool)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)
      end

      draw_buttons
    end

    def draw_buttons
      return unless w = @win

      row = @title_lines + @border_size
      col = @col_adjust // 2
      current_button = 0
      cur_row = -1
      cur_col = -1

      while current_button < @button_count
        @cols.times do |x|
          row = @title_lines + @border_size

          @rows.times do |y|
            break if current_button >= @button_count
            attr = if current_button == @current_button
                     cur_row = row
                     cur_col = col
                     @highlight
                   else
                     @button_attrib
                   end
            Draw.write_chtype_attrib(w, col, row,
              @button[current_button], attr, CDK::HORIZONTAL, 0,
              @button_len[current_button])
            row += 1 + @row_adjust
            current_button += 1
          end
          col += @column_widths[x] + @col_adjust + @border_size
        end
      end

      if cur_row >= 0 && cur_col >= 0
        w.move(cur_row, cur_col)
      end
      wrefresh
    end

    def erase
      CDK.erase_curses_window(@win)
      CDK.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CDK.delete_curses_window(@shadow_win)
      CDK.delete_curses_window(@win)
      clean_bindings(:BUTTONBOX)
      CDK::Screen.unregister(:BUTTONBOX, self)
    end

    def set_current_button(button : Int32)
      if button >= 0 && button < @button_count
        @current_button = button
      end
    end

    def get_current_button : Int32
      @current_button
    end

    def get_button_count : Int32
      @button_count
    end

    def set_highlight(highlight : Int32)
      @highlight = highlight
    end

    def get_highlight : Int32
      @highlight
    end

    def set_bk_attr(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
    end

    def focus
      draw(@box)
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :BUTTONBOX
    end
  end
end
