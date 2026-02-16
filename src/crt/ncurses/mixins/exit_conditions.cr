module CRT::Ncurses
  module ExitConditions
    property exit_type : CRT::Ncurses::ExitType = CRT::Ncurses::ExitType::NEVER_ACTIVATED

    def init_exit_conditions
      @exit_type = CRT::Ncurses::ExitType::NEVER_ACTIVATED
    end

    def set_exit_type(ch : Int32)
      case ch
      when CRT::Ncurses::KEY_ESC
        @exit_type = CRT::Ncurses::ExitType::ESCAPE_HIT
      when CRT::Ncurses::KEY_TAB, LibNCurses::Key::Enter.value, CRT::Ncurses::KEY_RETURN
        @exit_type = CRT::Ncurses::ExitType::NORMAL
      when NCurses::ERR
        @exit_type = CRT::Ncurses::ExitType::TIMEOUT
      when 0
        @exit_type = CRT::Ncurses::ExitType::EARLY_EXIT
      end
    end

    def reset_exit_type
      @exit_type = CRT::Ncurses::ExitType::NEVER_ACTIVATED
    end
  end
end
