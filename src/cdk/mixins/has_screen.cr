module CDK
  module HasScreen
    property screen_index : Int32 = -1
    property screen : CDK::Screen? = nil
    property is_visible : Bool = true

    def init_screen
      @is_visible = true
    end

    def screen_xpos(n : Int32) : Int32
      n + @border_size
    end

    def screen_ypos(n : Int32) : Int32
      n + @border_size + @title_lines
    end

    def wrefresh(win : NCurses::Window? = nil)
      w = win || @win
      CDK::Screen.wrefresh(w.not_nil!) if w
    end
  end
end
