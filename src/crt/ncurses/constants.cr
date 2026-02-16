module CRT
  CRT_PATHMAX = 256

  # Direction for drawing operations
  enum Direction
    Horizontal
    Vertical
  end

  # Position/alignment for widget placement and configuration
  enum Position
    Left   = 9000
    Right  = 9001
    Center = 9002
    Top    = 9003
    Bottom = 9004
    Full   = 9007
  end

  # Dominant dimension for matrix navigation
  enum Dominant
    None
    Row
    Col
  end

  # Direction convenience constants
  HORIZONTAL = Direction::Horizontal
  VERTICAL   = Direction::Vertical

  # TODO: Replace these Int32 convenience constants with `Int32 | Position` union
  # types on constructor x/y params and other mixed-use sites, so users pass
  # `Position::Left` directly instead of relying on sentinel values.
  LEFT   = Position::Left.value
  RIGHT  = Position::Right.value
  CENTER = Position::Center.value
  TOP    = Position::Top.value
  BOTTOM = Position::Bottom.value
  FULL   = Position::Full.value

  MAX_ITEMS    = 2000
  MAX_BUTTONS  = 200

  def self.ctrl(c : Char) : Int32
    c.ord & 0x1f
  end

  REFRESH   = ctrl('L')
  PASTE     = ctrl('V')
  COPY      = ctrl('Y')
  ERASE     = ctrl('U')
  CUT       = ctrl('X')
  BEGOFLINE = ctrl('A')
  ENDOFLINE = ctrl('E')
  BACKCHAR  = ctrl('B')
  FORCHAR   = ctrl('F')
  TRANSPOSE = ctrl('T')
  NEXT      = ctrl('N')
  PREV      = ctrl('P')
  DELETE    = 127 # "\177".ord
  KEY_ESC   =  27 # "\033".ord
  KEY_RETURN = 10 # "\012".ord
  KEY_TAB   =   9 # "\t".ord

  def self.key_f(n : Int32) : Int32
    264 + n
  end

  enum DisplayType
    CHAR
    HCHAR
    INT
    HINT
    MIXED
    HMIXED
    UCHAR
    LCHAR
    UHCHAR
    LHCHAR
    UMIXED
    LMIXED
    UHMIXED
    LHMIXED
    VIEWONLY
    INVALID
  end

  enum HistViewType
    NONE
    PERCENT
    FRACTION
    REAL
  end

  enum ExitType
    NEVER_ACTIVATED
    NORMAL
    ESCAPE_HIT
    EARLY_EXIT
    TIMEOUT
    ERROR
  end
end
