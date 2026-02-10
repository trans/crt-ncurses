module CDK
  module ExitConditions
    property exit_type : CDK::ExitType = CDK::ExitType::NEVER_ACTIVATED

    def init_exit_conditions
      @exit_type = CDK::ExitType::NEVER_ACTIVATED
    end

    def set_exit_type(ch : Int32)
      case ch
      when CDK::KEY_ESC
        @exit_type = CDK::ExitType::ESCAPE_HIT
      when CDK::KEY_TAB, LibNCurses::Key::Enter.value, CDK::KEY_RETURN
        @exit_type = CDK::ExitType::NORMAL
      when NCurses::ERR
        @exit_type = CDK::ExitType::TIMEOUT
      when 0
        @exit_type = CDK::ExitType::EARLY_EXIT
      end
    end

    def reset_exit_type
      @exit_type = CDK::ExitType::NEVER_ACTIVATED
    end
  end
end
