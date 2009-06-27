module Readorder
  # 
  # An interator over the contents of a bunch of files or IO objects
  # depending on the initializer.
  #
  class Filelist
    class Error < ::Readorder::Error; end

    def initialize( sources = [] )
      @sources = [ sources ].flatten
      @current_source = nil
      @sources.each do |s|
        case s
        when String
          raise Error, "#{s} does not exist" unless File.exist?( s )
          raise Error, "#{s} is not readable" unless File.readable?( s )
        else
          [ :gets, :close ].each do |meth|
            raise Error, "#{s.inspect} does not respond to '#{meth}'" unless s.respond_to? meth
          end
        end
      end
    end

    def current_source
      if not @current_source then 
        cs = @sources.shift
        case cs
        when String
          @current_source = File.open( cs )
        else
          # nil or respond_to? :gets
          @current_source = cs
        end
      end
      return @current_source
    end

    # return the next line from the sources, opening a new source if
    # need be
    def gets
      loop do
        return nil unless self.current_source
        line = self.current_source.gets
        return line if line

        @current_source.close unless @current_source == $stdin
        @current_source = nil
      end
    end

    #
    # Iterator yielding the line returned, stopping on no more lines
    #
    def each_line
      while line = self.gets do
        yield line
      end
    end
  end
end
