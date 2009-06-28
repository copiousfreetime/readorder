require File.expand_path( File.join( File.dirname( __FILE__ ),"spec_helper.rb"))

require 'readorder/analyzer'

describe Readorder::Analyzer do
  before( :each ) do
    s = StringIO.new
    fl = Dir.glob("#{Readorder::Paths.spec_path}/*_spec.rb")
    s.puts fl.to_a.join("\n")
    s.rewind
    @filelist = Readorder::Filelist.new( s )
    @analyzer = Readorder::Analyzer.new( @filelist, false )
  end

  it "collects data about files" do
    @analyzer.collect_data
    @analyzer.good_data.size.should > 0
    @analyzer.inode_order.size.should > 0
    @analyzer.physical_order.size.should == 0
  end

  it "logs a summary report" do
    @analyzer.collect_data
    @analyzer.log_summary_report
    spec_log.should =~ /Collection Rate/
  end

  it "can have bad data and dump it to a file" do
    s = StringIO.new
    s.puts "/a/nonexistent/file"
    s.rewind
    analyzer = Readorder::Analyzer.new( Readorder::Filelist.new( s ) )
    analyzer.collect_data
    analyzer.bad_data.size.should > 0

    s2 = StringIO.new
    analyzer.dump_bad_data_to( s2 )
    s2.rewind
    s2.gets.should == "error_reason,filename\n"
    s2.gets.should == "No such file or directory - /a/nonexistent/file,/a/nonexistent/file\n"
  end

  it "can dump good data to a csv" do
    @analyzer.collect_data
    s = StringIO.new
    @analyzer.dump_good_data_to( s )
    s.rewind
    s.gets.should == "filename,size,inode_number\n"
    s.read.split("\n").size.should == @analyzer.good_data.size
  end
end
