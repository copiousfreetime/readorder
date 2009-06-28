require 'logging'
require 'readorder'

module Readorder
  ::Logging::Logger[self].level = :info

  def self.logger
    ::Logging::Logger[self]
  end

  module Log
    def self.init( options = {} )
      appender = Logging.appenders.stderr
      appender.layout = self.console_layout
      if options['log-file'] then
        appender = ::Logging::Appenders::File.new(
          'readorder',
          :filename => options['log-file'],
          :layout   => self.layout
        )
      end
      
      Readorder.logger.add_appenders( appender )
      self.level = options['log-level'] || :info
    end
    
    def self.console
      Logging.appenders.stderr.level
    end

    def self.console=( level )
      Logging.appenders.stderr.level = level
    end
    
    def self.level
      ::Logging::Logger[Readorder].level 
    end

    def self.level=( l )
      ::Logging::Logger[Readorder].level = l
    end

    def self.layout
      @layout ||= Logging::Layouts::Pattern.new(
        :pattern      => "[%d] %5l %6p %c : %m\n",
        :date_pattern => "%Y-%m-%d %H:%M:%S"
      )
    end

    def self.console_layout
      @console_layout ||= Logging::Layouts::Pattern.new(
        :pattern      => "%d %5l : %m\n",
        :date_pattern => "%H:%M:%S"
      )
    end

  end
end
