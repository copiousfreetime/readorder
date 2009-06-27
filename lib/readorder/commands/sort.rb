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
        data = nil
        if get_physical? then
          logger.info "using physical order"
          data = analyzer.physical_order
        else
          logger.info "using inode order"
          data = analyzer.inode_order
        end
        data.values.each do |d|
          output.puts d.filename
        end
      end
    end
  end
end
