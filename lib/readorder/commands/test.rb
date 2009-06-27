module Readorder
  module Commands
    #
    # Test reading all the contents of a subset of the files and report summary
    # information on how long it takes to read the files given different
    # reading orders.
    #
    class Test < ::Readorder::Command

      def before
        super
        if not Datum.is_linux? then
          raise Error, "Only able to perform testing on linux.  I know how to dump the file sysem cache there."
        end
        if Process.euid != 0 then 
          raise Error, "Must be root to perform testing."
        end
      end

      def sample_data( data )
        logger.info "randomly collecting #{options['percentage']}% of #{analyzer.good_data.size} items"
        samples = []
        percentage = options['percentage']

        data.each do |d|
          if rand(100) < percentage then
            samples << d
          end
        end

        return samples
      end

      def run
        analyzer.collect_data
        samples = sample_data( analyzer.good_data )
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
      end

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
        logger.info "begin test"
        data.each do |d|
          timer.start
          bytes = dump_to_dev_null( data )
          timer.stop( bytes )

          if timer.count % 10_000 == 0 then
            logger.info "  processed #{timer.count} at #{"%0.3f" % timer.rate} bytes/sec"
          end
        end
        logger.info "end test"
        logger.info "processed #{timer.count} at #{"%0.3f" % timer.rate} bytes/sec"
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
        logging.info "dropping caches"
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
            chunk_size = datum.stat.blocksize || 4096 
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
