module CRT
  class Matrix < CRT::CRTObjs
    MAX_MATRIX_ROWS = 1000
    MAX_MATRIX_COLS = 1000

    getter info : Array(Array(String))
    getter row : Int32 = 1
    getter col : Int32 = 1
    getter crow : Int32 = 1
    getter ccol : Int32 = 1
    getter colwidths : Array(Int32)
    getter colvalues : Array(CRT::DisplayType)
    getter filler : Int32 = '.'.ord

    @cell : Array(Array(NCurses::Window?))
    @rows : Int32 = 0
    @cols : Int32 = 0
    @vrows : Int32 = 0
    @vcols : Int32 = 0
    @coltitle : Array(Array(Int32)) = [] of Array(Int32)
    @coltitle_len : Array(Int32) = [] of Int32
    @coltitle_pos : Array(Int32) = [] of Int32
    @rowtitle : Array(Array(Int32)) = [] of Array(Int32)
    @rowtitle_len : Array(Int32) = [] of Int32
    @rowtitle_pos : Array(Int32) = [] of Int32
    @maxrt : Int32 = 0
    @trow : Int32 = 1
    @lcol : Int32 = 1
    @oldcrow : Int32 = 1
    @oldccol : Int32 = 1
    @oldvrow : Int32 = 1
    @oldvcol : Int32 = 1
    @row_space : Int32 = 0
    @col_space : Int32 = 0
    @dominant : Dominant = Dominant::None
    @box_cell : Bool = false
    @highlight : Int32 = 0
    @shadow : Bool = false
    @parent : NCurses::Window? = nil
    @complete : Bool = false

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   rows : Int32, cols : Int32, vrows : Int32, vcols : Int32,
                   rowtitles : Array(String), coltitles : Array(String),
                   colwidths : Array(Int32), colvalues : Array(CRT::DisplayType),
                   title : String = "", rspace : Int32 = 1, cspace : Int32 = 1,
                   filler : Char = '.', dominant : Dominant = Dominant::None, box : Bool | CRT::Framing | Nil = nil,
                   box_cell : Bool = true, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      max_row_title_width = 0
      row_space = {0, rspace}.max
      col_space = {0, cspace}.max
      have_rowtitles = false
      have_coltitles = false

      set_box(box)
      borderw = @box ? 1 : 0

      return if rows <= 0 || cols <= 0 || vrows <= 0 || vcols <= 0

      vrows = {vrows, rows}.min
      vcols = {vcols, cols}.min

      @rows = rows
      @cols = cols
      @info = Array(Array(String)).new(rows + 1) { Array(String).new(cols + 1, "") }
      @cell = Array(Array(NCurses::Window?)).new(rows + 1) { Array(NCurses::Window?).new(cols + 1, nil) }
      @colwidths = Array(Int32).new(cols + 1, 0)
      @colvalues = Array(CRT::DisplayType).new(cols + 1, CRT::DisplayType::MIXED)
      @coltitle = Array(Array(Int32)).new(cols + 1) { [] of Int32 }
      @coltitle_len = Array(Int32).new(cols + 1, 0)
      @coltitle_pos = Array(Int32).new(cols + 1, 0)
      @rowtitle = Array(Array(Int32)).new(rows + 1) { [] of Int32 }
      @rowtitle_len = Array(Int32).new(rows + 1, 0)
      @rowtitle_pos = Array(Int32).new(rows + 1, 0)

      # Determine box height
      box_height = if vrows == 1
                     6 + @title_lines
                   elsif row_space == 0
                     6 + @title_lines + (vrows - 1) * 2
                   else
                     3 + @title_lines + vrows * 3 + (vrows - 1) * (row_space - 1)
                   end

      # Process row titles
      (1..rows).each do |x|
        rt = x < rowtitles.size ? rowtitles[x] : ""
        have_rowtitles = true if !rt.empty?
        rt_len = [] of Int32
        rt_pos = [] of Int32
        @rowtitle[x] = char2chtype(rt, rt_len, rt_pos)
        @rowtitle_len[x] = rt_len[0]
        @rowtitle_pos[x] = rt_pos[0]
        max_row_title_width = {max_row_title_width, @rowtitle_len[x]}.max
      end

      if have_rowtitles
        @maxrt = max_row_title_width + 2
        (1..rows).each do |x|
          @rowtitle_pos[x] = justify_string(@maxrt, @rowtitle_len[x], @rowtitle_pos[x])
        end
      end

      # Determine box width
      max_width = 2 + @maxrt
      (1..vcols).each do |x|
        cw = x < colwidths.size ? colwidths[x] : 1
        max_width += cw + 2 + col_space
      end
      max_width -= (col_space - 1)
      box_width = max_width
      box_width = set_title(title, box_width)

      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      begx = xpos
      begy = ypos + borderw + @title_lines

      # Make the 0,0 cell (row title header)
      if @maxrt > 0
        @cell[0][0] = CRT.subwin(w, 3, @maxrt, begy, begx)
      end

      begx += @maxrt + 1

      # Process column titles
      (1..cols).each do |x|
        ct = x < coltitles.size ? coltitles[x] : ""
        have_coltitles = true if !ct.empty?
        ct_len = [] of Int32
        ct_pos = [] of Int32
        @coltitle[x] = char2chtype(ct, ct_len, ct_pos)
        @coltitle_len[x] = ct_len[0]
        cw = x < colwidths.size ? colwidths[x] : 1
        @coltitle_pos[x] = @border_size + justify_string(cw, @coltitle_len[x], ct_pos[0])
        @colwidths[x] = cw
      end

      if have_coltitles
        (1..vcols).each do |x|
          cw = @colwidths[x]
          cell_width = cw + 3
          @cell[0][x] = CRT.subwin(w, borderw, cell_width, begy, begx)
          return if @cell[0][x].nil?
          begx += cell_width + col_space - 1
        end
        begy += 1
      end

      # Make main cell body
      (1..vrows).each do |x|
        if have_rowtitles
          @cell[x][0] = CRT.subwin(w, 3, @maxrt, begy, xpos + borderw)
          return if @cell[x][0].nil?
        end

        begx = xpos + @maxrt + borderw

        (1..vcols).each do |y|
          cell_width = @colwidths[y] + 3
          @cell[x][y] = CRT.subwin(w, 3, cell_width, begy, begx)
          return if @cell[x][y].nil?
          if cw = @cell[x][y]
            cw.keypad(true)
          end
          begx += cell_width + col_space - 1
        end
        begy += row_space + 2
      end

      @screen = screen
      @accepts_focus = true
      @input_window = @win
      @parent = parent_window
      @vrows = vrows
      @vcols = vcols
      @box_width = box_width
      @box_height = box_height
      @row_space = row_space
      @col_space = col_space
      @filler = filler.ord
      @dominant = dominant
      @box_cell = box_cell
      @shadow = shadow
      @highlight = LibNCurses::Attribute::Reverse.value.to_i32

      # Copy colwidths and colvalues
      (1..cols).each do |y|
        @colvalues[y] = y < colvalues.size ? colvalues[y] : CRT::DisplayType::MIXED
        @colwidths[y] = y < colwidths.size ? colwidths[y] : 1
      end

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      remap_key(CRT::FORCHAR, LibNCurses::Key::PageDown.value)
      remap_key(CRT::BACKCHAR, LibNCurses::Key::PageUp.value)

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          if cell = cur_matrix_cell
            @input_window = cell
            cell.keypad(true)
          end
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
      refresh_cells = false
      moved_cell = false
      ret = -1
      @complete = false

      set_exit_type(0)

      # Position cursor in current cell
      if cell = cur_matrix_cell
        charcount = @info[@row][@col].size
        if @colwidths[@ccol] == 1
          LibNCurses.wmove(cell, 1, 1)
        else
          LibNCurses.wmove(cell, 1, charcount + 1)
        end
      end

      focus_current

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
        when LibNCurses::Key::Backspace.value, LibNCurses::Key::Delete.value
          if @colvalues[@col].viewonly? || @info[@row][@col].size <= 0
            CRT.beep
          else
            charcount = @info[@row][@col].size - 1
            if cell = cur_matrix_cell
              LibNCurses.mvwdelch(cell, 1, charcount + 1)
              LibNCurses.mvwinsch(cell, 1, charcount + 1, @filler.to_u8.unsafe_chr.ord.to_i8)
              CRT::Screen.wrefresh(cell)
            end
            @info[@row][@col] = @info[@row][@col][0...charcount]
          end
        when LibNCurses::Key::Right.value, CRT::KEY_TAB
          if @ccol != @vcols
            @col += 1
            @ccol += 1
            moved_cell = true
          elsif @col != @cols
            @lcol += 1
            @col += 1
            if @rows > @vrows
              redraw_titles(false, true)
            end
            refresh_cells = true
            moved_cell = true
          else
            if @row == @rows
              CRT.beep
            else
              @col = 1; @lcol = 1; @ccol = 1
              if @crow != @vrows
                @row += 1; @crow += 1
              else
                @row += 1; @trow += 1
              end
              redraw_titles(true, true)
              refresh_cells = true
              moved_cell = true
            end
          end
        when LibNCurses::Key::Left.value
          if @ccol != 1
            @col -= 1; @ccol -= 1
            moved_cell = true
          elsif @lcol != 1
            @lcol -= 1; @col -= 1
            if @cols > @vcols
              redraw_titles(false, true)
            end
            refresh_cells = true
            moved_cell = true
          else
            if @row == 1
              CRT.beep
            else
              @col = @cols; @lcol = @cols - @vcols + 1; @ccol = @vcols
              if @crow != 1
                @row -= 1; @crow -= 1
              else
                @row -= 1; @trow -= 1
              end
              redraw_titles(true, true)
              refresh_cells = true
              moved_cell = true
            end
          end
        when LibNCurses::Key::Up.value
          if @crow != 1
            @row -= 1; @crow -= 1
            moved_cell = true
          elsif @trow != 1
            @trow -= 1; @row -= 1
            if @rows > @vrows
              redraw_titles(true, false)
            end
            refresh_cells = true
            moved_cell = true
          else
            CRT.beep
          end
        when LibNCurses::Key::Down.value
          if @crow != @vrows
            @row += 1; @crow += 1
            moved_cell = true
          elsif @trow + @vrows - 1 != @rows
            @trow += 1; @row += 1
            if @rows > @vrows
              redraw_titles(true, false)
            end
            refresh_cells = true
            moved_cell = true
          else
            CRT.beep
          end
        when LibNCurses::Key::PageDown.value
          if @rows > @vrows && @trow + (@vrows - 1) * 2 <= @rows
            @trow += @vrows - 1
            @row += @vrows - 1
            redraw_titles(true, false)
            refresh_cells = true
            moved_cell = true
          else
            CRT.beep
          end
        when LibNCurses::Key::PageUp.value
          if @rows > @vrows && @trow - (@vrows - 1) >= 1
            @trow -= @vrows - 1
            @row -= @vrows - 1
            redraw_titles(true, false)
            refresh_cells = true
            moved_cell = true
          else
            CRT.beep
          end
        when CRT::PASTE
          buf = CRT::CRTObjs.paste_buffer
          if buf.empty? || buf.size > @colwidths[@ccol]
            CRT.beep
          else
            @info[@row][@col] = buf
            draw_cur_cell
          end
        when CRT::COPY
          CRT::CRTObjs.paste_buffer = @info[@row][@col]
        when CRT::CUT
          CRT::CRTObjs.paste_buffer = @info[@row][@col]
          clean_cell(@row, @col)
          draw_cur_cell
        when CRT::ERASE
          clean_cell(@row, @col)
          draw_cur_cell
        when LibNCurses::Key::Enter.value, CRT::KEY_RETURN
          if !@box_cell && (old_cell = @cell[@oldcrow][@oldccol])
            Draw.attrbox(old_cell, ' '.ord, ' '.ord, ' '.ord, ' '.ord,
              ' '.ord, ' '.ord, 0)
          else
            draw_old_cell
          end
          set_exit_type(resolved)
          ret = 1
          @complete = true
        when CRT::KEY_ESC
          if !@box_cell && (old_cell = @cell[@oldcrow][@oldccol])
            Draw.attrbox(old_cell, ' '.ord, ' '.ord, ' '.ord, ' '.ord,
              ' '.ord, ' '.ord, 0)
          else
            draw_old_cell
          end
          set_exit_type(resolved)
          @complete = true
        when CRT::REFRESH
          if scr = @screen
            scr.erase
            scr.refresh
          end
        else
          # Character input callback
          plainchar = CRT::Display.filter_by_display_type(@colvalues[@col], input)
          charcount = @info[@row][@col].size

          if plainchar == -1
            CRT.beep
          elsif charcount >= @colwidths[@col]
            CRT.beep
          else
            if cell = cur_matrix_cell
              ch = if CRT::Display.hidden_display_type?(@colvalues[@col])
                     @filler
                   else
                     plainchar
                   end
              LibNCurses.wmove(cell, 1, charcount + 1)
              LibNCurses.waddch(cell, ch.to_u8.unsafe_chr.ord.to_i8)
              CRT::Screen.wrefresh(cell)
            end
            @info[@row][@col] += plainchar.unsafe_chr
          end
        end
      end

      if !@complete
        if moved_cell
          if !@box_cell && (old_cell = @cell[@oldcrow][@oldccol])
            Draw.attrbox(old_cell, ' '.ord, ' '.ord, ' '.ord, ' '.ord,
              ' '.ord, ' '.ord, 0)
            CRT::Screen.wrefresh(old_cell)
          else
            draw_old_cell
          end
          focus_current
        end

        if refresh_cells
          draw_each_cell
          focus_current
        end

        if refresh_cells || moved_cell
          if cell = cur_matrix_cell
            if @colwidths[@ccol] == 1
              LibNCurses.wmove(cell, 1, 1)
            else
              LibNCurses.wmove(cell, 1, @info[@row][@col].size + 1)
            end
            CRT::Screen.wrefresh(cell)
          end
        end
      end

      if !@complete
        @oldcrow = @crow
        @oldccol = @ccol
        @oldvrow = @row
        @oldvcol = @col
        set_exit_type(0)
      end

      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)
        wrefresh
      end

      draw_each_col_title
      draw_each_row_title
      draw_each_cell
      focus_current
    end

    def set_cell(row : Int32, col : Int32, value : String) : Int32
      return -1 if row > @rows || col > @cols || row <= 0 || col <= 0
      clean_cell(row, col)
      @info[row][col] = value[0...{@colwidths[col], value.size}.min]
      1
    end

    def get_cell(row : Int32, col : Int32) : String
      return "" if row > @rows || col > @cols || row <= 0 || col <= 0
      @info[row][col]
    end

    def clean
      (1..@rows).each do |x|
        (1..@cols).each do |y|
          clean_cell(x, y)
        end
      end
    end

    def clean_cell(row : Int32, col : Int32)
      if row > 0 && row <= @rows && col > 0 && col <= @cols
        @info[row][col] = ""
      end
    end

    def move_to_cell(newrow : Int32, newcol : Int32) : Int32
      return 0 if newrow > @rows || newcol > @cols || newrow <= 0 || newcol <= 0

      row_shift = newrow - @row
      col_shift = newcol - @col

      # Handle row movement
      if row_shift > 0
        if @vrows == @rows
          @trow = 1; @crow = newrow; @row = newrow
        elsif row_shift + @vrows < @rows
          @trow += row_shift; @crow = 1; @row += row_shift
        else
          @trow = @rows - @vrows + 1
          @crow = row_shift + @vrows - @rows + 1
          @row = newrow
        end
      elsif row_shift < 0
        if @vrows == @rows
          @trow = 1; @row = newrow; @crow = newrow
        elsif row_shift + @vrows > 1
          @trow += row_shift; @row += row_shift; @crow = 1
        else
          @trow = 1; @crow = 1; @row = 1
        end
      end

      # Handle column movement
      if col_shift > 0
        if @vcols == @cols
          @lcol = 1; @ccol = newcol; @col = newcol
        elsif col_shift + @vcols < @cols
          @lcol += col_shift; @ccol = 1; @col += col_shift
        else
          @lcol = @cols - @vcols + 1
          @ccol = col_shift + @vcols - @cols + 1
          @col = newcol
        end
      elsif col_shift < 0
        if @vcols == @cols
          @lcol = 1; @col = newcol; @ccol = newcol
        elsif col_shift + @vcols > 1
          @lcol += col_shift; @col += col_shift; @ccol = 1
        else
          @lcol = 1; @col = 1; @ccol = 1
        end
      end

      @oldcrow = @crow; @oldccol = @ccol
      @oldvrow = @row; @oldvcol = @col
      1
    end

    def erase
      CRT.erase_curses_window(@cell[0][0]) if @maxrt > 0
      (1..@vrows).each { |x| CRT.erase_curses_window(@cell[x][0]) }
      (1..@vcols).each { |x| CRT.erase_curses_window(@cell[0][x]) }
      (1..@vrows).each do |x|
        (1..@vcols).each { |y| CRT.erase_curses_window(@cell[x][y]) }
      end
      CRT.erase_curses_window(@shadow_win)
      CRT.erase_curses_window(@win)
    end

    def destroy
      unregister_framing
      clean_title
      CRT.delete_curses_window(@cell[0][0]) if @maxrt > 0
      (1..@vrows).each { |x| CRT.delete_curses_window(@cell[x][0]) }
      (1..@vcols).each { |x| CRT.delete_curses_window(@cell[0][x]) }
      (1..@vrows).each do |x|
        (1..@vcols).each { |y| CRT.delete_curses_window(@cell[x][y]) }
      end
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clear_key_bindings
      CRT::Screen.unregister(object_type, self)
    end

    def background=(attrib : Int32)
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
      :MATRIX
    end

    def cur_matrix_cell : NCurses::Window?
      @cell[@crow][@ccol]
    end

    private def highlight_cell
      return unless cell = cur_matrix_cell
      infolen = @info[@row][@col].size
      hl = @highlight

      if @dominant.row?
        hl = (@rowtitle[@crow][0]? || 0) & 0xFFFFFF00_u32.to_i32
      elsif @dominant.col?
        hl = (@coltitle[@ccol][0]? || 0) & 0xFFFFFF00_u32.to_i32
      end

      (1..@colwidths[@ccol]).each do |x|
        ch = if x <= infolen && !CRT::Display.hidden_display_type?(@colvalues[@col])
               @info[@row][@col][x - 1].ord
             else
               @filler & 0xFF
             end
        Draw.mvwaddch(cell, 1, x, ch | hl)
      end
      LibNCurses.wmove(cell, 1, infolen + 1)
      CRT::Screen.wrefresh(cell)
    end

    private def focus_current
      return unless cell = cur_matrix_cell
      Draw.attrbox(cell, Draw::ACS_ULCORNER, Draw::ACS_URCORNER,
        Draw::ACS_LLCORNER, Draw::ACS_LRCORNER,
        Draw::ACS_HLINE, Draw::ACS_VLINE,
        LibNCurses::Attribute::Bold.value.to_i32)
      CRT::Screen.wrefresh(cell)
      highlight_cell
    end

    private def draw_cell(row : Int32, col : Int32, vrow : Int32, vcol : Int32,
                          attr : Int32, box_it : Bool)
      return unless cell = @cell[row][col]
      infolen = @info[vrow][vcol].size
      hl = @filler & 0xFFFFFF00_u32.to_i32

      if @dominant.row?
        hl = (@rowtitle[row][0]? || 0) & 0xFFFFFF00_u32.to_i32
      elsif @dominant.col?
        hl = (@coltitle[col][0]? || 0) & 0xFFFFFF00_u32.to_i32
      end

      (1..@colwidths[col]).each do |x|
        ch = if x <= infolen && !CRT::Display.hidden_display_type?(@colvalues[@col])
               @info[vrow][vcol][x - 1].ord | hl
             else
               @filler
             end
        Draw.mvwaddch(cell, 1, x, ch)
      end

      LibNCurses.wmove(cell, 1, infolen + 1)
      CRT::Screen.wrefresh(cell)

      return unless box_it
      draw_cell_box(row, col, @vrows, @vcols, attr)
    end

    private def draw_cell_box(row : Int32, col : Int32, rows : Int32, cols : Int32, attr : Int32)
      return unless cell = @cell[row][col]

      if @col_space != 0 && @row_space != 0
        Draw.attrbox(cell, Draw::ACS_ULCORNER, Draw::ACS_URCORNER,
          Draw::ACS_LLCORNER, Draw::ACS_LRCORNER,
          Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
      elsif @col_space != 0
        if row == 1
          Draw.attrbox(cell, Draw::ACS_ULCORNER, Draw::ACS_URCORNER,
            Draw::ACS_LTEE, Draw::ACS_RTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        elsif row < rows
          Draw.attrbox(cell, Draw::ACS_LTEE, Draw::ACS_RTEE,
            Draw::ACS_LTEE, Draw::ACS_RTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        else
          Draw.attrbox(cell, Draw::ACS_LTEE, Draw::ACS_RTEE,
            Draw::ACS_LLCORNER, Draw::ACS_LRCORNER, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        end
      elsif @row_space != 0
        if col == 1
          Draw.attrbox(cell, Draw::ACS_ULCORNER, Draw::ACS_TTEE,
            Draw::ACS_LLCORNER, Draw::ACS_BTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        elsif col < cols
          Draw.attrbox(cell, Draw::ACS_TTEE, Draw::ACS_TTEE,
            Draw::ACS_BTEE, Draw::ACS_BTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        else
          Draw.attrbox(cell, Draw::ACS_TTEE, Draw::ACS_URCORNER,
            Draw::ACS_BTEE, Draw::ACS_LRCORNER, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
        end
      else
        # Grid mode: cells share borders
        if row == 1
          if col == 1
            Draw.attrbox(cell, Draw::ACS_ULCORNER, Draw::ACS_TTEE,
              Draw::ACS_LTEE, Draw::ACS_PLUS, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          elsif col < cols
            Draw.attrbox(cell, Draw::ACS_TTEE, Draw::ACS_TTEE,
              Draw::ACS_PLUS, Draw::ACS_PLUS, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          else
            Draw.attrbox(cell, Draw::ACS_TTEE, Draw::ACS_URCORNER,
              Draw::ACS_PLUS, Draw::ACS_RTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          end
        elsif row < rows
          if col == 1
            Draw.attrbox(cell, Draw::ACS_LTEE, Draw::ACS_PLUS,
              Draw::ACS_LTEE, Draw::ACS_PLUS, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          elsif col < cols
            Draw.attrbox(cell, Draw::ACS_PLUS, Draw::ACS_PLUS,
              Draw::ACS_PLUS, Draw::ACS_PLUS, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          else
            Draw.attrbox(cell, Draw::ACS_PLUS, Draw::ACS_RTEE,
              Draw::ACS_PLUS, Draw::ACS_RTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          end
        else
          if col == 1
            Draw.attrbox(cell, Draw::ACS_LTEE, Draw::ACS_PLUS,
              Draw::ACS_LLCORNER, Draw::ACS_BTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          elsif col < cols
            Draw.attrbox(cell, Draw::ACS_PLUS, Draw::ACS_PLUS,
              Draw::ACS_BTEE, Draw::ACS_BTEE, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          else
            Draw.attrbox(cell, Draw::ACS_PLUS, Draw::ACS_RTEE,
              Draw::ACS_BTEE, Draw::ACS_LRCORNER, Draw::ACS_HLINE, Draw::ACS_VLINE, attr)
          end
        end
      end

      focus_current
    end

    private def draw_each_col_title
      (1..@vcols).each do |x|
        if cell = @cell[0][x]
          cell.erase
          Draw.write_chtype(cell,
            @coltitle_pos[@lcol + x - 1], 0,
            @coltitle[@lcol + x - 1], CRT::HORIZONTAL, 0,
            @coltitle_len[@lcol + x - 1])
          CRT::Screen.wrefresh(cell)
        end
      end
    end

    private def draw_each_row_title
      (1..@vrows).each do |x|
        if cell = @cell[x][0]
          cell.erase
          Draw.write_chtype(cell,
            @rowtitle_pos[@trow + x - 1], 1,
            @rowtitle[@trow + x - 1], CRT::HORIZONTAL, 0,
            @rowtitle_len[@trow + x - 1])
          CRT::Screen.wrefresh(cell)
        end
      end
    end

    private def draw_each_cell
      (1..@vrows).each do |x|
        (1..@vcols).each do |y|
          draw_cell(x, y, @trow + x - 1, @lcol + y - 1, 0, @box_cell)
        end
      end
    end

    private def draw_cur_cell
      draw_cell(@crow, @ccol, @row, @col, 0, @box_cell)
    end

    private def draw_old_cell
      draw_cell(@oldcrow, @oldccol, @oldvrow, @oldvcol, 0, @box_cell)
    end

    private def redraw_titles(row_titles : Bool, col_titles : Bool)
      draw_each_row_title if row_titles
      draw_each_col_title if col_titles
    end
  end
end
