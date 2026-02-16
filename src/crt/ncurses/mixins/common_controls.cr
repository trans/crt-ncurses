module CRT
  module CommonControls
    property quit_on_enter : Bool = true

    def quit_on_enter? : Bool
      @quit_on_enter
    end
  end
end
