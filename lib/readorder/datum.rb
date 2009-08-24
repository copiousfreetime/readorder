require 'rbconfig'
require 'pathname'
module Readorder
  #
  # All the block, inode and stat information about one file
  #
  class Datum

    # The fully qualified path of the file
    attr_reader :filename

    # The inode number of the file
    attr_reader :inode_number

    # The physical block number of the first disc block of the file.  This piece
    # of data may not be gathered.  This will be nil if that is the case
    attr_reader :first_physical_block_number

    # if there is a reason this file is not eligible for analysis this explains
    # why
    attr_reader :error_reason

    # File::Stat of the file
    attr_reader :stat

    # count of the number of physical disc blocks this file consumes.  This is
    # only gathered if the *first_physical_block_number* is also gathered.
    attr_reader :physical_block_count

    # the original order in which the Datum was collected
    attr_accessor :original_order
   
    # Check if we are running on linux.  We use this to enable 
    # us to check the physical block id.
    def self.is_linux?
      @is_linux ||= ::Config::CONFIG['host_os'] =~ /linux/i
    end

    #
    # call-seq:
    #   Datum.new( filename ) -> Datum
    #
    # Create a new Datum instance for the given filename
    #
    def initialize( filename )
      @filename = ::File.expand_path( filename.strip )
      @inode_number = nil
      @first_physical_block_number = nil
      @physical_block_count = 0
      @error_reason = nil
      @original_order = 0
      @size = 0
      
      @stat = nil
      @valid = false
      @collected = false
    end

    #
    # call-seq:
    #   datum.to_csv
    #
    # return the datum as a CSV in the format:
    #
    #   physical_id,inode_id,filename
    #
    def to_csv
      "#{first_physical_block_number},#{inode_number},#{filename}"
    end


    #
    # call-seq:
    #   datum.size -> Integer
    #
    # The number of bytes the file consumes
    #
    def size
      @size ||= @stat.size
    end

    #
    # call-seq:
    #   datum.logger -> Logger
    #
    # The Logger for the instance
    #
    def logger
      ::Logging::Logger[self]
    end

    #
    # :call-seq: 
    #   datum.collect( get_physical = true ) -> true
    #
    # Collect all the information about the file we need.
    # This includes:
    # 
    # * making sure we have a valid file, this means the file exists
    #   and is non-zero in size
    # * getting the inode number of the file
    # * getting the physical block number of the first block of the file
    # * getting the device of the file
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
            @inode_number = @stat.ino
            if get_physical then
              @first_physical_block_number = self.find_first_physical_block_number
            end
            @valid = true
          end
        rescue => e
          @error_reason = e.to_s
          logger.warn e.to_s
          @valid = false
        ensure
          @collected = true
        end
      end
      return @collected
    end

    #
    # call-seq:
    #   datum.valid?
    #
    # Does this Datum represent a collection of valid data
    #
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
  
    #
    # call-seq:
    #   datum.find_first_physical_block_number -> Integer
    #
    # find the first physical block number, this only applies to linux
    # machines.
    #
    # This is only called within the context of the #collect method
    #
    def find_first_physical_block_number
      return nil unless Datum.is_linux?

      first_block_num = 0
      File.open( @filename ) do |f|
        @stat.blocks.times do |i|

          j = [i].pack("i")
          # FIBMAP = 0x00000001
          f.ioctl( 0x00000001, j )
          block_id = j.unpack("i")[0]

          if block_id > 0 then
            first_block_num = block_id if block_id < first_block_num || first_block_num == 0
            @physical_block_count += 1
          end

        end
      end
      return first_block_num

    end
  end
end
