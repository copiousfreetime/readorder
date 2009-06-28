require File.expand_path( File.join( File.dirname( __FILE__ ),"spec_helper.rb"))

require 'readorder/runner'

class Readorder::Junk4Runner < Readorder::Command
  def self.command_name
    'junk4runner'
  end

  def run
    logger.info "doing junk, as instructed #{options['foo']}"
    if options['boom'] then
      raise options['boom']
    end
  end
end

describe Readorder::Runner do
  before(:each) do
    @old_level = ::Readorder::Log.console
    ::Readorder::Log.console = :off
  end

  after(:each) do
    ::Readorder::Log.console = @old_level
  end

  it "can log" do
    r = Readorder::Runner.new
    r.logger.info "log statement from Runner"
    spec_log.should =~ /log statement from Runner/
  end

  it "runs a command" do
    r = Readorder::Runner.new( "foo" => "bar" )
    r.run( 'junk4runner' )
    spec_log.should =~ /doing junk, as instructed bar/
  end

  it "logs an exception raised by a Command" do
    r = Readorder::Runner.new( 'boom' => 'a big kaboom!' )
    r.run( 'junk4runner' )
    spec_log.should =~ /doing junk, as instructed/
    spec_log.should =~ /a big kaboom!/
  end
end
