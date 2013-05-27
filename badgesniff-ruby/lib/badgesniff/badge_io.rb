require 'serialport'
require 'badgesniff/packet'

module BadgeSniff
  class BadgeIO
    def initialize(port_path, opts = {})
      port_str = port_path
      baud_rate = opts[:baud] || 38400
      data_bits = opts[:data_bits] || 8
      stop_bits = opts[:stop_bits] || 1
      parity = SerialPort::NONE

      @sp = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
      @sp.set_encoding("BINARY")
      @running = false
    end

    def stop
      @running = false
    end

    def channel_set new_channel
      @sp.write(sprintf("C%02x", new_channel))
    end

    def channel_next
      @sp.write("n")
    end

    def channel_prev 
      @sp.write("p")
    end

    def channel_show
      @sp.write("c")
    end

    def get_badge_msg()
      begin
        if select([@sp], nil, nil, 0.1)
          line = @sp.gets()
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
      @sp.close()
    end
  end
end
