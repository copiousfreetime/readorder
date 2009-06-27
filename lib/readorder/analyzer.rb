require 'hitimes'
require 'readorder/datum'
require 'rbtree'

module Readorder
  #
  # Use the given Filelist and traverse all the file collecting the
  # appropriate Datum instances
  #
  class Analyzer
    # an Array of Datum instances for files that cannot be processed
    attr_accessor :bad_data

    # an Array of Datum instances in the order they were processed
    attr_accessor :good_data

    # an RBTree of Datum instances of those files that were analyzed
    # in order by phyiscal disc block number.  This only has items if 
    # the physical block number was obtained.  It is empty otherwise
    attr_accessor :physical_order

    # an RBTree of Datum instances of those files that were analyzed
    # in order by inode
    attr_accessor :inode_order

    #
    # Initialize the Analyzer with the Filelist object and whether or
    # not to gather the physical block size.
    #
    def initialize( filelist, get_physical = true )
      @filelist          = filelist
      @bad_data          = []
      @good_data         = []
      @physical_order    = ::MultiRBTree.new
      @inode_order       = ::MultiRBTree.new
      @get_physical      = get_physical
      @size_metric       = ::Hitimes::ValueMetric.new( 'size' )
      @time_metric       = ::Hitimes::TimedMetric.new( 'time' )
    end

    # 
    # call-seq:
    #   analyzer.logger -> Logger
    #   
    # return the Logger instance for the Analyzer
    #
    def logger
      ::Logging::Logger[self]
    end

    # 
    # call-seq:
    #   analyzer.collect_data -> nil
    #
    # Run data collections over the Filelist and store the results into
    # *good_data* or *bad_data* as appropriate.  A status message is written to the
    # log every 10,000 files processed
    #
    def collect_data
      logger.info "Begin data collection"
      original_order = 0
      @filelist.each_line do |fname|
        #logger.debug "  analyzing #{fname.strip}"
        @time_metric.measure do
          d = Datum.new( fname )
          d.collect( @get_physical )
          d.original_order = original_order
          if d.valid? then
            @good_data << d
            @size_metric.measure d.stat.size
            @inode_order[d.inode_number] = d
            if @get_physical then
              @physical_order[d.first_physical_block_number] = d
            end
          else
            @bad_data << d
          end
        end

        if @time_metric.count % 10_000 == 0 then
          logger.info "  processed #{@time_metric.count} at #{"%0.3f" % @time_metric.rate} files/sec"
        end
        original_order += 1
      end
      logger.info "  processed #{@time_metric.count} at #{"%0.3f" % @time_metric.rate} files/sec"
      logger.info "  yielded #{@good_data.size} data points"
      logger.info "End data collection" 
      nil
    end

    #
    # call-seq:
    #   analyzer.log_summary_report -> nil
    #
    # Write the summary report to the #logger
    #
    def log_summary_report
      summary_report.split("\n").each do |l|
        logger.info l
      end
    end

    # 
    # call-seq: 
    #   analyzer.summary_report -> String
    #
    # Generate a summary report of how long it took to analyze the files and the
    # filesizes found.  return it as a String
    #
    def summary_report
      s = StringIO.new
      s.puts "Files analyzed   : #{"%12d" % @time_metric.count}"
      s.puts "Elapsed time     : #{"%12d" % @time_metric.duration} seconds"
      s.puts "Collection Rate  : #{"%16.3f" % @time_metric.rate} files/sec"
      s.puts "Good files       : #{"%12d" % @good_data.size}"
      s.puts "  average size   : #{"%16.3f" % @size_metric.mean} bytes"
      s.puts "  minimum size   : #{"%16.3f" % @size_metric.min} bytes"
      s.puts "  maximum size   : #{"%16.3f" % @size_metric.max} bytes"
      s.puts "  sum of sizes   : #{"%12d" % @size_metric.sum} bytes"
      s.puts "Bad files        : #{"%12d" % @bad_data.size}"
      return s.string
    end

    #
    # call-seq:
    #   analyzer.dump_data_to( IO ) -> nil
    #
    # write a csv to the _IO_ object passed in.  The format is:
    #
    #   error reason,filename
    #
    # If there are no bad Datum instances then do not write anything.
    #
    def dump_bad_data_to( io )
      if bad_data.size > 0 then
        io.puts "error_reason,filename"
        bad_data.each do |d|
          io.puts "#{d.error_reason},#{d.filename}"
        end
      end
      nil
    end


    # 
    # call-seq:
    #   analyzer.dump_good_data_to( IO ) -> nil
    #
    # Write a csv fo the _IO_ object passed in.  The format is:
    #
    #   filename,size,inode_number,physical_block_count,first_physical_block_number
    #
    # The last two fields *physical_block_count* and *first_physical_block_number* are
    # only written if the analyzer was able to gather physical block information
    #
    def dump_good_data_to( io )
      fields = %w[ filename size inode_number ]
      if @get_physical then
        fields << 'physical_block_count'
        fields << 'first_physical_block_number'
      end

      io.puts fields.join(",")
      good_data.each do |d|
        f = fields.collect { |f| d.send( f ) }
        io.puts f.join(",")
      end
    end
  end
end
