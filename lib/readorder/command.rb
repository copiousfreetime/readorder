require 'readorder'

module Readorder
  # The Command is the base class for any class that wants to implement a
  # command line command for 
  #
  # Inheriting from this calss will make the class registered and be available
  # for invocation from the Runner class
  #
  # The lifecycle of a command is:
  #
  #   1) instantiation with a hash parameter
  #   2) before
  #   3) run
  #   4) after
  #   5) error calld if the runner catches and exception from the command
  #
  class Command
    class Error < ::Readorder::Error ; end

    def self.command_name
      name.split("::").last.downcase
    end

    attr_reader :options
    attr_reader :filelist
    attr_reader :analyzer
    attr_reader :output

    def initialize( opts = {} )
      @options = opts
      @filelist = nil
      @analyzer = nil
      @output = nil
    end

    def filelist
      unless @filelist then
        begin
          @filelist = Filelist.new( @options['filelist'] )
        rescue => fe
          msg = "Invalid file list.  The list of files containing filenames should be given on the commandline, or filenames should be sent in on stdin."
          raise Error, msg
        end
      end
      return @filelist
    end

    def analyzer
      @analyzer ||= Analyzer.new( filelist, self.results, self.get_physical? )
    end

    def results_dbfile
      if options['output'] then
        output_dname = File.dirname( options['output'] )
        output_bname = File.basename( options['output'], '.*' )
        return File.join( output_dname, "#{output_bname}.db" )
      else 
        return ":memory:"
      end
    end

    def results
      @results ||= Results.new( results_dbfile )
    end

    def output
      unless @output then
        if options['output'] then
          logger.info "output going to #{options['output']}"
          @output = File.open( options['output'] , "w+" )
        else
          @output = $stdout
        end
      end
      return @output
    end


    def get_physical?
      return false if @options['inode']
      unless Datum.is_linux? then
        logger.warn "unable to get physical block number, this is not a linux machine, it is #{Config::CONFIG['host_os']}"
        return false
      end
      unless Process.euid == 0 then
        logger.warn "no permissions to get physical block number, try running as root."
        return false
      end
      return true
    end

    def command_name
      self.class.command_name
    end

    def logger
      ::Logging::Logger[self]
    end

    # called by the Runner before the command, this can be used to setup
    # additional items for the command
    def before() ; end

    # called by the Runner to execute the command
    def run
      raise Error, "Unknown command `#{command_name}`"
    end 

    # called by the Runner if an error is encountered during the run method
    def error() 
      results.close
    end

    # called by runner if a signal is hit
    def shutdown() 
      results.close
    end

    # called by runner when all is done
    def after() 
      if options['error-filelist'] then
        if analyzer.bad_data_count > 0 then
          File.open( options['error-filelist'], "w+" ) do |f|
            analyzer.dump_bad_data_to( f )
          end
          logger.info "wrote error filelist to #{options['error-filelist']}"
        end
      end

      if output != $stdout then
        output.close
        results.close
        File.ulink( results_dbfile )
      end
    end

    class << self
      # this method is invoked by the Ruby interpreter whenever a class inherts
      # from Command.  This is how commands register to be invoked
      #
      def inherited( klass )
        return unless klass.instance_of? Class
        return if commands.include? klass
        commands << klass
      end

      # The list of commands registered.
      #
      def commands
        unless defined? @commands
          @commands = []
        end
        return @commands
      end

      # get the command klass for the given name
      def find( name )
        @commands.find { |klass| klass.command_name == name }
      end

    end
  end
end

require 'readorder/commands/sort'
require 'readorder/commands/analyze'
require 'readorder/commands/test'
