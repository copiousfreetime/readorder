require 'rbconfig'
require 'pathname'
module Readorder
  #
  # All the block, inode and stat information about one file
  #
  class Datum
    attr_reader :filename
    attr_reader :inode_number
    attr_reader :first_physical_block_number
    attr_reader :error_reason
    attr_reader :stat
    attr_reader :physical_block_count
   
    # Check if we are running on linux.  We use this to enable 
    # us to check the physical block id.
    def self.is_linux?
      @is_linux ||= ::Config::CONFIG['host_os'] =~ /linux/i
    end

    #
    # Create a new Datum instance for the given filename
    #
    def initialize( filename )
      @filename = ::File.expand_path( filename.strip )
      @inode_number = nil
      @first_physical_block_number = nil
      @physical_block_count = 0
      @error_reason = nil
      
      @stat = nil
      @valid = false
      @collected = false
    end

    def block_count
      @stat.blocks
    end

    def size
      @stat.size
    end

    def logger
      ::Logging::Logger[self]
    end

    #
    # :call-seq: 
    #   datum.collect -> true
    #   datum.collect( false ) -> true
    #
    # collect all the information about the file we need
    # This includes:
    # 
    # - making sure we have a valid file, this means the file exists
    #   and is non-zero in size
    # - getting the inode number of the file
    # - getting the physical block number of the first block of the file
    # - getting the device of the file
    #
    # If false is passed in, then the physical block number is not
    # collected.
    #
    def collect( get_physical = true )
      unless @collected then
        begin
          @stat = ::File.stat( @filename )
          if not @stat.file? then
            @valid = false
            @error_reason = "Not a file"
          elsif @stat.zero? then
            @valid = false
            @error_reason = "0 byte file"
          else
            @valid = true
            @inode_number = @stat.ino
            if get_physical then
              @first_physical_block_number = self.find_first_physical_block_number
            end
          end
        rescue => e
          @error_reason = e.to_s
          logger.warn e
          @valid = false
        ensure
          @collected = true
        end
      end
      return @collected
    end

    def valid?
      @valid
    end

    ####
    # Not part of the public api
    protected

    # find the mountpoint for this datum.  We traverse up the Pathname
    # of the datum until we get to a parent where #mountpoint? is true
    #
=begin
    def find_mountpoint
      p = Pathname.new( @filename ).parent
      until p.mountpoint? do
        p = p.parent
      end
      return p.to_s
    end
=end
   
    # find the first physical block number, this only applies to linux
    # machines.
    def find_first_physical_block_number
      return nil unless Datum.is_linux?

      File.open( @filename ) do |f|
        first_block_num = 0
        @stat.blocks.times do |i|
          j = [i].pack("i")
          # FIBMAP = 0x00000001
          f.ioctl( 0x00000001, j )
          block_id = j.unpack("i")[0]
          if block_id > 0 then
            first_block_num = block_id if block_id < first_block_id || first_block_id == 0
            @physical_block_count += 1
          end
        end
      end
    end
  end
end
