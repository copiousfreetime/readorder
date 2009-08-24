require 'readorder/datum'
require 'readorder/results'

module Readorder
  #
  # Use the given Filelist and traverse all the file collecting the
  # appropriate Datum instances
  #
  class Analyzer
    # number of bad_data items encountered
    attr_accessor :bad_data_count
  
    # number of good_data items encountered
    attr_accessor :good_data_count

    # The Results handler
    attr_accessor :results

    #
    # Initialize the Analyzer with the Filelist object and whether or
    # not to gather the physical block size.
    #
    def initialize( filelist, results, get_physical = true )
      @filelist          = filelist
      @get_physical      = get_physical
      @size_metric       = ::Hitimes::ValueMetric.new( 'size' )
      @time_metric       = ::Hitimes::TimedMetric.new( 'time' )
      @results           = results
      @bad_data_count    = 0
      @good_data_count   = 0
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
        next if @results.has_datum_for_filename?( fname )
        logger.debug "  analyzing #{fname.strip}"
        @time_metric.measure do
          d = Datum.new( fname )
          begin
            d.collect( @get_physical )
            d.original_order = original_order

            @results.add_datum( d )

            if d.valid? then
              @size_metric.measure d.stat.size
              @good_data_count += 1
            else
              @bad_data_count += 1
            end
          rescue => e
            logger.error "#{e} : #{d.to_hash.inspect}"
          end
        end

        if @time_metric.count % 10_000 == 0 then
          logger.info "  processed #{@time_metric.count} at #{"%0.3f" % @time_metric.rate} files/sec ( #{@good_data_count} good, #{@bad_data_count} bad )"
        end
        original_order += 1
      end
      @results.flush
      logger.info "  processed #{@time_metric.count} at #{"%0.3f" % @time_metric.rate} files/sec"
      logger.info "  yielded #{@good_data_count} data points"
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
      s.puts "Good files       : #{"%12d" % @good_data_count}"
      s.puts "  average size   : #{"%16.3f" % @size_metric.mean} bytes"
      s.puts "  minimum size   : #{"%16.3f" % @size_metric.min} bytes"
      s.puts "  maximum size   : #{"%16.3f" % @size_metric.max} bytes"
      s.puts "  sum of sizes   : #{"%12d" % @size_metric.sum} bytes"
      s.puts "Bad files        : #{"%12d" % @bad_data_count}"
      return s.string
    end

    #
    # call-seq:
    #   analyzer.dump_errors_to( IO ) -> nil
    #
    # write a csv to the _IO_ object passed in.  The format is:
    #
    #   error_reason,filename
    #
    # If there are no bad Datum instances then do not write anything.
    #
    def dump_errors_to( io )
      if results.error_count > 0 then
        io.puts "error_reason,filename"
        results.each_error do |d|
          io.puts "#{d['error_reason']},#{d['filename']}"
        end
      end
      nil
    end


    # 
    # call-seq:
    #   analyzer.dump_valid_to( IO ) -> nil
    #
    # Write a csv fo the _IO_ object passed in.  The format is:
    #
    #   filename,size,inode_number,physical_block_count,first_physical_block_number
    #
    # The last two fields *physical_block_count* and *first_physical_block_number* are
    # only written if the analyzer was able to gather physical block information
    #
    def dump_valid_to( io )
      fields = %w[ filename size inode_number ]
      by_field = 'inode_number'
      if @get_physical then
        fields << 'physical_block_count'
        fields << 'first_physical_block_number'
        by_field = 'first_physical_block_number'
      end
      io.puts fields.join(",")
      results.each_valid_by_field( by_field ) do |d|
       f = fields.collect { |f| d[f] }
       io.puts f.join(",")
      end
    end
  end
end
