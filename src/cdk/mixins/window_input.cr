module CDK
  module WindowInput
    property pre_process_func : Proc(Nil)? = nil
    property pre_process_data : Nil = nil
    property post_process_func : Proc(Nil)? = nil
    property post_process_data : Nil = nil

    def inject(a)
    end

    def set_pre_process(fn : Proc(Nil), data = nil)
      @pre_process_func = fn
      @pre_process_data = data
    end

    def set_post_process(fn : Proc(Nil), data = nil)
      @post_process_func = fn
      @post_process_data = data
    end

    def getc : Int32
      return -1 unless input_win = @input_window
      result = input_win.get_char
      ch = case result
           when Char
             result.ord
           when NCurses::Key
             result.value
           else
             -1 # ERR
           end

      # Map common keys
      case ch
      when '\r'.ord, '\n'.ord
        ch = LibNCurses::Key::Enter.value
      when '\t'.ord
        ch = CDK::KEY_TAB
      when CDK::DELETE
        ch = LibNCurses::Key::Delete.value
      when '\b'.ord
        ch = LibNCurses::Key::Backspace.value
      when CDK::BEGOFLINE
        ch = LibNCurses::Key::Home.value
      when CDK::ENDOFLINE
        ch = LibNCurses::Key::End.value
      when CDK::FORCHAR
        ch = LibNCurses::Key::Right.value
      when CDK::BACKCHAR
        ch = LibNCurses::Key::Left.value
      when CDK::NEXT
        ch = CDK::KEY_TAB
      when CDK::PREV
        ch = LibNCurses::Key::ShiftTab.value
      end

      ch
    end

    def getch(function_key : Array(Bool)) : Int32
      key = self.getc
      function_key << (key >= LibNCurses::Key::Down.value)
      key
    end
  end
end
