require 'hitimes'
require 'readorder/datum'
require 'rbtree'

module Readorder
  #
  # Use the given Filelist and traverse all the file collecting the
  # appropriate Datum instances
  #
  class Analyzer
    #
    # Initialize the Analyzer with the Filelist object and whether or
    # not to gather the physical block size.
    #
    attr_accessor :bad_data
    attr_accessor :good_data

    def initialize( filelist, get_physical = true )
      @filelist = filelist
      @good_data = ::MultiRBTree.new
      @bad_data = []
      @get_physical = get_physical
      @size_metric = ::Hitimes::ValueMetric.new( 'size' )
      @time_metric = ::Hitimes::TimedMetric.new( 'time' )
    end

    def logger
      ::Logging::Logger[self]
    end

    def collect_data
      logger.info "Begin data collection"
      @filelist.each_line do |fname|

        #logger.debug "  analyzing #{fname.strip}"

        @time_metric.measure do
          d = Datum.new( fname )
          d.collect( @get_physical )
          if d.valid? then
            @size_metric.measure d.stat.size
            key = (@get_physical ? d.first_physical_block_number : d.inode_number)
            @good_data[key] = d
          else
            @bad_data << d
          end
        end

        if @time_metric.count % 10_000 == 0 then
          logger.info "  processed #{@time_metric.count} at #{"%0.3f" % @time_metric.rate} files/sec"
        end

      end
      logger.info "End data collection" 
      nil
    end

    def log_summary_report
      summary_report.split("\n").each do |l|
        logger.info l
      end
    end

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

    def dump_bad_data_to( io )
      if bad_data.size > 0 then
        io.puts "error_reason,filename"
        bad_data.each do |d|
          io.puts "#{d.error_reason},#{d.filename}"
        end
      end
    end


    def dump_good_data_to( io )
      fields = %w[ filename size inode_number ]
      if @get_physical then
        fields << 'block_count'
        fields << 'first_physical_block_number'
      end

      io.puts fields.join(",")
      good_data.values.each do |d|
        f = fields.collect { |f| d.send( f ) }
        io.puts f.join(",")
      end
    end
  end
end
