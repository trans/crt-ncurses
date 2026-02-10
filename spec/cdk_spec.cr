require "./spec_helper"

describe CDK do
  it "has a version" do
    CDK::VERSION.should eq("0.1.0")
  end

  describe CDK::Display do
    it "identifies hidden display types" do
      CDK::Display.hidden_display_type?(CDK::DisplayType::HCHAR).should be_true
      CDK::Display.hidden_display_type?(CDK::DisplayType::CHAR).should be_false
    end
  end

  describe "constants" do
    it "defines position constants" do
      CDK::LEFT.should eq(9000)
      CDK::RIGHT.should eq(9001)
      CDK::CENTER.should eq(9002)
      CDK::TOP.should eq(9003)
      CDK::BOTTOM.should eq(9004)
    end

    it "defines orientation constants" do
      CDK::HORIZONTAL.should eq(9005)
      CDK::VERTICAL.should eq(9006)
      CDK::FULL.should eq(9007)
    end

    it "defines key constants" do
      CDK::KEY_ESC.should eq(27)
      CDK::KEY_TAB.should eq(9)
      CDK::KEY_RETURN.should eq(10)
    end

    it "computes ctrl keys" do
      CDK.ctrl('L').should eq(12)
      CDK.ctrl('A').should eq(1)
    end
  end

  describe "helper types" do
    it "checks digit characters" do
      CDK.digit?('5').should be_true
      CDK.digit?('a').should be_false
    end

    it "checks alpha characters" do
      CDK.alpha?('a').should be_true
      CDK.alpha?('5').should be_false
    end
  end

  describe "set_widget_dimension" do
    it "returns parent dim for FULL" do
      CDK.set_widget_dimension(80, CDK::FULL, 0).should eq(80)
    end

    it "returns parent dim for zero" do
      CDK.set_widget_dimension(80, 0, 0).should eq(80)
    end

    it "returns proposed dim for positive value" do
      CDK.set_widget_dimension(80, 40, 0).should eq(40)
    end

    it "clamps to parent for oversized value" do
      CDK.set_widget_dimension(80, 100, 0).should eq(80)
    end

    it "handles negative dimension" do
      CDK.set_widget_dimension(80, -10, 0).should eq(70)
    end
  end
end
