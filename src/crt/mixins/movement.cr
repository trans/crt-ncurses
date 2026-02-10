module CRT
  module Movement
    def move(xplace : Int32, yplace : Int32, relative : Bool, refresh_flag : Bool)
      move_specific(xplace, yplace, relative, refresh_flag,
        [win].compact, [] of CRT::CRTObjs)
    end

    def move_specific(xplace : Int32, yplace : Int32, relative : Bool, refresh_flag : Bool,
                      windows : Array(NCurses::Window), subwidgets : Array(CRT::CRTObjs))
      return unless w = @win
      current_x = 0 # will use window position
      current_y = 0
      xpos = xplace
      ypos = yplace

      if relative
        xpos = xplace
        ypos = yplace
      end

      # Adjust the window if we need to
      if scr = @screen
        if scr_win = scr.window
          xtmp = [xpos]
          ytmp = [ypos]
          alignxy(scr_win, xtmp, ytmp, @box_width, @box_height)
          xpos = xtmp[0]
          ypos = ytmp[0]
        end
      end

      # Move the window to the new location.
      windows.each do |window|
        CRT.move_curses_window(window, xpos, ypos)
      end

      # Touch/refresh the screen
      if scr = @screen
        if scr_win = scr.window
          CRT::Screen.refresh_cdk_window(scr_win)
        end
      end

      # Redraw the window if requested
      if refresh_flag
        self.draw(@box)
      end
    end

    def position(win : NCurses::Window)
      # Interactive positioning via cursor keys - simplified
    end
  end
end
