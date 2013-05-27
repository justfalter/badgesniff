require 'serialport'

module BadgeSniff
  class DirectSerial 
    def initialize(port_path, opts = {})
      port_str = port_path
      baud_rate = opts[:baud] || 38400
      data_bits = opts[:data_bits] || 8
      stop_bits = opts[:stop_bits] || 1
      parity = ::SerialPort::NONE

      @sp = ::SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)
      @sp.set_encoding("BINARY")
    end

    def write(str)
      @sp.write(str)
    end

    def gets()
      @sp.gets()
    end

    def close()
      @sp.close()
    end

    def readable?(tout = 0.1)
      !select([@sp], nil, nil, tout).nil?
    end

  end
end
