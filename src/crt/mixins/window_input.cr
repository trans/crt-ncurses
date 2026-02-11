module CRT
  # TODO: Consider adding before/after input hooks (e.g., `before_input { }`,
  # `after_input { }`) for running callbacks around each keypress cycle.
  # Could complement `on_key` for cross-cutting concerns like logging or
  # input transformation.

  module WindowInput
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
        ch = CRT::KEY_TAB
      when CRT::DELETE
        ch = LibNCurses::Key::Delete.value
      when '\b'.ord
        ch = LibNCurses::Key::Backspace.value
      when CRT::BEGOFLINE
        ch = LibNCurses::Key::Home.value
      when CRT::ENDOFLINE
        ch = LibNCurses::Key::End.value
      when CRT::FORCHAR
        ch = LibNCurses::Key::Right.value
      when CRT::BACKCHAR
        ch = LibNCurses::Key::Left.value
      when CRT::NEXT
        ch = CRT::KEY_TAB
      when CRT::PREV
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
