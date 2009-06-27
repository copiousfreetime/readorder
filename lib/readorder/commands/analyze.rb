module Readorder
  module Commands
    #
    # Analyze the list of files to sort and give a report
    #
    class Analyze < ::Readorder::Command
      def run
        analyzer.collect_data
        output.puts @analyzer.summary_report
        if options['data-csv'] then
          File.open( options['data-csv'], "w+") { |f| analyzer.dump_good_data_to( f ) }
          logger.info "dumped #{analyzer.good_data.size} rows to #{options['data-csv']}"
        end
      end
    end
  end
end
