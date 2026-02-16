module CRT::Ncurses
  class Label < CRT::Ncurses::CRTObjs
    getter xpos : Int32 = 0
    getter ypos : Int32 = 0
    getter rows : Int32 = 0
    getter parent : NCurses::Window? = nil

    @info : Array(Array(Int32)) = [] of Array(Int32)
    @info_len : Array(Int32) = [] of Int32
    @info_pos : Array(Int32) = [] of Int32

    def initialize(screen : CRT::Ncurses::Screen, *, x : Int32, y : Int32,
                   mesg : Array(String), box : Bool | CRT::Ncurses::Framing | Nil = nil, shadow : Bool = false)
      super()

      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      box_width = 0
      box_height = 0

      return if mesg.empty?

      set_box(box)
      box_height = mesg.size + 2 * @border_size

      @info = [] of Array(Int32)
      @info_len = [] of Int32
      @info_pos = [] of Int32

      # Determine the box width by finding the widest message line
      mesg.size.times do |x|
        chtype, len, pos = char2chtype(mesg[x])
        @info << chtype
        @info_len << len
        @info_pos << pos
        box_width = {box_width, len}.max
      end
      box_width += 2 * @border_size

      # Create the string alignments
      mesg.size.times do |x|
        @info_pos[x] = justify_string(box_width - 2 * @border_size,
          @info_len[x], @info_pos[x])
      end

      # Clamp to parent dimensions
      box_width = {box_width, parent_width}.min
      box_height = {box_height, parent_height}.min

      # Rejustify the x and y positions if needed
      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      @screen = screen
      @parent = parent_window
      @win = NCurses::Window.new(
        height: box_height,
        width: box_width,
        y: ypos,
        x: xpos
      )
      @shadow_win = nil
      @xpos = xpos
      @ypos = ypos
      @rows = mesg.size
      @box_width = box_width
      @box_height = box_height
      @input_window = @win
      @has_focus = false
      @shadow = shadow

      if w = @win
        w.keypad(true)
      end

      # If a shadow was requested, create the shadow window
      if shadow
        @shadow_win = NCurses::Window.new(
          height: box_height,
          width: box_width,
          y: ypos + 1,
          x: xpos + 1
        )
      end

      # Register this widget
      screen.register(object_type, self)
      register_framing
    end

    def activate(actions : String = "")
      draw(@box)
    end

    # Set multiple attributes
    def set(mesg : Array(String), lines : Int32, box : Bool)
      self.message = mesg
      set_box(box)
    end

    # Set the information within the label
    def message=(info : Array(String))
      info_size = info.size

      # Clean out the old message
      @rows.times do |x|
        @info[x] = [] of Int32
        @info_pos[x] = 0
        @info_len[x] = 0
      end

      @rows = {info_size, @rows}.min

      # Copy in the new message
      @rows.times do |x|
        chtype, len, pos = char2chtype(info[x])
        @info[x] = chtype
        @info_len[x] = len
        @info_pos[x] = justify_string(@box_width - 2 * @border_size, len, pos)
      end

      # Redraw
      erase
      draw(@box)
    end

    def message : Array(Array(Int32))
      @info
    end

    def object_type : Symbol
      :LABEL
    end

    # Set the background attribute of the widget
    def background=(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
    end

    # Draw the label widget
    def draw(box : Bool = @box)
      # Draw shadow if present
      Draw.draw_shadow(@shadow_win)

      # Box the widget if requested
      if w = @win
        if box
          Draw.draw_obj_box(w, self)
        end

        # Draw the message lines
        @rows.times do |x|
          Draw.write_chtype(w,
            @info_pos[x] + @border_size, x + @border_size,
            @info[x], CRT::Ncurses::HORIZONTAL, 0, @info_len[x])
        end

        # Refresh
        wrefresh
      end
    end

    # Erase the label widget
    def erase
      CRT::Ncurses.erase_curses_window(@win)
      CRT::Ncurses.erase_curses_window(@shadow_win)
    end

    # Destroy the label widget
    def destroy
      unregister_framing
      CRT::Ncurses.delete_curses_window(@shadow_win)
      CRT::Ncurses.delete_curses_window(@win)
      clear_key_bindings
      CRT::Ncurses::Screen.unregister(object_type, self)
    end

    # Pause until a user hits a key
    def wait(key : Int32 = 0) : Int32
      function_key = [] of Bool
      if key == 0
        code = getch(function_key)
      else
        code = 0
        loop do
          code = getch(function_key)
          break if code == key
        end
      end
      code
    end
  end
end
