require File.expand_path(File.join(File.dirname(__FILE__),"spec_helper.rb"))

require 'stringio'
require 'readorder/filelist'

describe ::Readorder::Filelist do
  it "can read from an object that responds to gets" do
    s = StringIO.new
    files = %w[ /tmp/here /tmp/there ]
    files.each { |f| s.puts f }
    s.rewind

    fl = ::Readorder::Filelist.new( s )
    fl.gets.should == "/tmp/here\n"
    fl.gets.should == "/tmp/there\n"
  end

  it "raises an error if given a filename and it cannot open or read from the file" do
    lambda { ::Readorder::Filelist.new( "/does/not/exist" ) }.should raise_error( Readorder::Filelist::Error, /does not exist/ )
  end

  it "raises an error if given something that is not a string that does not respond to gets" do
    x = Object.new
    def x.close
      true
    end
    lambda { ::Readorder::Filelist.new( x ) }.should raise_error( Readorder::Filelist::Error, /does not respond to 'gets'/ )
  end
  
  it "raises an error if given something that is not a string that does not respond to close" do
    x = Object.new
    def x.gets
      true
    end
    lambda { ::Readorder::Filelist.new( x ) }.should raise_error( Readorder::Filelist::Error, /does not respond to 'close'/ )
  end

  it "can be iterated over with each_line" do
    s = StringIO.new
    files = [ "/tmp/here\n", "/tmp/there\n" ]

    files.each { |f| s.print f }
    s.rewind

    fl = ::Readorder::Filelist.new( s )
    out = []
    fl.each_line do |l| 
      out << l 
    end
    out.size.should == 2
    out.should == files
  end
end
