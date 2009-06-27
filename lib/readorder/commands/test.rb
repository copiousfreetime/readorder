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
      #   test.first_of( Filelist ) -> Filelist
      #
      # Use the *percentage* option to take the first *percentage* of the input
      # Filelist and return a new Filelist object continaing that subjset.
      #
      def first_of( data ) 
        percentage = options['percentage']
        logger.info "gathering the first #{percentage}% of the data"
        lines = []
        data.each_line { |l| lines << l.strip }
        max_index = ( lines.size.to_f * ( percentage.to_f / 100.0  ) ).ceil
        subset = lines[0..max_index]
        return Filelist.new( StringIO.new( subset.join("\n") ) )
      end

      #
      # call-seq: 
      #   test.sample_from( Filelist ) -> Filelist
      #
      # Use the *percentage* option to take a random subsampling of data from
      # the input Filelist and return an new Filelist object containing that
      # subset.
      #
      def sample_from( data )
        logger.info "sampling a random #{options['percentage']}% of the data"
        samples = []
        total = 0
        fraction = options['percentage'] / 100.0
        data.each_line do |l|
          total += 1
          if rand < fraction
            samples << l.strip
          end
        end
        logger.info "sampled #{samples.size} of #{total}"
        return Filelist.new( StringIO.new( samples.join("\n") ) )
      end

      #
      # call-seq:
      #   test.run -> nil
      #
      # Part of the Command lifecycle.
      #
      def run
        test_using_random_sample
        test_using_first_of
      end

      #
      # call-seq:
      #   test.test_using_random_sample
      #
      # Run the full test using a random subsample of the original Filelist
      #
      def test_using_random_sample
        @filelist = nil
        sublist = sample_from( self.filelist ) 
        results = test_using_sublist( sublist )
        output.puts "Test Using Random Sample".center(72)
        output.puts "=" * 72
        report_results( results )

      end

      #
      # call-seq:
      #   test.test_using_first_of
      #
      # Run the full test using a the first *percentage* of the original
      # Filelist
      #
      def test_using_first_of
        @filelist = nil
        sublist = first_of( self.filelist ) 
        results = test_using_sublist( sublist )
        output.puts "Test Using First Of".center(72)
        output.puts "=" * 72
        report_results( results )
      end

      #
      # call-seq:
      #   test.test_using_sublist( Filelist ) -> Array of TimedValueMetric
      #
      # given a Filielist of messages run the whole test on them all
      #
      def test_using_sublist( sublist )
        analyzer = Analyzer.new( sublist )
        analyzer.collect_data
        results = []

        %w[ original_order inode_number first_physical_block_number ].each do |order|
          logger.info "ordering #{analyzer.good_data.size} samples by #{order}"
          tree = ::MultiRBTree.new
          analyzer.good_data.each do |s|
            rank = s.send( order )
            tree[rank] = s
          end
          results << run_test( order, tree.values )
        end
        return results
      end

      # 
      # call-seq:
      #   test.report_results( results ) -> nil
      #
      # Write the report of the timings to output
      #
      def report_results( timings )
        t = timings.first
        output.puts 
        output.puts "  Total files read : #{"%12d" % t.value_stats.count}"
        output.puts "  Total bytes read : #{"%12d" % t.value_stats.sum}"
        output.puts "  Minimum filesize : #{"%12d" % t.value_stats.min}"
        output.puts "  Average filesize : #{"%16.3f" % t.value_stats.mean}"
        output.puts "  Maximum filesize : #{"%12d" % t.value_stats.max}"
        output.puts "  Stddev of sizes  : #{"%16.3f" % t.value_stats.stddev}"
        output.puts

        output.puts ["%28s" % "read order", "%20s" % "Elapsed time (sec)", "%22s" % "Read rate (bytes/sec)" ].join(" ")
        output.puts "-" * 72
        timings.each do |timing|
          p = [ ]
          p << "%28s" % timing.name
          p << "%20.3f" % timing.timed_stats.sum
          p << "%22.3f" % timing.rate
          output.puts p.join(" ")
        end
        output.puts
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
