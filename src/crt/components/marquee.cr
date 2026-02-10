module CRT
  class Marquee < CRT::CRTObjs
    property active : Bool = true
    @width : Int32 = 0
    @shadow : Bool = false
    @parent : NCurses::Window? = nil

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   width : Int32 = 0, box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x

      @screen = cdkscreen
      @parent = parent_window
      @width = width
      @shadow = shadow
      @active = true

      set_box(box)

      box_width = CRT.set_widget_dimension(parent_width, width, 0)
      box_height = @border_size * 2 + 1

      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @box_height = box_height
      @box_width = box_width

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      cdkscreen.register(:MARQUEE, self)
    end

    def activate(mesg : String, delay : Int32, repeat : Int32, box : Bool) : Int32
      return -1 if mesg.empty?
      return -1 unless w = @win

      set_box(box)

      mesg_length_arr = [] of Int32
      message = char2chtype(mesg, mesg_length_arr, [] of Int32)
      mesg_length = mesg_length_arr[0]

      draw(@box)
      view_limit = @box_width - 2 * @border_size

      padding = mesg[-1] == ' ' ? 0 : 1

      first_char = 0
      last_char = 1
      view_size = last_char - first_char
      start_pos = @box_width - view_size - @border_size
      repeat_count = 0
      first_time = true

      old_curs = LibNCurses.curs_set(0)

      while @active
        if first_time
          first_char = 0
          last_char = 1
          view_size = last_char - first_char
          start_pos = @box_width - view_size - @border_size
          first_time = false
        end

        # Draw characters
        y = first_char
        (start_pos...(start_pos + view_size)).each do |x|
          ch = y < mesg_length ? message[y] : ' '.ord
          Draw.mvwaddch(w, @border_size, x, ch)
          y += 1
        end
        wrefresh

        # Advance the scroll
        if mesg_length < view_limit
          if last_char < mesg_length + padding
            last_char += 1
            view_size += 1
            start_pos = @box_width - view_size - @border_size
          elsif start_pos > @border_size
            start_pos -= 1
            view_size = mesg_length + padding
          else
            start_pos = @border_size
            first_char += 1
            view_size -= 1
          end
        else
          if start_pos > @border_size
            last_char += 1
            view_size += 1
            start_pos -= 1
          elsif last_char < mesg_length + padding
            first_char += 1
            last_char += 1
            start_pos = @border_size
            view_size = view_limit
          else
            start_pos = @border_size
            first_char += 1
            view_size -= 1
          end
        end

        # Check if we need to start over
        if view_size <= 0 && first_char == mesg_length + padding
          repeat_count += 1
          break if repeat > 0 && repeat_count >= repeat

          Draw.mvwaddch(w, @border_size, @border_size, ' '.ord)
          wrefresh
          first_time = true
        end

        LibNCurses.napms(delay * 10)
      end

      old_curs = 1 if old_curs < 0
      LibNCurses.curs_set(old_curs)
      0
    end

    def deactivate
      @active = false
    end

    def draw(box : Bool)
      @box = box
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        wrefresh
      end
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      clean_bindings(:MARQUEE)
      CRT::Screen.unregister(:MARQUEE, self)
    end

    def set_bk_attr(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
    end

    def object_type : Symbol
      :MARQUEE
    end
  end
end
