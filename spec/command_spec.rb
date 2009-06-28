require File.expand_path( File.join( File.dirname( __FILE__ ),"spec_helper.rb"))

require 'readorder/command'

class Readorder::Junk < Readorder::Command; end

describe Readorder::Command do
  before( :each ) do
    @cmd = Readorder::Command.new
  end

  it "has a command name" do
    @cmd.command_name.should == "command"
  end

  it "can log" do
    @cmd.logger.info "this is a log statement"
    spec_log.should =~ /this is a log statement/
  end

  it "cannot be run" do
    lambda { @cmd.run }.should raise_error( Readorder::Command::Error, /Unknown command `command`/ )
  end

  it "registers inherited classes" do
    Readorder::Command.commands.should be_include( Readorder::Junk )
    Readorder::Command.commands.delete( Readorder::Junk )
    Readorder::Command.commands.should_not be_include(Readorder::Junk)
  end

  it "classes cannot be run without implementing 'run'" do
    j = Readorder::Junk.new
    j.respond_to?(:run).should == true
    lambda { j.run }.should raise_error( Readorder::Command::Error, /Unknown command `junk`/)
  end

end
