require 'main'
require 'readorder/runner'

module Readorder
  Cli = Main.create {
    author "Copyright 2009 (c) Jeremy Hinegardner"
    version ::Readorder::VERSION

    description <<-txt
    Readorder orders a list of files into a more efficient read order.

    Given a list of filenames, either on the command line or via stdin,
    output the filenames in an order that should increase the I/O 
    throughput when the contents files are read from disc.
    txt

    run { help! }

    ## --- Modes -- 
    ## Default mode is sort, which is when no mode is given

    mode( :sort ) {
      description <<-txt
      Given a list of filenames, either on the command line or via stdin,
      output the filenames in an order that should increase the I/O 
      throughput when the contents files are read from disc.
      txt

      option( 'inode' ) {
        description "Only use inode order do not attempt physical block order"
        cast :boolean
      }

      mixin :option_log_level
      mixin :option_log_file
      mixin :argument_filelist
      mixin :option_output
      mixin :option_error_filelist

      run { Cli.run_command_with_params( 'sort', params ) }
    }

    mode( :analyze ) {
      description <<-txt
      Take the list of filenames and output an analysis of the volume of
      data in those files.
      txt

      mixin :option_log_level
      mixin :option_log_file
      mixin :argument_filelist
      mixin :option_output
      mixin :option_error_filelist

      option( 'data-csv' ) {
        description "Write the raw data collected to this csv file"
        argument :required
        validate { |f| File.directory?( File.dirname(File.expand_path( f ) ) ) }
      }
      
      run { Cli.run_command_with_params( 'analyze', params ) }
    }

    mode( :test ) {
      description <<-txt
      Give a list of filenames, either on the commandline or via stdin, 
      take a random subsample of them and read all the contents of those
      files in different orders.

      1) in initial given order
      2) in inode order
      3) in physical block order

      Output a report of the various times take to read the files.

      This command requires elevated priveleges to run and will spike the 
      I/O of your machine.  Run with care.
      txt
      option( :percentage ) {
        description "What random percentage of input files to select"
        argument :required
        default "10"
        validate { |p| 
          pi = Float(p).to_i
          (pi > 0) and (pi <= 100)
        }
        cast :int
      }
      mixin :option_log_level
      mixin :option_log_file
      mixin :argument_filelist
      mixin :option_error_filelist

      run { Cli.run_command_with_params( 'test', params ) }
    }

    ## --- Mixins --- 
    mixin :argument_filelist do
      argument('filelist') {
        description "The files containing filenames"
        arity '*'
        default [ $stdin ]
        required false
      }
    end

    mixin :option_log_level do
      option( 'log-level' ) do
        description "The verbosity of logging, one of [ #{::Logging::LNAMES.map {|l| l.downcase }.join(', ')} ]"
        argument :required
        default 'info'
        validate { |l| %w[ debug info warn error fatal off ].include?( l.downcase ) }
      end
    end

    mixin :option_log_file do
      option( 'log-file' ) do
        description "Log to this file instead of stderr"
        argument :required
        validate { |f| File.directory?( File.dirname(File.expand_path( f ) ) ) }
      end
    end

    mixin :option_output do
      option( 'output' ) do
        description "Where to write the output"
        argument :required
        validate { |f| File.directory?( File.dirname(File.expand_path( f ) ) ) }
      end
    end

    mixin :option_error_filelist do
      option('error-filelist') do
        description "Write all the files from the filelist that had errors to this file"
        argument :required
        validate { |f| File.directory?( File.dirname(File.expand_path( f ) ) ) }
      end
    end
  } 


  # 
  # Convert the Parameters::List that exists as the parameter from Main
  #
  #
  def Cli.params_to_hash( params )
    (hash = params.to_hash ).keys.each do |key| 
      v = hash[key].values
      v = v.first if v.size <= 1
      hash[key] = v
    end
    return hash
  end

  def Cli.run_command_with_params( command, params )
    ::Readorder::Runner.new( Cli.params_to_hash( params ) ).run( command )
  end
end
