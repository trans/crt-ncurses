module CRT
  class Button < CRT::CRTObjs
    include Formattable

    getter xpos : Int32 = 0
    getter ypos : Int32 = 0
    getter parent : NCurses::Window? = nil
    property callback : Proc(CRT::Button, Nil)? = nil

    @info : Array(Int32) = [] of Int32
    @info_len : Int32 = 0
    @info_pos : Int32 = 0
    @shadow : Bool = false
    @complete : Bool = false
    @result_data : Int32 = -1

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   text : String, callback : Proc(CRT::Button, Nil)? = nil,
                   box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = 0

      set_box(box)
      box_height = 1 + 2 * @border_size

      # Translate the string to a chtype array
      info_len = [] of Int32
      info_pos = [] of Int32
      @info = char2chtype(text, info_len, info_pos)
      @info_len = info_len[0]
      @info_pos = info_pos[0]

      box_width = {@info_len, box_width}.max + 2 * @border_size

      # Create the string alignments
      @info_pos = justify_string(box_width - 2 * @border_size,
        @info_len, @info_pos)

      # Clamp to parent dimensions
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      # Align positions
      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @screen = screen
      @parent = parent_window
      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      @shadow_win = nil
      @xpos = xpos
      @ypos = ypos
      @box_width = box_width
      @box_height = box_height
      @callback = callback
      @input_window = @win
      @accepts_focus = true
      @shadow = shadow

      if w = @win
        w.keypad(true)
      end

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : Array(Int32)? = nil) : Int32
      draw(@box)
      ret = -1

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
      -1
    end

    def inject(input : Int32) : Int32
      ret = -1
      @complete = false

      set_exit_type(0)

      case input
      when CRT::KEY_ESC
        set_exit_type(input)
        @complete = true
      when ' '.ord, CRT::KEY_RETURN, LibNCurses::Key::Enter.value
        if cb = @callback
          cb.call(self)
        end
        set_exit_type(LibNCurses::Key::Enter.value)
        ret = 0
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
        set_exit_type(0)
      end

      @result_data = ret
      ret
    end

    def message=(info : String)
      info_len = [] of Int32
      info_pos = [] of Int32
      @info = char2chtype(info, info_len, info_pos)
      @info_len = info_len[0]
      @info_pos = justify_string(@box_width - 2 * @border_size,
        @info_len, info_pos[0])

      erase
      draw(@box)
    end

    def draw_text
      return unless w = @win
      box_width = @box_width

      (0...(box_width - 2 * @border_size)).each do |i|
        pos = @info_pos
        len = @info_len
        if i >= pos && (i - pos) < len
          c = @info[i - pos]
        else
          c = ' '.ord
        end

        c = c | LibNCurses::Attribute::Reverse.value.to_i32 if @has_focus
        Draw.mvwaddch(w, @border_size, i + @border_size, c)
      end
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)

      if w = @win
        Draw.draw_obj_box(w, self) if box
        draw_text
        wrefresh
      end
    end

    def erase
      CRT.erase_curses_window(@win)
      CRT.erase_curses_window(@shadow_win)
    end

    def destroy
      unregister_framing
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
      draw_text
      wrefresh
    end

    def unfocus
      draw_text
      wrefresh
    end

    def object_type : Symbol
      :BUTTON
    end
  end
end
