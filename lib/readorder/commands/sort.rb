require 'readorder/command'
module Readorder
  #
  # Run an anlyzer to gather all the information and then output the
  # filenames to stdout or to the output file
  #
  class Sort < ::Readorder::Command
    def run
      analyzer.collect_data
      analyzer.log_summary_report
      analyzer.good_data
    end
  end
end
