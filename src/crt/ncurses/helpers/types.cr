module CRT::Ncurses
  def self.digit?(character : Char) : Bool
    character.ascii_number?
  end

  def self.alpha?(character : Char) : Bool
    character.ascii_letter?
  end

  def self.is_char?(c : Int32) : Bool
    c >= 0 && c < LibNCurses::Key::Down.value
  end
end
