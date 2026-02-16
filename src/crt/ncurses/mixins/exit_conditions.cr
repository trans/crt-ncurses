module CRT
  module ExitConditions
    property exit_type : CRT::ExitType = CRT::ExitType::NEVER_ACTIVATED

    def init_exit_conditions
      @exit_type = CRT::ExitType::NEVER_ACTIVATED
    end

    def set_exit_type(ch : Int32)
      case ch
      when CRT::KEY_ESC
        @exit_type = CRT::ExitType::ESCAPE_HIT
      when CRT::KEY_TAB, LibNCurses::Key::Enter.value, CRT::KEY_RETURN
        @exit_type = CRT::ExitType::NORMAL
      when NCurses::ERR
        @exit_type = CRT::ExitType::TIMEOUT
      when 0
        @exit_type = CRT::ExitType::EARLY_EXIT
      end
    end

    def reset_exit_type
      @exit_type = CRT::ExitType::NEVER_ACTIVATED
    end
  end
end
