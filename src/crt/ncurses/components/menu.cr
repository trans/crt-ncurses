module CRT::Ncurses
  class Menu < CRT::Ncurses::CRTObjs
    TITLELINES     = 1
    MAX_MENU_ITEMS = 30
    MAX_SUB_ITEMS  = 98

    getter current_title : Int32 = 0
    getter current_subtitle : Int32 = 0

    @pull_win : Array(NCurses::Window?) = [] of NCurses::Window?
    @title_win : Array(NCurses::Window?) = [] of NCurses::Window?
    @menu_title : Array(Array(Int32)) = [] of Array(Int32)
    @menu_title_len : Array(Int32) = [] of Int32
    @sublist : Array(Array(Array(Int32))) = [] of Array(Array(Int32))
    @sublist_len : Array(Array(Int32)) = [] of Array(Int32)
    @subsize : Array(Int32) = [] of Int32
    @menu_items : Int32 = 0
    @title_attr : Int32 = 0
    @subtitle_attr : Int32 = 0
    @last_selection : Int32 = -1
    @menu_pos : Position = Position::Top
    @parent : NCurses::Window? = nil
    @complete : Bool = false

    def initialize(screen : CRT::Ncurses::Screen, *, menu_list : Array(Array(String)),
                   menu_location : Array(Position), menu_pos : Position = Position::Top,
                   title_attr : Int32 = 0, subtitle_attr : Int32 = 0)
      super()
      menu_items = menu_list.size
      subsize = menu_list.map { |m| m.size - 1 }

      right_count = menu_items - 1
      parent_window = screen.window.not_nil!
      rightloc = parent_window.max_x
      leftloc = 0
      xpos = LibNCurses.getbegx(parent_window)
      ypos = LibNCurses.getbegy(parent_window)
      ymax = parent_window.max_y

      @screen = screen
      @box = false
      @accepts_focus = false
      @parent = parent_window
      @menu_items = menu_items
      @title_attr = title_attr
      @subtitle_attr = subtitle_attr
      @current_title = 0
      @current_subtitle = 0
      @last_selection = -1
      @menu_pos = menu_pos

      @pull_win = Array(NCurses::Window?).new(menu_items, nil)
      @title_win = Array(NCurses::Window?).new(menu_items, nil)
      @menu_title = Array(Array(Int32)).new(menu_items) { [] of Int32 }
      @menu_title_len = Array(Int32).new(menu_items, 0)
      max_sub = subsize.max? || 1
      @sublist = Array(Array(Array(Int32))).new(menu_items) { Array(Array(Int32)).new(max_sub) { [] of Int32 } }
      @sublist_len = Array(Array(Int32)).new(menu_items) { Array(Int32).new(max_sub, 0) }
      @subsize = Array(Int32).new(menu_items, 0)

      right_count_val = menu_items - 1

      (0...menu_items).each do |x|
        x1 = if menu_location[x].left?
               x
             else
               val = right_count_val
               right_count_val -= 1
               val
             end

        y1 = menu_pos.bottom? ? ymax - 1 : 0
        y2 = menu_pos.bottom? ? ymax - subsize[x] - 2 : TITLELINES
        high = subsize[x] + TITLELINES

        if high + y2 > ymax
          high = ymax - TITLELINES
        end

        max = -1
        (TITLELINES...subsize[x]).each do |y|
          y0 = y - TITLELINES
          chtype, len, _ = char2chtype(menu_list[x][y])
          @sublist[x1][y0] = chtype
          @sublist_len[x1][y0] = len
          max = {max, len}.max
        end

        x2 = if menu_location[x].left?
               leftloc
             else
               rightloc -= (max + 2)
               rightloc
             end

        chtype, len, _ = char2chtype(menu_list[x][0])
        @menu_title[x1] = chtype
        @menu_title_len[x1] = len
        @subsize[x1] = subsize[x] - TITLELINES
        @title_win[x1] = CRT::Ncurses.subwin(parent_window, TITLELINES,
          @menu_title_len[x1] + 2, ypos + y1, xpos + x2)
        @pull_win[x1] = CRT::Ncurses.subwin(parent_window, high, max + 2,
          ypos + y2, xpos + x2)

        return if @title_win[x1].nil? || @pull_win[x1].nil?

        if tw = @title_win[x1]
          tw.keypad(true)
        end
        if pw = @pull_win[x1]
          pw.keypad(true)
        end

        leftloc += @menu_title_len[x] + 1
      end

      @input_window = @title_win[@current_title]

      screen.register(object_type, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      ret = 0

      if scr = @screen
        scr.refresh
      end

      draw(@box)
      draw_subwin

      if actions.nil? || actions.empty?
        @input_window = @title_win[@current_title]

        loop do
          input = getch([] of Bool)
          ret = inject(input)
          return ret if @exit_type != CRT::Ncurses::ExitType::EARLY_EXIT
        end
      else
        actions.each do |action|
          ret = inject(action)
          return ret if @exit_type != CRT::Ncurses::ExitType::EARLY_EXIT
        end
      end

      set_exit_type(0)
      -1
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
        when LibNCurses::Key::Left.value
          across_submenus(-1)
        when LibNCurses::Key::Right.value, CRT::Ncurses::KEY_TAB
          across_submenus(1)
        when LibNCurses::Key::Up.value
          within_submenu(-1)
        when LibNCurses::Key::Down.value, ' '.ord
          within_submenu(1)
        when LibNCurses::Key::Enter.value, CRT::Ncurses::KEY_RETURN
          clean_up_menu
          set_exit_type(resolved)
          @last_selection = @current_title * 100 + @current_subtitle
          ret = @last_selection
          @complete = true
        when CRT::Ncurses::KEY_ESC
          clean_up_menu
          set_exit_type(resolved)
          @last_selection = -1
          ret = @last_selection
          @complete = true
        when CRT::Ncurses::REFRESH
          erase
          if scr = @screen
            scr.refresh
          end
        end
      end

      unless @complete
        set_exit_type(0)
      end

      ret
    end

    def draw(box : Bool = @box)
      (0...@menu_items).each do |x|
        draw_menu_title(x)
      end
    end

    def draw_subwin
      return unless pw = @pull_win[@current_title]

      high = pw.max_y - 2
      x0 = 0
      x1 = @subsize[@current_title]

      x1 = high if x1 > high

      if @current_subtitle >= x1
        x0 = @current_subtitle - x1 + 1
        x1 += x0
      end

      # Box the pull-down window
      LibNCurses.box(pw, 0_i8, 0_i8)
      if @menu_pos.bottom?
        Draw.mvwaddch(pw, @subsize[@current_title] + 1, 0,
          Draw::ACS_VLINE)
      else
        Draw.mvwaddch(pw, 0, 0, Draw::ACS_VLINE)
      end

      # Draw items
      (x0...x1).each do |x|
        draw_item(x, x0)
      end

      select_item(@current_subtitle, x0)
      CRT::Ncurses::Screen.wrefresh(pw)

      # Highlight the title
      if tw = @title_win[@current_title]
        Draw.write_chtype_attrib(tw, 0, 0,
          @menu_title[@current_title], @title_attr, CRT::Ncurses::HORIZONTAL,
          0, @menu_title_len[@current_title])
        CRT::Ncurses::Screen.wrefresh(tw)
      end
    end

    def erase_subwin
      CRT::Ncurses.erase_curses_window(@pull_win[@current_title])
      draw_menu_title(@current_title)
    end

    def erase
      (0...@menu_items).each do |x|
        if tw = @title_win[x]
          tw.erase
          CRT::Ncurses::Screen.wrefresh(tw)
        end
        if pw = @pull_win[x]
          pw.erase
          CRT::Ncurses::Screen.wrefresh(pw)
        end
      end
    end

    def destroy
      (0...@menu_items).each do |x|
        CRT::Ncurses.delete_curses_window(@title_win[x])
        CRT::Ncurses.delete_curses_window(@pull_win[x])
      end

      clear_key_bindings
      CRT::Ncurses::Screen.unregister(object_type, self)
    end

    def set_current_item(menu_item : Int32, submenu_item : Int32)
      @current_title = self.class.wrapped(menu_item, @menu_items)
      @current_subtitle = self.class.wrapped(submenu_item, @subsize[@current_title])
    end

    def title_highlight=(highlight : Int32)
      @title_attr = highlight
    end

    def subtitle_highlight=(highlight : Int32)
      @subtitle_attr = highlight
    end

    def background=(attrib : Int32)
      (0...@menu_items).each do |x|
        if tw = @title_win[x]
          LibNCurses.wbkgd(tw, attrib.to_u32)
        end
        if pw = @pull_win[x]
          LibNCurses.wbkgd(pw, attrib.to_u32)
        end
      end
    end

    def focus
      draw_subwin
      @input_window = @title_win[@current_title]
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :MENU
    end

    def self.wrapped(within : Int32, limit : Int32) : Int32
      if within < 0
        limit - 1
      elsif within >= limit
        0
      else
        within
      end
    end

    private def draw_menu_title(item : Int32)
      return unless tw = @title_win[item]
      Draw.write_chtype(tw, 0, 0, @menu_title[item],
        CRT::Ncurses::HORIZONTAL, 0, @menu_title_len[item])
      CRT::Ncurses::Screen.wrefresh(tw)
    end

    private def draw_item(item : Int32, offset : Int32)
      return unless pw = @pull_win[@current_title]
      Draw.write_chtype(pw, 1,
        item + TITLELINES - offset,
        @sublist[@current_title][item],
        CRT::Ncurses::HORIZONTAL, 0, @sublist_len[@current_title][item])
    end

    private def select_item(item : Int32, offset : Int32)
      return unless pw = @pull_win[@current_title]
      Draw.write_chtype_attrib(pw, 1,
        item + TITLELINES - offset,
        @sublist[@current_title][item], @subtitle_attr,
        CRT::Ncurses::HORIZONTAL, 0, @sublist_len[@current_title][item])
    end

    private def within_submenu(step : Int32)
      next_item = Menu.wrapped(@current_subtitle + step, @subsize[@current_title])
      return if next_item == @current_subtitle

      if pw = @pull_win[@current_title]
        ymax = pw.max_y

        if 1 + LibNCurses.getbegy(pw) + @subsize[@current_title] >= ymax
          @current_subtitle = next_item
          draw_subwin
        else
          draw_item(@current_subtitle, 0)
          @current_subtitle = next_item
          select_item(@current_subtitle, 0)
          CRT::Ncurses::Screen.wrefresh(pw)
        end
      end

      @input_window = @title_win[@current_title]
    end

    private def across_submenus(step : Int32)
      next_item = Menu.wrapped(@current_title + step, @menu_items)
      return if next_item == @current_title

      erase_subwin
      if scr = @screen
        scr.refresh
      end

      @current_title = next_item
      @current_subtitle = 0

      draw_subwin
      @input_window = @title_win[@current_title]
    end

    private def clean_up_menu
      erase_subwin
      if pw = @pull_win[@current_title]
        CRT::Ncurses::Screen.wrefresh(pw)
      end
      if scr = @screen
        scr.refresh
      end
    end
  end
end
