require 'serialport'
require 'badgesniff/packet'

module BadgeSniff
  class BadgeIO
    def initialize(io)
      @io = io
      @running = false
    end

    def stop
      @running = false
    end

    def channel_set new_channel
      @io.write(sprintf("C%02x", new_channel))
    end

    def channel_next
      @io.write("n")
    end

    def channel_prev 
      @io.write("p")
    end

    def channel_show
      @io.write("c")
    end

    def get_badge_msg()
      begin
        if @io.readable?(0.1)
          line = @io.gets()
          return nil unless line =~ /^(?<msg>[A-Z]):(?<param>.*)$/
          return [$~[:msg], $~[:param]]
        end
      rescue => e
        warn "Caught in each_badge_msg(): #{e} #{e.message}"
      end
      return nil
    end

    def each_badge_msg()
      @running = true
      while @running == true
        msg, param = get_badge_msg()
        if msg
          yield(msg, param)
        end
      end
      @io.close()
    end
  end
end
