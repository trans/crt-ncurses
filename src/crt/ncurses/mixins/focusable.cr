module CRT::Ncurses
  module Focusable
    property has_focus : Bool = true
    property accepts_focus : Bool = false

    def init_focus
      @has_focus = true
      @accepts_focus = false
    end

    def focus
    end

    def unfocus
    end
  end
end
