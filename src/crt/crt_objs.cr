module CRT
  abstract class CRTObjs
    include Alignments
    include Justifications
    include Converters
    include Movement
    include Borders
    include Focusable
    include Bindings
    include ExitConditions
    include HasScreen
    include HasTitle
    include WindowInput
    include WindowHooks
    include CommonControls
    include Formattable

    @@g_paste_buffer = ""

    def self.paste_buffer : String
      @@g_paste_buffer
    end

    def self.paste_buffer=(value : String)
      @@g_paste_buffer = value
    end

    # Subclasses must provide access to these window references
    property win : NCurses::Window? = nil
    property shadow_win : NCurses::Window? = nil
    property input_window : NCurses::Window? = nil

    property box_width : Int32 = 0
    property box_height : Int32 = 0

    @title : Array(Array(Int32)) = [] of Array(Int32)
    @title_pos : Array(Int32) = [] of Int32
    @title_len : Array(Int32) = [] of Int32

    # TODO: Consider having `activate` return `self` instead of mixed types
    # (String, Int32, String | Int32, T). Widget state (value, exit_type, etc.)
    # is already accessible via getters after activation, making return values
    # redundant. Also consider renaming to `activate!` to signal that it blocks.

    def self.open(*args, **kwargs, &)
      widget = new(*args, **kwargs)
      begin
        yield widget
      ensure
        widget.destroy
      end
    end

    def initialize
      CRT::ALL_OBJECTS << self

      init_title
      init_borders
      init_focus
      init_exit_conditions
      init_screen
    end

    def timeout(v : Int32)
      if input_win = @input_window
        input_win.timeout = v
      end
    end

    def object_type : Symbol
      :NULL
    end

    def valid_obj_type?(type : Symbol) : Bool
      true
    end

    def valid_object? : Bool
      CRT::ALL_OBJECTS.includes?(self) && valid_obj_type?(object_type)
    end

    # Set the background color of the widget
    def set_background_color(color : String)
      return if color.empty?

      junk1 = [] of Int32
      junk2 = [] of Int32
      holder = char2chtype(color, junk1, junk2)
      set_bk_attr(holder[0]) unless holder.empty?
    end

    def set_bk_attr(attrib : Int32)
      if w = @win
        LibNCurses.wbkgd(w, attrib.to_u32)
      end
    end
  end
end
