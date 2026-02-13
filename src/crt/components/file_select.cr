module CRT
  class FileSelect < CRT::CRTObjs
    include ListSupport

    getter scroll_field : CRT::Scroll
    getter entry_field : CRT::Entry
    getter dir_contents : Array(String) = [] of String
    getter file_counter : Int32 = 0
    getter pwd : String = ""
    getter pathname : String = ""

    property dir_attribute : String = ""
    property file_attribute : String = ""
    property link_attribute : String = ""
    property sock_attribute : String = ""
    property field_attribute : Int32 = 0
    property filler_character : Char = '.'
    property highlight : Int32 = 0

    @shadow : Bool = false
    @parent : NCurses::Window? = nil
    @complete : Bool = false

    def initialize(screen : CRT::Screen, *, x : Int32, y : Int32,
                   height : Int32, width : Int32,
                   title : String = "", label : String = "",
                   field_attribute : Int32 = 0, filler_char : Char = '.',
                   highlight : Int32 = LibNCurses::Attribute::Reverse.value.to_i32,
                   dir_attribute : String = "", file_attribute : String = "",
                   link_attribute : String = "", sock_attribute : String = "",
                   box : Bool | CRT::Framing | Nil = nil, shadow : Bool = false)
      super()
      parent_window = screen.window.not_nil!
      parent_width = parent_window.max_x
      parent_height = parent_window.max_y

      set_box(box)

      box_height = CRT.set_widget_dimension(parent_height, height, 0)
      box_width = CRT.set_widget_dimension(parent_width, width, 0)

      xpos, ypos = alignxy(parent_window, x, y, box_width, box_height)

      box_width = {box_width, 15}.max
      box_height = {box_height, 6}.max

      @win = NCurses::Window.new(height: box_height, width: box_width, y: ypos, x: xpos)
      return unless w = @win
      w.keypad(true)

      @screen = screen
      @parent = parent_window
      @dir_attribute = dir_attribute
      @file_attribute = file_attribute
      @link_attribute = link_attribute
      @sock_attribute = sock_attribute
      @highlight = highlight
      @filler_character = filler_char
      @field_attribute = field_attribute
      @box_height = box_height
      @box_width = box_width
      @file_counter = 0
      @input_window = @win
      @shadow = shadow
      @accepts_focus = true

      # Get the present working directory
      @pwd = Dir.current

      # Get directory contents
      set_dir_contents

      # Create the entry field
      label_len_arr = [] of Int32
      char2chtype(label, label_len_arr, [] of Int32)
      label_len = label_len_arr[0]? || 0

      temp_width = is_full_width?(width) ? CRT::FULL : box_width - 2 - label_len
      @entry_field = CRT::Entry.new(screen,
        x: LibNCurses.getbegx(w), y: LibNCurses.getbegy(w),
        title: title, label: label, field_width: temp_width,
        field_attr: field_attribute, filler: filler_char, box: box, shadow: false)

      entry_win = @entry_field.win
      return unless entry_win

      @entry_field.ll_char = Draw::ACS_LTEE
      @entry_field.lr_char = Draw::ACS_RTEE
      @entry_field.value = @pwd

      # Create the scrolling list
      temp_height = entry_win.max_y - @border_size
      temp_width_scroll = is_full_width?(width) ? CRT::FULL : box_width - 1
      @scroll_field = CRT::Scroll.new(screen,
        x: LibNCurses.getbegx(w), y: LibNCurses.getbegy(entry_win) + temp_height,
        height: box_height - temp_height, width: temp_width_scroll,
        list: @dir_contents, highlight: @highlight, box: box, shadow: false)

      @scroll_field.ul_char = Draw::ACS_LTEE
      @scroll_field.ur_char = Draw::ACS_RTEE

      if shadow
        @shadow_win = NCurses::Window.new(height: box_height, width: box_width,
          y: ypos + 1, x: xpos + 1)
      end

      remap_key(CRT::BACKCHAR, LibNCurses::Key::PageUp.value)
      remap_key(CRT::FORCHAR, LibNCurses::Key::PageDown.value)

      screen.register(object_type, self)
      register_framing
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

      set_exit_type(0)
      0
    end

    def inject(input : Int32) : String | Int32
      ret : String | Int32 = -1
      @complete = false

      resolved = resolve_key(input)
      if resolved.nil?
        @complete = true
      else
        case resolved
        when LibNCurses::Key::Up.value, LibNCurses::Key::Down.value,
             LibNCurses::Key::PageUp.value, LibNCurses::Key::PageDown.value
          if @scroll_field.list_size > 0
            inject_my_scroller(resolved)
            # Get the currently highlighted filename
            current_idx = @scroll_field.current_item
            if current_idx >= 0 && current_idx < @dir_contents.size
              temp = content_to_path(@dir_contents[current_idx])
              @entry_field.value = temp
              @entry_field.draw(@entry_field.box)
            end
          else
            CRT.beep
          end
        when CRT::KEY_TAB
          # Tab completion
          filename = @entry_field.info
          if filename.empty?
            CRT.beep
          else
            # Check if it's a directory
            if Dir.exists?(filename)
              self.directory = filename
            else
              # Look for matching files
              file_list = (0...@file_counter).map { |x| content_to_path(@dir_contents[x]) }
              index = search_list(file_list, file_list.size, filename)
              if index >= 0
                @entry_field.value = file_list[index]
                @entry_field.draw(@entry_field.box)
                @scroll_field.set_position(index)
                draw_my_scroller
              else
                CRT.beep
              end
            end
          end
        else
          # Delegate to entry field
          filename = @entry_field.inject(resolved)
          @exit_type = @entry_field.exit_type

          if @exit_type == CRT::ExitType::EARLY_EXIT
            return 0
          end

          filename_str = filename.is_a?(String) ? filename : ""
          if !filename_str.empty? && !Dir.exists?(filename_str)
            @pathname = filename_str
            ret = @pathname
            @complete = true
          elsif !filename_str.empty? && Dir.exists?(filename_str)
            self.directory = filename_str
            draw_my_scroller
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

    def directory=(directory : String)
      return if directory.empty?

      expanded = File.expand_path(directory)
      if Dir.exists?(expanded)
        @pwd = expanded
        @entry_field.value = @pwd
        @entry_field.draw(@entry_field.box)
        set_dir_contents
        @scroll_field.set_items(@dir_contents)
      else
        CRT.beep
      end
    end

    def erase
      @scroll_field.erase
      @entry_field.erase
      CRT.erase_curses_window(@win)
    end

    def destroy
      unregister_framing
      clear_key_bindings
      @scroll_field.destroy
      @entry_field.destroy
      CRT.delete_curses_window(@shadow_win)
      CRT.delete_curses_window(@win)
      CRT::Screen.unregister(object_type, self)
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
      :FILE_SELECT
    end

    def content_to_path(content : String) : String
      temp_len = [] of Int32
      temp_chtype = char2chtype(content, temp_len, [] of Int32)
      temp_char = chtype2char(temp_chtype)
      make_pathname(@pwd, temp_char.strip)
    end

    private def make_pathname(directory : String, filename : String) : String
      if filename == ".."
        File.expand_path(directory) + "/.."
      else
        File.expand_path(filename, directory)
      end
    end

    private def set_dir_contents
      @dir_contents = [] of String
      @file_counter = 0

      begin
        entries = Dir.entries(@pwd).sort
      rescue
        return
      end

      entries.each do |entry|
        full_path = File.join(@pwd, entry)
        attr = ""
        mode = ' '

        begin
          info = File.info(full_path, follow_symlinks: false)
          if info.symlink?
            attr = @link_attribute
            mode = '@'
          elsif info.directory?
            attr = @dir_attribute
            mode = '/'
          elsif info.type.socket?
            attr = @sock_attribute
            mode = '&'
          else
            attr = @file_attribute
            # Check if executable
            if File.executable?(full_path)
              mode = '*'
            end
          end
        rescue
          attr = @file_attribute
        end

        @dir_contents << "#{attr}#{entry}#{mode}"
        @file_counter += 1
      end
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
