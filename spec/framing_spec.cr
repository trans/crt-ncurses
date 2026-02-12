require "./spec_helper"

describe CRT::Framing do
  describe "Edge flags enum" do
    it "defaults to None" do
      CRT::Framing::Edge::None.value.should eq(0)
    end

    it "composes with bitwise OR" do
      combined = CRT::Framing::Edge::Left | CRT::Framing::Edge::Right
      combined.left?.should be_true
      combined.right?.should be_true
      combined.up?.should be_false
    end
  end

  describe "#add horizontal line" do
    it "stamps Left+Right on interior cells" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 2, y: 3, h: 5)

      # Left endpoint: only Right
      f.edges_at(2, 3).should eq(CRT::Framing::Edge::Right)
      # Interior: Left+Right
      f.edges_at(3, 3).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
      f.edges_at(4, 3).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
      f.edges_at(5, 3).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
      # Right endpoint: only Left
      f.edges_at(6, 3).should eq(CRT::Framing::Edge::Left)
      # Adjacent cell: empty
      f.edges_at(7, 3).should eq(CRT::Framing::Edge::None)
    end

    it "handles negative h (draws leftward)" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 8, y: 3, h: -5)

      f.edges_at(4, 3).should eq(CRT::Framing::Edge::Right)
      f.edges_at(8, 3).should eq(CRT::Framing::Edge::Left)
      f.edges_at(6, 3).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
    end
  end

  describe "#add vertical line" do
    it "stamps Up+Down on interior cells" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 5, y: 1, v: 4)

      # Top endpoint: only Down
      f.edges_at(5, 1).should eq(CRT::Framing::Edge::Down)
      # Interior: Up+Down
      f.edges_at(5, 2).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
      f.edges_at(5, 3).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
      # Bottom endpoint: only Up
      f.edges_at(5, 4).should eq(CRT::Framing::Edge::Up)
    end

    it "handles negative v (draws upward)" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 5, y: 7, v: -4)

      f.edges_at(5, 4).should eq(CRT::Framing::Edge::Down)
      f.edges_at(5, 7).should eq(CRT::Framing::Edge::Up)
      f.edges_at(5, 5).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
    end
  end

  describe "#add box" do
    it "produces correct corners" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 1, y: 1, h: 5, v: 4)

      # Top-left: Right+Down
      f.edges_at(1, 1).should eq(CRT::Framing::Edge::Right | CRT::Framing::Edge::Down)
      # Top-right: Left+Down
      f.edges_at(5, 1).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Down)
      # Bottom-left: Right+Up
      f.edges_at(1, 4).should eq(CRT::Framing::Edge::Right | CRT::Framing::Edge::Up)
      # Bottom-right: Left+Up
      f.edges_at(5, 4).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Up)
    end

    it "produces hline on top and bottom edges" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 1, y: 1, h: 5, v: 4)

      f.edges_at(3, 1).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
      f.edges_at(3, 4).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
    end

    it "produces vline on left and right edges" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 1, y: 1, h: 5, v: 4)

      f.edges_at(1, 2).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
      f.edges_at(5, 3).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
    end

    it "handles negative h and v" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 8, y: 6, h: -5, v: -4)

      # Box occupies x=4..8, y=3..6
      f.edges_at(4, 3).should eq(CRT::Framing::Edge::Right | CRT::Framing::Edge::Down)
      f.edges_at(8, 3).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Down)
      f.edges_at(4, 6).should eq(CRT::Framing::Edge::Right | CRT::Framing::Edge::Up)
      f.edges_at(8, 6).should eq(CRT::Framing::Edge::Left | CRT::Framing::Edge::Up)
    end
  end

  describe "intersection resolution" do
    it "produces tees where a horizontal line meets box left/right edges" do
      f = CRT::Framing.new(width: 40, height: 20)
      f.add(x: 0, y: 0, h: 20, v: 10)
      f.add(x: 0, y: 5, h: 20)

      # Left edge intersection: LTEE (Up+Down+Right)
      f.edges_at(0, 5).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down | CRT::Framing::Edge::Right)
      # Right edge intersection: RTEE (Up+Down+Left)
      f.edges_at(19, 5).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down | CRT::Framing::Edge::Left)
    end

    it "produces tees where a vertical line meets box top/bottom edges" do
      f = CRT::Framing.new(width: 40, height: 20)
      f.add(x: 0, y: 0, h: 20, v: 10)
      f.add(x: 10, y: 0, v: 10)

      # Top edge intersection: TTEE (Left+Right+Down)
      f.edges_at(10, 0).should eq(
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right | CRT::Framing::Edge::Down)
      # Bottom edge intersection: BTEE (Left+Right+Up)
      f.edges_at(10, 9).should eq(
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right | CRT::Framing::Edge::Up)
    end

    it "produces a cross where two lines intersect" do
      f = CRT::Framing.new(width: 20, height: 20)
      f.add(x: 0, y: 5, h: 15)
      f.add(x: 7, y: 0, v: 12)

      f.edges_at(7, 5).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down |
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
    end

    it "produces tees where two adjacent boxes share an edge" do
      f = CRT::Framing.new(width: 60, height: 20)
      f.add(x: 0, y: 0, h: 20, v: 10)
      f.add(x: 19, y: 0, h: 20, v: 10)

      # Top shared point: TTEE (Left+Right+Down)
      f.edges_at(19, 0).should eq(
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right | CRT::Framing::Edge::Down)
      # Bottom shared point: BTEE (Left+Right+Up)
      f.edges_at(19, 9).should eq(
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right | CRT::Framing::Edge::Up)
      # Middle of shared edge: just VLINE (Up+Down)
      f.edges_at(19, 5).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
    end

    it "produces a cross where horizontal divider crosses shared vertical edge" do
      f = CRT::Framing.new(width: 60, height: 20)
      f.add(x: 0, y: 0, h: 20, v: 10)
      f.add(x: 19, y: 0, h: 20, v: 10)
      f.add(x: 0, y: 5, h: 39)

      # Shared vertical edge at (19, 5): PLUS
      f.edges_at(19, 5).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down |
        CRT::Framing::Edge::Left | CRT::Framing::Edge::Right)
    end
  end

  describe "#remove" do
    it "removes an op and rebuilds the grid" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 0, y: 0, h: 10, v: 5)
      f.add(x: 0, y: 2, h: 10)

      # Before remove: left edge at (0,2) is LTEE
      f.edges_at(0, 2).should eq(
        CRT::Framing::Edge::Up | CRT::Framing::Edge::Down | CRT::Framing::Edge::Right)

      f.remove(x: 0, y: 2, h: 10)

      # After remove: just box left edge (Up+Down)
      f.edges_at(0, 2).should eq(CRT::Framing::Edge::Up | CRT::Framing::Edge::Down)
    end
  end

  describe "#clear" do
    it "resets the grid to empty" do
      f = CRT::Framing.new(width: 20, height: 10)
      f.add(x: 0, y: 0, h: 10, v: 5)
      f.clear
      f.edges_at(0, 0).should eq(CRT::Framing::Edge::None)
      f.edges_at(5, 0).should eq(CRT::Framing::Edge::None)
    end
  end

  describe "bounds clamping" do
    it "clamps lines that extend beyond grid" do
      f = CRT::Framing.new(width: 10, height: 10)
      f.add(x: 8, y: 0, h: 20)

      f.edges_at(9, 0).should_not eq(CRT::Framing::Edge::None)
    end

    it "ignores lines entirely outside the grid" do
      f = CRT::Framing.new(width: 10, height: 10)
      f.add(x: 0, y: 15, h: 5)

      (0...10).each do |x|
        (0...10).each do |y|
          f.edges_at(x, y).should eq(CRT::Framing::Edge::None)
        end
      end
    end
  end

  describe "method chaining" do
    it "returns self from add and remove" do
      f = CRT::Framing.new(width: 20, height: 10)
      result = f.add(x: 0, y: 0, h: 10).add(x: 0, y: 5, h: 10)
      result.should be(f)
    end
  end
end
