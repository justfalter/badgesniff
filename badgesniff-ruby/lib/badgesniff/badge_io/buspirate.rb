require 'serialport'

module BadgeSniff
  class BusPirate
    def initialize(port)
      port_str = port
      baud_rate = 115200
      data_bits = 8
      stop_bits = 1
      parity = ::SerialPort::NONE

      @bp = ::SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
      @bp.set_encoding("BINARY")

      init_uart()
    end

    BP_ENTER_BITBANG    = 0b00000000   # "BBIO1"
    BP_UART_MODE        = 0b00000011   # "ART1"
    BP_RESET            = 0b00001111   
    

    # @param [String] ack
    # @return [Boolean] true
    def wait_for_ack(ack)
      ack.each_byte do |expected_byte|
        byte_read = @bp.readbyte
        unless byte_read == expected_byte
          return false
        end
      end

      return true
    end

    def reset
      @bp.putc BP_RESET
    end

    def enter_bitbang
      20.times do
        #@bp.putc BP_ENTER_BITBANG
        @bp.write(0.chr * 20)
        if select([@bp], nil, nil, 0.1)
          if wait_for_ack("BBIO1") == true
            return true
          else
            raise "Got invalid ack while trying to enter bitbang mode"
          end
          break
        end
      end

      raise "Failed to get buspirate to enter bitbang mode."
      false
    end

    def init_uart
      enter_bitbang

      @bp.putc(BP_UART_MODE)
      if wait_for_ack("ART1") != true
        raise "got invalid ack for entering UART mode"
      end

      # Set baud to 38400
      @bp.putc(0b01100111)
      if wait_for_ack(1.chr) != true
        raise "got invalid ack for setting baud to 38400"
      end
      
      # Turn power on.
      @bp.putc(0b01001000)
      if wait_for_ack(1.chr) != true
        raise "got invalid ack for turning power up"
      end

      # Turn power on.
      @bp.putc(0b10010000)
      if wait_for_ack(1.chr) != true
        raise "got invalid ack for turning power up"
      end

      # Now enter bridge mode.
      @bp.putc(0b00001111)
    end

    def write(str)
      @bp.write(str)
    end

    def gets()
      @bp.gets()
    end

    def close()
      puts "You will have to turn the buspirate off and on in order to use it, again."
      @bp.close()
    end

    def readable?(tout = 0.1)
      !select([@bp], nil, nil, tout).nil?
    end
  end
end
