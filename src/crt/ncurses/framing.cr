module CRT::Ncurses
  class Framing
    @[Flags]
    enum Edge
      Up
      Down
      Left
      Right
    end

    record Op, x : Int32, y : Int32, h : Int32 = 0, v : Int32 = 0

    @screen : CRT::Ncurses::Screen?
    @grid : Array(Array(Edge))
    @ops : Array(Op)
    @max_x : Int32
    @max_y : Int32

    def initialize(@screen : CRT::Ncurses::Screen)
      window = @screen.not_nil!.window.not_nil!
      @max_x = window.max_x
      @max_y = window.max_y
      @grid = Array.new(@max_y) { Array.new(@max_x, Edge::None) }
      @ops = [] of Op
    end

    def initialize(*, width : Int32, height : Int32)
      @screen = nil
      @max_x = width
      @max_y = height
      @grid = Array.new(@max_y) { Array.new(@max_x, Edge::None) }
      @ops = [] of Op
    end

    def add(*, x : Int32, y : Int32, h : Int32 = 0, v : Int32 = 0)
      op = Op.new(x: x, y: y, h: h, v: v)
      @ops << op
      apply_op(op)
      self
    end

    def remove(*, x : Int32, y : Int32, h : Int32 = 0, v : Int32 = 0)
      target = Op.new(x: x, y: y, h: h, v: v)
      @ops.delete(target)
      rebuild_grid
      self
    end

    def draw(attr : Int32 = 0)
      screen = @screen
      raise "Cannot draw without a screen" if screen.nil?
      window = screen.window.not_nil!

      @max_y.times do |y|
        @max_x.times do |x|
          edge = @grid[y][x]
          next if edge.none?

          ch = edge_to_acs(edge)
          Draw.mvwaddch(window, y, x, ch | attr) if ch != 0
        end
      end

      CRT::Ncurses::Screen.wrefresh(window)
    end

    def clear
      @ops.clear
      @grid.each { |row| row.fill(Edge::None) }
    end

    def edges_at(x : Int32, y : Int32) : Edge
      if x >= 0 && x < @max_x && y >= 0 && y < @max_y
        @grid[y][x]
      else
        Edge::None
      end
    end

    private def apply_op(op : Op)
      if op.h != 0 && op.v != 0
        apply_box(op.x, op.y, op.h, op.v)
      elsif op.h != 0
        apply_hline(op.x, op.y, op.h)
      elsif op.v != 0
        apply_vline(op.x, op.y, op.v)
      end
    end

    private def apply_hline(x : Int32, y : Int32, h : Int32)
      if h > 0
        x_start = x
        x_end = x + h - 1
      else
        x_start = x + h + 1
        x_end = x
      end

      x_start = x_start.clamp(0, @max_x - 1)
      x_end = x_end.clamp(0, @max_x - 1)

      return if x_start > x_end || y < 0 || y >= @max_y

      (x_start..x_end).each do |cx|
        edges = Edge::None
        edges |= Edge::Right if cx < x_end
        edges |= Edge::Left if cx > x_start
        @grid[y][cx] |= edges
      end
    end

    private def apply_vline(x : Int32, y : Int32, v : Int32)
      if v > 0
        y_start = y
        y_end = y + v - 1
      else
        y_start = y + v + 1
        y_end = y
      end

      y_start = y_start.clamp(0, @max_y - 1)
      y_end = y_end.clamp(0, @max_y - 1)

      return if y_start > y_end || x < 0 || x >= @max_x

      (y_start..y_end).each do |cy|
        edges = Edge::None
        edges |= Edge::Down if cy < y_end
        edges |= Edge::Up if cy > y_start
        @grid[cy][x] |= edges
      end
    end

    private def apply_box(x : Int32, y : Int32, h : Int32, v : Int32)
      if h > 0
        x_left = x
        x_right = x + h - 1
      else
        x_left = x + h + 1
        x_right = x
      end

      if v > 0
        y_top = y
        y_bottom = y + v - 1
      else
        y_top = y + v + 1
        y_bottom = y
      end

      width = x_right - x_left + 1
      height = y_bottom - y_top + 1

      apply_hline(x_left, y_top, width)
      apply_hline(x_left, y_bottom, width)
      apply_vline(x_left, y_top, height)
      apply_vline(x_right, y_top, height)
    end

    private def rebuild_grid
      @grid.each { |row| row.fill(Edge::None) }
      @ops.each { |op| apply_op(op) }
    end

    private def edge_to_acs(edge : Edge) : Int32
      case edge
      when Edge::Left | Edge::Right
        Draw::ACS_HLINE
      when Edge::Up | Edge::Down
        Draw::ACS_VLINE
      when Edge::Right | Edge::Down
        Draw::ACS_ULCORNER
      when Edge::Left | Edge::Down
        Draw::ACS_URCORNER
      when Edge::Right | Edge::Up
        Draw::ACS_LLCORNER
      when Edge::Left | Edge::Up
        Draw::ACS_LRCORNER
      when Edge::Up | Edge::Down | Edge::Right
        Draw::ACS_LTEE
      when Edge::Up | Edge::Down | Edge::Left
        Draw::ACS_RTEE
      when Edge::Left | Edge::Right | Edge::Down
        Draw::ACS_TTEE
      when Edge::Left | Edge::Right | Edge::Up
        Draw::ACS_BTEE
      when Edge::Up | Edge::Down | Edge::Left | Edge::Right
        Draw::ACS_PLUS
      else
        if edge.left? || edge.right?
          Draw::ACS_HLINE
        elsif edge.up? || edge.down?
          Draw::ACS_VLINE
        else
          0
        end
      end
    end
  end
end
