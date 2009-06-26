require File.expand_path(File.join(File.dirname(__FILE__),"spec_helper.rb"))

describe "Readorder::Version" do

  it "should have a version string" do
    Readorder::Version.to_s.should =~ /\d+\.\d+\.\d+/
    Readorder::VERSION.should =~ /\d+\.\d+\.\d+/
  end

  it "should have a version hash" do
    h = Readorder::Version.to_hash
    [ :major, :minor, :build ].each do |k|
      h[k].should_not be_nil
    end
  end
end
