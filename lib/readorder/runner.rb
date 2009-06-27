require 'readorder/log'
require 'readorder/command'

module Readorder
  class Runner
    attr_reader :options

    def initialize( opts = {} )
      @options = opts.dup
      initialize_logging
    end

    def logger
      @logger ||= ::Logging::Logger[self]
    end

    def setup_signal_handling( cmd )
      %w[ INT QUIT TERM ].each do |s|
        Signal.trap( s ) do
          logger.info "received signal #{s} -- shutting down"
          cmd.shutdown
          exit 1
        end
      end
    end

    def initialize_logging
      Readorder::Log.init( options )
    end

    def run( command_name )
      cmd = Command.find( command_name ).new( @options )
      begin
        setup_signal_handling( cmd )
        cmd.before
        cmd.run
      rescue => e
        logger.error "while running #{command_name} : #{e.message}"
        e.backtrace.each do |l|
          logger.debug l
        end
        cmd.error
      ensure
        cmd.after
      end
    end
  end
end
