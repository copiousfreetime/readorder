require File.expand_path( File.join( File.dirname( __FILE__ ),"spec_helper.rb"))

require 'readorder/log'

describe Readorder::Log do
  it "creates its own layout" do
    Readorder::Log.layout.should be_instance_of(Logging::Layouts::Pattern)
  end

  it "can retrieves its level" do
    Readorder::Log.level.should == 0
  end
end
