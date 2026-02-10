module CDK
  module Formattable
    property skip_formatting : Bool = false

    def skip_formatting? : Bool
      @skip_formatting
    end
  end
end
