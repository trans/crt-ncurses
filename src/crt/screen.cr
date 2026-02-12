module CRT
  # TODO: Investigate terminal color query (OSC 11) response leaking into the
  # shell after NCurses.end. Some terminals send async replies to color queries
  # that arrive after endwin(). NCurses.flush_input or draining stdin post-exit
  # may mitigate. See: https://invisible-island.net/ncurses/ncurses.faq.html

  class Screen
    property object_focus : Int32 = 0
    property object_count : Int32 = 0
    property object_limit : Int32 = 2
    property object : Array(CRT::CRTObjs?) = Array(CRT::CRTObjs?).new(2, nil)
    property window : NCurses::Window? = nil
    property exit_status : Int32 = 0

    NOEXIT     = 0
    EXITOK     = 1
    EXITCANCEL = 2

    @@refresh_output : Bool = true

    def initialize(window : NCurses::Window)
      if CRT::ALL_SCREENS.empty?
        NCurses.no_echo
        NCurses.cbreak
      end

      CRT::ALL_SCREENS << self
      @object_count = 0
      @object_limit = 2
      @object = Array(CRT::CRTObjs?).new(@object_limit, nil)
      @window = window
      @object_focus = 0
    end

    # Register a CRT object with a screen
    def register(obj_type : Symbol, obj : CRT::CRTObjs)
      if @object_count + 1 >= @object_limit
        @object_limit += 2
        @object_limit *= 2
        while @object.size < @object_limit
          @object << nil
        end
      end

      if obj.valid_obj_type?(obj_type)
        set_screen_index(@object_count, obj)
        @object_count += 1
      end
    end

    # Remove an object from the CRT screen
    def self.unregister(obj_type : Symbol, obj : CRT::CRTObjs)
      return unless obj.valid_obj_type?(obj_type) && obj.screen_index >= 0
      screen = obj.screen
      return if screen.nil?

      index = obj.screen_index
      obj.screen_index = -1

      # Resequence the objects
      (index...screen.object_count - 1).each do |x|
        if next_obj = screen.object[x + 1]
          screen.set_screen_index(x, next_obj)
        end
      end

      if screen.object_count <= 1
        screen.object = [] of CRT::CRTObjs?
        screen.object_count = 0
        screen.object_limit = 0
      else
        screen.object[screen.object_count - 1] = nil
        screen.object_count -= 1

        if screen.object_focus == index
          screen.object_focus -= 1
          screen.object_focus = 0 if screen.object_focus < 0
        elsif screen.object_focus > index
          screen.object_focus -= 1
        end
      end
    end

    def set_screen_index(number : Int32, obj : CRT::CRTObjs)
      obj.screen_index = number
      obj.screen = self
      @object[number] = obj
    end

    def valid_index?(n : Int32) : Bool
      n >= 0 && n < @object_count
    end

    def swap_indices(n1 : Int32, n2 : Int32)
      if n1 != n2 && valid_index?(n1) && valid_index?(n2)
        o1 = @object[n1]
        o2 = @object[n2]
        set_screen_index(n1, o2.not_nil!) if o2
        set_screen_index(n2, o1.not_nil!) if o1

        if @object_focus == n1
          @object_focus = n2
        elsif @object_focus == n2
          @object_focus = n1
        end
      end
    end

    def self.raise_object(obj_type : Symbol, obj : CRT::CRTObjs)
      if obj.valid_obj_type?(obj_type)
        if screen = obj.screen
          screen.swap_indices(obj.screen_index, screen.object_count - 1)
        end
      end
    end

    def self.lower_object(obj_type : Symbol, obj : CRT::CRTObjs)
      if obj.valid_obj_type?(obj_type)
        if screen = obj.screen
          screen.swap_indices(obj.screen_index, 0)
        end
      end
    end

    def self.refresh_output(v : Bool = true)
      @@refresh_output = v
    end

    def self.refresh_output? : Bool
      @@refresh_output
    end

    def self.wrefresh(w : NCurses::Window)
      if refresh_output?
        w.refresh
      else
        LibNCurses.noutrefresh(w)
      end
    end

    def self.refresh_window(win : NCurses::Window)
      LibNCurses.touchwin(win)
      wrefresh(win)
    end

    # This calls refresh (made consistent with widgets)
    def draw
      refresh
    end

    # Refresh all objects in the screen
    def refresh
      if w = @window
        Screen.refresh_window(w)
      end

      focused = -1
      visible = -1

      # Erase invisible objects, track visible and focused
      (0...@object_count).each do |x|
        if obj = @object[x]
          if obj.valid_obj_type?(obj.object_type)
            if obj.is_visible
              visible = x if visible < 0
              focused = x if obj.has_focus && focused < 0
            else
              obj.erase
            end
          end
        end
      end

      # Draw visible objects
      (0...@object_count).each do |x|
        if obj = @object[x]
          if obj.valid_obj_type?(obj.object_type)
            obj.has_focus = (x == focused)
            if obj.is_visible
              obj.draw(obj.box)
            end
          end
        end
      end
    end

    # Erase all objects in the screen
    def erase
      (0...@object_count).each do |x|
        if obj = @object[x]
          if obj.valid_obj_type?(obj.object_type)
            obj.erase
          end
        end
      end

      if w = @window
        Screen.wrefresh(w)
      end
    end

    # Destroy all objects on a screen
    def destroy_screen_objects
      (0...@object_count).each do |x|
        if obj = @object[x]
          if obj.valid_obj_type?(obj.object_type)
            obj.erase
            obj.destroy
          end
        end
      end
    end

    # Destroy this screen
    def destroy
      CRT::ALL_SCREENS.delete(self)
    end

    # End CRT / ncurses mode
    def self.end_crt
      NCurses.echo
      NCurses.nocbreak
      NCurses.end
    end
  end
end
