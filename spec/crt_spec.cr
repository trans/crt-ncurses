require "./spec_helper"

describe CRT do
  it "has a version" do
    CRT::VERSION.should eq("0.1.0")
  end

  describe CRT::Display do
    it "identifies hidden display types" do
      CRT::Display.hidden_display_type?(CRT::DisplayType::HCHAR).should be_true
      CRT::Display.hidden_display_type?(CRT::DisplayType::CHAR).should be_false
    end
  end

  describe "constants" do
    it "defines position constants" do
      CRT::LEFT.should eq(9000)
      CRT::RIGHT.should eq(9001)
      CRT::CENTER.should eq(9002)
      CRT::TOP.should eq(9003)
      CRT::BOTTOM.should eq(9004)
    end

    it "defines direction enum" do
      CRT::HORIZONTAL.should eq(CRT::Direction::Horizontal)
      CRT::VERTICAL.should eq(CRT::Direction::Vertical)
    end

    it "defines position enum" do
      CRT::Position::Left.value.should eq(9000)
      CRT::Position::Right.value.should eq(9001)
      CRT::Position::Center.value.should eq(9002)
      CRT::Position::Top.value.should eq(9003)
      CRT::Position::Bottom.value.should eq(9004)
      CRT::Position::Full.value.should eq(9007)
    end

    it "defines dominant enum" do
      CRT::Dominant::None.value.should eq(0)
      CRT::Dominant::Row.value.should eq(1)
      CRT::Dominant::Col.value.should eq(2)
    end

    it "defines key constants" do
      CRT::KEY_ESC.should eq(27)
      CRT::KEY_TAB.should eq(9)
      CRT::KEY_RETURN.should eq(10)
    end

    it "computes ctrl keys" do
      CRT.ctrl('L').should eq(12)
      CRT.ctrl('A').should eq(1)
    end
  end

  describe "helper types" do
    it "checks digit characters" do
      CRT.digit?('5').should be_true
      CRT.digit?('a').should be_false
    end

    it "checks alpha characters" do
      CRT.alpha?('a').should be_true
      CRT.alpha?('5').should be_false
    end
  end

  describe "set_widget_dimension" do
    it "returns parent dim for FULL" do
      CRT.set_widget_dimension(80, CRT::FULL, 0).should eq(80)
    end

    it "returns parent dim for zero" do
      CRT.set_widget_dimension(80, 0, 0).should eq(80)
    end

    it "returns proposed dim for positive value" do
      CRT.set_widget_dimension(80, 40, 0).should eq(40)
    end

    it "clamps to parent for oversized value" do
      CRT.set_widget_dimension(80, 100, 0).should eq(80)
    end

    it "handles negative dimension" do
      CRT.set_widget_dimension(80, -10, 0).should eq(70)
    end
  end
end
