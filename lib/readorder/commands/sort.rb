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
        data = get_physical? ? analyzer.physical_order : analyzer.inode_order
        data.values.each do |d|
          output.puts d.filename
        end
      end
    end
  end
end
