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

        filenames = nil
        if get_physical? then
          logger.info "using physical order"
          filenames = analyzer.filenames_by_physical_order
        else
          logger.info "using inode order"
          filenames = analyzer.filenames_by_inode_order
        end

        filenames.each do |fname|
          output.puts fname
        end

      end
    end
  end
end
