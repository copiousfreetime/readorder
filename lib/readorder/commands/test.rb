require 'stringio'
module Readorder
  module Commands
    #
    # Test reading all the contents of a subset of the files and report summary
    # information on how long it takes to read the files given different
    # reading orders.
    #
    class Test < ::Readorder::Command

      # 
      # call-seq:
      #   test.before -> nil
      #
      # Part of the Command lifecycle.  In the Test command this make sure we
      # are on a Linux machine and running as root.
      #
      def before
        super
        if not Datum.is_linux? then
          raise Error, "Only able to perform testing on linux.  I know how to dump the file sysem cache there."
        end
        if Process.euid != 0 then 
          raise Error, "Must be root to perform testing."
        end
      end

      #
      # call-seq: 
      #   test.sample_data -> Array of Datum
      #
      # Take a subset of the whole data collected based upon the percentage
      # option.
      #
      def sample_data( data )
        logger.info "collecting #{options['percentage']}% of the data"
        samples = []
        total = 0
        percentage = options['percentage']
        data.each_line do |l|
          total += 1
          if rand( 100 ) < percentage then
            samples << l
          end
        end
        logger.info "sampled #{samples.size} of #{total}"
        return StringIO.new( samples.join("\n") )
      end

      #
      # call-seq:
      #   test.run -> nil
      #
      # Part of the Command lifecycle.
      #
      def run
        sub_list_io = sample_from( self.file_list ) 
        @analyzer = Analyzer.new( Filelist.new( sub_list_io ) )
        @analyzer.collect_data
        results = []

        %w[ original_order inode_number first_physical_block_number ].each do |order|
          logger.info "ordering #{samples.size} samples by #{order}"
          tree = ::MultiRBTree.new
          samples.each do |s|
            rank = s.send( order )
            tree[rank] = s
          end
          results << run_test( order, tree.values )
        end

        report_results( results )
      end

      # 
      # call-seq:
      #   test.report_results( results ) -> nil
      #
      # Write the report of the timings to output
      #
      def report_results( timings )
        output.puts "Summary of files read"
        t = timings.first
        output.puts 
        output.puts "  Total files read : #{"%12d" % t.value_stats.count}"
        output.puts "  Total bytes read : #{"%12d" % t.value_stats.sum}"
        output.puts "  Minimum filesize : #{"%12d" % t.value_stats.min}"
        output.puts "  Average filesize : #{"%16.3f" % t.value_stats.mean}"
        output.puts "  Maximum filesize : #{"%12d" % t.value_stats.max}"
        output.puts "  Stddev of sizes  : #{"%16.3f" % t.value_stats.stddev}"
        output.puts
        output.puts "Comparison of read orders"
        output.puts

        output.puts ["%28s" % "order", "%20s" % "Elapsed time (sec)", "%22s" % "Read rate (bytes/sec)" ].join(" ")
        output.puts "-" * 72
        timings.each do |timing|
          p = [ ]
          p << "%30s" % timing.name
          p << "%20.3f" % timing.timed_stats.sum
          p << "%20.3f" % timing.rate
          output.puts p.join(" ")
        end
      end
      #
      # 
      # call-seq:
      #   test.run_test( 'original', [ Datum, Dataum, ... ]) -> Hitimes::TimedValueMetric
      #
      # Loop over all the Datum instances in the array and read the contents of
      # the file dumping them to /dev/null.  Timings of this process are recorded
      # an a Hitimes::TimedValueMetric is returned which holds the results.
      #
      def run_test( test_name, data )
        logger.info "running #{test_name} test on #{data.size} files"
        self.drop_caches
        timer = ::Hitimes::TimedValueMetric.new( test_name )
        logger.info "  begin test"
        data.each do |d|
          timer.start
          bytes = dump_to_dev_null( d )
          timer.stop( bytes )

          if timer.timed_stats.count % 10_000 == 0 then
            logger.info "  processed #{timer.count} at #{"%0.3f" % timer.rate} bytes/sec"
          end
        end
        logger.info "  end test"
        logger.info "  processed #{timer.timed_stats.count} at #{"%0.3f" % timer.rate} bytes/sec"
        return timer
      end

      #
      # call-seq:
      #   test.drop_caches -> nil
      #
      # Drop the caches on a linux filesystem.
      #
      # See proc(5) and /proc/sys/vm/drop_caches
      #
      def drop_caches
        # old habits die hard
        logger.info "  dropping caches"
        3.times { %x[ /bin/sync ] }
        File.open( "/proc/sys/vm/drop_caches", "w" ) do |f|
          f.puts 3
        end
      end

      # 
      # call-seq:
      #   test.dump_to_dev_null( Datum ) -> Integer
      # 
      # Write the contents of the file info in Datum to /dev/null and return the
      # number of bytes written.
      #
      def dump_to_dev_null( datum )
        bytes = 0
        File.open( "/dev/null", "w+" ) do |writer|
          File.open( datum.filename, "r") do |reader|
            chunk_size = datum.stat.blksize || 4096 
            buf = String.new  
            loop do
              begin
                r = reader.sysread( chunk_size, buf )
                bytes += writer.write( r )
              rescue => e
                break
              end
            end
          end
        end
        return bytes
      end
    end
  end
end
