module CDK
  CDK_PATHMAX = 256

  L_MARKER = '<'
  R_MARKER = '>'

  LEFT       = 9000
  RIGHT      = 9001
  CENTER     = 9002
  TOP        = 9003
  BOTTOM     = 9004
  HORIZONTAL = 9005
  VERTICAL   = 9006
  FULL       = 9007

  NONE = 0
  ROW  = 1
  COL  = 2

  MAX_BINDINGS = 300
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
