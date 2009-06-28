require 'rubygems'
require 'spec'

$: << File.expand_path(File.join(File.dirname(__FILE__),"..","lib"))
require 'readorder'

Logging::Logger['Readorder'].level = :all
module Spec
  module Log
    def self.io
      @io ||= StringIO.new
    end
    def self.appender
      @appender ||= Logging::Appenders::IO.new( "speclog", io )
    end

    Logging::Logger['Readorder'].add_appenders( Log.appender )

    def self.layout
      @layout ||= Logging::Layouts::Pattern.new(
        :pattern      => "[%d] %5l %6p %c : %m\n",
        :date_pattern => "%Y-%m-%d %H:%M:%S"
      )
    end

    Log.appender.layout = layout

  end

  module Helpers
    require 'tmpdir'
    def make_temp_dir( unique_id = $$ )
      dirname = File.join( Dir.tmpdir, "snipe-#{unique_id}" ) 
      FileUtils.mkdir_p( dirname ) unless File.directory?( dirname )
      return dirname
    end

    # the logging output from the test, if that class has any logging
    def spec_log
      Log.io.string
    end
  end
end

Spec::Runner.configure do |config|
  config.include Spec::Helpers

  config.before do
    Spec::Log.io.rewind
    Spec::Log.io.truncate( 0 )
  end

  config.after do
    Spec::Log.io.rewind
    Spec::Log.io.truncate( 0 )
  end
end
