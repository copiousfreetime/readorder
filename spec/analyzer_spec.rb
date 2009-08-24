require File.expand_path( File.join( File.dirname( __FILE__ ),"spec_helper.rb"))

require 'readorder/analyzer'

describe Readorder::Analyzer do
  before( :each ) do
    s = StringIO.new
    fl = Dir.glob("#{Readorder::Paths.spec_path}*_spec.rb")
    s.write( fl.join("\n") )
    s.rewind

    @filelist = Readorder::Filelist.new( s )
    @r = Readorder::Results.new( ":memory:" )

    @analyzer = Readorder::Analyzer.new( @filelist, @r , false )
  end

  after( :each ) do
    @r.close
  end

  it "collects data about files" do
    @analyzer.collect_data
    @analyzer.results.valid_count.should > 0
    check_count = 0
    @analyzer.results.each_valid { |v| check_count += 1 }
    check_count.should > 0
    check_count.should == @analyzer.results.valid_count
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
    analyzer = Readorder::Analyzer.new( Readorder::Filelist.new( s ), @r, false )
    analyzer.collect_data
    analyzer.results.error_count.should > 0

    s2 = StringIO.new
    analyzer.dump_errors_to( s2 )
    s2.rewind
    s2.gets.should == "error_reason,filename\n"
    s2.gets.should == "No such file or directory - /a/nonexistent/file,/a/nonexistent/file\n"
  end

  it "can dump good data to a csv" do
    @analyzer.collect_data
    s = StringIO.new
    @analyzer.dump_valid_to( s )
    s.rewind
    s.gets.should == "filename,size,inode_number\n"
    s.read.split("\n").size.should == @analyzer.results.valid_count
  end

  it "can iterate over inode block numbers" do
    @analyzer.collect_data
    by_order = []
    @analyzer.results.each_valid_by_field( 'original_order' ) do |r|
      by_order << r['filename']
    end

    by_inode = []
    @analyzer.results.each_valid_by_inode_number do |r|
      by_inode << r['filename']
    end

    by_order.should_not == by_inode
    by_order.sort.should == by_inode.sort
  end
end
