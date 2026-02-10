module CDK
  class Calendar < CDK::CDKObjs
    getter day : Int32 = 1
    getter month : Int32 = 1
    getter year : Int32 = 2000
    property week_base : Int32 = 0

    MONTHS_OF_THE_YEAR = [
      "NULL", "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December",
    ]

    DAYS_OF_THE_MONTH = [
      -1, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31,
    ]

    MAX_DAYS   =  32
    MAX_MONTHS =  13
    MAX_YEARS  = 140
    CALENDAR_LIMIT = MAX_DAYS * MAX_MONTHS * MAX_YEARS

    @field_win : NCurses::Window? = nil
    @label_win : NCurses::Window? = nil
    @marker : Array(Int32) = [] of Int32
    @month_name : Array(String) = MONTHS_OF_THE_YEAR.clone
    @day_name : String = "Su Mo Tu We Th Fr Sa "
    @day_attrib : Int32 = 0
    @month_attrib : Int32 = 0
    @year_attrib : Int32 = 0
    @highlight : Int32 = 0
    @x_offset : Int32 = 0
    @field_width : Int32 = 0
    @week_day : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @parent : NCurses::Window? = nil

    def self.calendar_index(d : Int32, m : Int32, y : Int32) : Int32
      (y * MAX_MONTHS + m) * MAX_DAYS + d
    end

    def self.year2index(year : Int32) : Int32
      year >= 1900 ? year - 1900 : year
    end

    def self.is_leap_year?(year : Int32) : Bool
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
    end

    def self.get_month_length(year : Int32, month : Int32) : Int32
      length = DAYS_OF_THE_MONTH[month]
      length += 1 if month == 2 && is_leap_year?(year)
      length
    end

    def self.get_month_start_weekday(year : Int32, month : Int32) : Int32
      Time.local(year, month, 1).day_of_week.value % 7
    end

    def initialize(cdkscreen : CDK::Screen, xplace : Int32, yplace : Int32,
                   title : String, day : Int32, month : Int32, year : Int32,
                   day_attrib : Int32, month_attrib : Int32, year_attrib : Int32,
                   highlight : Int32, box : Bool, shadow : Bool)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = 24
      box_height = 11

      set_box(box)

      box_width = set_title(title, box_width)
      box_height += @title_lines

      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      xtmp = [xplace]
      ytmp = [yplace]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @x_offset = (box_width - 20) // 2
      @field_width = box_width - 2 * (1 + @border_size)

      @screen = cdkscreen
      @parent = parent_window
      @shadow_win = nil
      @box_width = box_width
      @box_height = box_height
      @day = day
      @month = month
      @year = year
      @day_attrib = day_attrib
      @month_attrib = month_attrib
      @year_attrib = year_attrib
      @highlight = highlight
      @accepts_focus = true
      @input_window = @win
      @week_base = 0
      @shadow = shadow

      @label_win = CDK.subwin(w, 1, @field_width,
        ypos + @title_lines + 1, xpos + 1 + @border_size)

      @field_win = CDK.subwin(w, 7, 20,
        ypos + @title_lines + 3, xpos + @x_offset)

      @marker = Array(Int32).new(CALENDAR_LIMIT, 0)

      # Use today's date if all zeros
      if @day == 0 && @month == 0 && @year == 0
        now = Time.local
        @day = now.day
        @month = now.month
        @year = now.year
      end

      verify_calendar_date
      @week_day = Calendar.get_month_start_weekday(@year, @month)

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      bind(:CALENDAR, 'T'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:CALENDAR, 't'.ord, :getc, LibNCurses::Key::Home.value)
      bind(:CALENDAR, 'n'.ord, :getc, LibNCurses::Key::PageDown.value)
      bind(:CALENDAR, CDK::FORCHAR, :getc, LibNCurses::Key::PageDown.value)
      bind(:CALENDAR, 'p'.ord, :getc, LibNCurses::Key::PageUp.value)
      bind(:CALENDAR, CDK::BACKCHAR, :getc, LibNCurses::Key::PageUp.value)

      cdkscreen.register(:CALENDAR, self)
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      ret = -1
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
      ret
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)
      draw_field

      case input
      when LibNCurses::Key::Up.value
        decrement_calendar_day(7)
      when LibNCurses::Key::Down.value
        increment_calendar_day(7)
      when LibNCurses::Key::Left.value
        decrement_calendar_day(1)
      when LibNCurses::Key::Right.value
        increment_calendar_day(1)
      when LibNCurses::Key::PageDown.value
        increment_calendar_month(1)
      when LibNCurses::Key::PageUp.value
        decrement_calendar_month(1)
      when 'N'.ord
        increment_calendar_month(6)
      when 'P'.ord
        decrement_calendar_month(6)
      when '-'.ord
        decrement_calendar_year(1)
      when '+'.ord
        increment_calendar_year(1)
      when LibNCurses::Key::Home.value
        set_date(-1, -1, -1)
      when CDK::KEY_ESC
        set_exit_type(input)
        @complete = true
      when CDK::KEY_TAB, CDK::KEY_RETURN, LibNCurses::Key::Enter.value
        set_exit_type(input)
        ret = @day
        @complete = true
      when CDK::REFRESH
        if scr = @screen
          scr.erase
          scr.refresh
        end
      end

      unless @complete
        set_exit_type(0)
      end

      ret
    end

    def draw(box : Bool)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_title(w)

        # Draw day-of-week header
        header_len = @day_name.size
        col_len = (6 + header_len) // 7
        7.times do |col|
          src = col_len * ((col + (@week_base % 7)) % 7)
          dst = col_len * col
          part = @day_name[src..]? || ""
          Draw.write_char(w, @x_offset + dst, @title_lines + 2,
            part, CDK::HORIZONTAL, 0, col_len)
        end

        wrefresh
      end

      draw_field
    end

    def draw_field
      return unless fw = @field_win
      month_length = Calendar.get_month_length(@year, @month)
      year_index = Calendar.year2index(@year)

      day = 1 - @week_day + (@week_base % 7)
      day -= 7 if day > 0

      (1..6).each do |row|
        7.times do |col|
          if day >= 1 && day <= month_length
            xpos = col * 3
            ypos = row

            marker = @day_attrib
            temp = "%02d" % day

            if @day == day
              marker = @highlight
            else
              m = get_marker(day, @month, year_index)
              marker |= m
            end
            Draw.write_char_attrib(fw, xpos, ypos, temp, marker,
              CDK::HORIZONTAL, 0, 2)
          end
          day += 1
        end
      end
      CDK::Screen.wrefresh(fw)

      # Draw month/day and year in label window
      if lw = @label_win
        month_name = @month_name[@month]
        temp = "#{month_name} #{@day},"
        Draw.write_char(lw, 0, 0, temp, CDK::HORIZONTAL, 0, temp.size)
        LibNCurses.wclrtoeol(lw)

        year_str = @year.to_s
        Draw.write_char(lw, @field_width - year_str.size, 0, year_str,
          CDK::HORIZONTAL, 0, year_str.size)

        lw.move(0, 0)
        CDK::Screen.wrefresh(lw)
      end
    end

    def set_date(day : Int32, month : Int32, year : Int32)
      now = Time.local
      @day = day == -1 ? now.day : day
      @month = month == -1 ? now.month : month
      @year = year == -1 ? now.year : year
      verify_calendar_date
      @week_day = Calendar.get_month_start_weekday(@year, @month)
    end

    def set_marker(day : Int32, month : Int32, year : Int32, marker : Int32)
      year_index = Calendar.year2index(year)
      old = get_marker(day, month, year_index)
      if old != 0
        set_calendar_cell(day, month, year_index, old | LibNCurses::Attribute::Blink.value.to_i32)
      else
        set_calendar_cell(day, month, year_index, marker)
      end
    end

    def get_marker(day : Int32, month : Int32, year : Int32) : Int32
      idx = Calendar.calendar_index(day, month, year)
      idx >= 0 && idx < @marker.size ? @marker[idx] : 0
    end

    def remove_marker(day : Int32, month : Int32, year : Int32)
      set_calendar_cell(day, month, Calendar.year2index(year), 0)
    end

    def erase
      CDK.erase_curses_window(@label_win)
      CDK.erase_curses_window(@field_win)
      CDK.erase_curses_window(@win)
      CDK.erase_curses_window(@shadow_win)
    end

    def destroy
      clean_title
      CDK.delete_curses_window(@label_win)
      CDK.delete_curses_window(@field_win)
      CDK.delete_curses_window(@shadow_win)
      CDK.delete_curses_window(@win)
      clean_bindings(:CALENDAR)
      CDK::Screen.unregister(:CALENDAR, self)
    end

    def set_bk_attr(attrib : Int32)
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
      draw(@box)
    end

    def unfocus
      draw(@box)
    end

    def object_type : Symbol
      :CALENDAR
    end

    private def set_calendar_cell(d : Int32, m : Int32, y : Int32, value : Int32)
      idx = Calendar.calendar_index(d, m, y)
      @marker[idx] = value if idx >= 0 && idx < @marker.size
    end

    private def verify_calendar_date
      @year = 1900 if @year < 1900
      @month = @month.clamp(1, 12)
      month_length = Calendar.get_month_length(@year, @month)
      @day = @day.clamp(1, month_length)
    end

    private def increment_calendar_day(adjust : Int32)
      month_length = Calendar.get_month_length(@year, @month)
      if adjust + @day > month_length
        @day = @day + adjust - month_length
        increment_calendar_month(1)
      else
        @day += adjust
        draw_field
      end
    end

    private def decrement_calendar_day(adjust : Int32)
      if @day - adjust < 1
        if @month == 1 && @year == 1900
          CDK.beep
          return
        end
        prev_month = @month == 1 ? 12 : @month - 1
        prev_year = @month == 1 ? @year - 1 : @year
        month_length = Calendar.get_month_length(prev_year, prev_month)
        @day = month_length - (adjust - @day)
        decrement_calendar_month(1)
      else
        @day -= adjust
        draw_field
      end
    end

    private def increment_calendar_month(adjust : Int32)
      if @month + adjust > 12
        @month = @month + adjust - 12
        @year += 1
      else
        @month += adjust
      end
      month_length = Calendar.get_month_length(@year, @month)
      @day = {@day, month_length}.min
      @week_day = Calendar.get_month_start_weekday(@year, @month)
      erase
      draw(@box)
    end

    private def decrement_calendar_month(adjust : Int32)
      if @month <= adjust
        if @year == 1900
          CDK.beep
          return
        end
        @month = 13 - adjust
        @year -= 1
      else
        @month -= adjust
      end
      month_length = Calendar.get_month_length(@year, @month)
      @day = {@day, month_length}.min
      @week_day = Calendar.get_month_start_weekday(@year, @month)
      erase
      draw(@box)
    end

    private def increment_calendar_year(adjust : Int32)
      @year += adjust
      if @month == 2
        month_length = Calendar.get_month_length(@year, @month)
        @day = {@day, month_length}.min
      end
      @week_day = Calendar.get_month_start_weekday(@year, @month)
      erase
      draw(@box)
    end

    private def decrement_calendar_year(adjust : Int32)
      if @year - adjust < 1900
        CDK.beep
        return
      end
      @year -= adjust
      if @month == 2
        month_length = Calendar.get_month_length(@year, @month)
        @day = {@day, month_length}.min
      end
      @week_day = Calendar.get_month_start_weekday(@year, @month)
      erase
      draw(@box)
    end
  end
end
