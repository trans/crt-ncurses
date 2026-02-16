module CRT::Ncurses
  module HasTitle
    property title_attrib : Int32 = 0
    property title_lines : Int32 = 0

    def init_title
      @title_attrib = 0 # A_NORMAL
      @title_lines = 0
      @title = [] of Array(Int32)
      @title_pos = [] of Int32
      @title_len = [] of Int32
    end

    # Set the widget's title.
    def set_title(title : String?, box_width : Int32) : Int32
      return box_width if title.nil?

      temp = title.split("\n")
      @title_lines = temp.size

      if box_width >= 0
        max_width = 0
        temp.each do |line|
          _, len, _ = char2chtype(line)
          max_width = {len, max_width}.max
        end
        box_width = {box_width, max_width + 2 * @border_size}.max
      else
        box_width = -(box_width - 1)
      end

      title_width = box_width - (2 * @border_size)
      @title = [] of Array(Int32)
      @title_pos = [] of Int32
      @title_len = [] of Int32

      @title_lines.times do |x|
        chtype, len, pos = char2chtype(temp[x])
        @title << chtype
        @title_len << len
        @title_pos << justify_string(title_width, len, pos)
      end

      box_width
    end

    # Draw the widget's title
    def draw_title(win : NCurses::Window)
      @title_lines.times do |x|
        CRT::Ncurses::Draw.write_chtype_attrib(win,
          @title_pos[x] + @border_size,
          x + @border_size,
          @title[x],
          @title_attrib,
          CRT::Ncurses::HORIZONTAL,
          0,
          @title_len[x])
      end
    end

    def clean_title
      @title_lines = 0
    end
  end
end
