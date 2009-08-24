require 'readorder/command'
module Readorder
  module Commands
    #
    # Run an anlyzer to gather all the information and then output the
    # filenames to stdout or to the output file
    #
    class Sort < ::Readorder::Command
      def run

        analyzer.collect_data
        analyzer.log_summary_report

        field = nil
        if get_physical? then
          logger.info "using first physical block number order"
          field = 'first_physical_block_number'
        else
          logger.info "using inode number order"
          field = 'inode_number'
        end

        analyzer.results.each_valid_by_field( field ) do |row|
          output.puts row['filename']
        end
      end
    end
  end
end
