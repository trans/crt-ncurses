module CRT
  class AlphaList < CRT::CRTObjs
    include ListSupport

    getter scroll_field : CRT::Scroll
    getter entry_field : CRT::Entry
    getter list : Array(String) = [] of String

    @highlight : Int32 = 0
    @filler_char : Char = '.'
    @shadow : Bool = false
    @parent : NCurses::Window? = nil
    @complete : Bool = false
    @save_focus : Bool = false

    def initialize(cdkscreen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32, list : Array(String),
                   title : String = "", label : String = "",
                   filler_char : Char = '.', highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   box : Bool = true, shadow : Bool = false)
      super()
      parent_window = cdkscreen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y
      label_len = 0

      @list = list.sort.dup

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)

      if !label.empty?
        label_len_arr = [] of Int32
        char2chtype(label, label_len_arr, [] of Int32)
        label_len = label_len_arr[0]
      end

      xtmp = [x]
      ytmp = [y]
      alignxy(parent_window, xtmp, ytmp, box_width, box_height)
      xpos = xtmp[0]
      ypos = ytmp[0]

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @screen = cdkscreen
      @parent = parent_window
      @highlight = highlight
      @filler_char = filler_char
      @box_height = box_height
      @box_width = box_width
      @shadow = shadow

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      # Create the entry field
      temp_width = is_full_width?(width) ? CRT::FULL : box_width - 2 - label_len
      @entry_field = CRT::Entry.new(cdkscreen,
        x: LibNCurses.getbegx(w), y: LibNCurses.getbegy(w),
        title: title, label: label, field_width: temp_width,
        filler: filler_char, box: box, shadow: false)

      entry_win = @entry_field.win
      return unless entry_win

      @entry_field.ll_char = Draw::ACS_LTEE
      @entry_field.lr_char = Draw::ACS_RTEE

      # Create the scrolling list below the entry
      temp_height = entry_win.max_y - @border_size
      temp_width_scroll = is_full_width?(width) ? CRT::FULL : box_width - 1
      @scroll_field = CRT::Scroll.new(cdkscreen,
        x: LibNCurses.getbegx(w), y: LibNCurses.getbegy(entry_win) + temp_height,
        height: box_height - temp_height, width: temp_width_scroll,
        list: @list, box: box, shadow: false)

      @scroll_field.ul_char = Draw::ACS_LTEE
      @scroll_field.ur_char = Draw::ACS_RTEE

      @input_window = @entry_field.win
      @accepts_focus = true

      remap_key(CRT::BACKCHAR, LibNCurses::Key::PageUp.value)
      remap_key(CRT::FORCHAR, LibNCurses::Key::PageDown.value)

      cdkscreen.register(object_type, self)
    end

    def activate(actions : Array(Int32)? = nil) : String | Int32
      draw(@box)

      if actions.nil? || actions.empty?
        loop do
          @input_window = @entry_field.input_window
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

      0
    end

    def inject(input : Int32) : String | Int32
      ret : String | Int32 = -1
      @complete = false

      draw(@box)

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
        when LibNCurses::Key::Up.value, LibNCurses::Key::Down.value,
             LibNCurses::Key::PageUp.value, LibNCurses::Key::PageDown.value
          if @scroll_field.list_size > 0
            inject_my_scroller(resolved)
            # Update entry from scroll selection
            current_idx = @scroll_field.current_item
            if current_idx >= 0 && current_idx < @list.size
              @entry_field.value = @list[current_idx]
              @entry_field.draw(@entry_field.box)
            end
          else
            CRT.beep
          end
        when CRT::KEY_TAB
          # Attempt word completion
          if @entry_field.info.empty?
            CRT.beep
          else
            index = search_list(@list, @list.size, @entry_field.info)
            if index < 0
              CRT.beep
            else
              @entry_field.value = @list[index]
              @entry_field.draw(@entry_field.box)
              @scroll_field.set_position(index)
              draw_my_scroller
            end
          end
        else
          # Delegate to entry field
          ret = @entry_field.inject(resolved)
          @exit_type = @entry_field.exit_type

          if @exit_type == CRT::ExitType::EARLY_EXIT
            # Filter the scroll list based on current entry
            if !@entry_field.info.empty?
              index = search_list(@list, @list.size, @entry_field.info)
              if index >= 0
                @scroll_field.set_position(index)
                draw_my_scroller
              end
            else
              @scroll_field.set_position(0)
              draw_my_scroller
            end
          else
            @complete = true
            return ret
          end
        end
      end

      unless @complete
        set_exit_type(0)
      end

      ret
    end

    def draw(box : Bool = @box)
      Draw.draw_shadow(@shadow_win)
      @entry_field.draw(@entry_field.box)
      draw_my_scroller
    end

    def erase
      @scroll_field.erase
      @entry_field.erase
      CRT.erase_curses_window(@shadow_win)
      CRT.erase_curses_window(@win)
    end

    def destroy
      clear_key_bindings
      @entry_field.destroy
      @scroll_field.destroy
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      CRT::Screen.unregister(object_type, self)
    end

    def contents=(list : Array(String))
      @list = list.sort.dup
      @scroll_field.set_items(@list)
      @entry_field.clean
      erase
      draw(@box)
    end

    def current_item=(item : Int32)
      if @list.size > 0
        @scroll_field.current_item = item
        if @scroll_field.current_item < @list.size
          @entry_field.value = @list[@scroll_field.current_item]
        end
      end
    end

    def current_item : Int32
      @scroll_field.current_item
    end

    def filler_char=(filler : Char)
      @filler_char = filler
      @entry_field.filler_char = filler
    end

    def highlight=(highlight : Int32)
      @highlight = highlight
    end

    def background=(attrib : Int32)
      @entry_field.background = attrib
      @scroll_field.background = attrib
    end

    def focus
      @entry_field.focus
    end

    def unfocus
      @entry_field.unfocus
    end

    def object_type : Symbol
      :ALPHA_LIST
    end

    private def draw_my_scroller
      save = @scroll_field.has_focus
      @scroll_field.has_focus = @entry_field.has_focus
      @scroll_field.draw(@scroll_field.box)
      @scroll_field.has_focus = save
    end

    private def inject_my_scroller(key : Int32)
      save = @scroll_field.has_focus
      @scroll_field.has_focus = @entry_field.has_focus
      @scroll_field.inject(key)
      @scroll_field.has_focus = save
    end

    private def is_full_width?(width : Int32) : Bool
      width == CRT::FULL
    end
  end
end
