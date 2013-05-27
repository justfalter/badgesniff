
module BadgeSniff
  class Packet
    attr_reader :channel, :length, :orig_length, :data
    def initialize(channel, orig_length, length, data)
      @channel = channel
      @length = length
      @orig_length = orig_length
      @data = data
    end

    PACKET_RE = /\A(?<channel>\h\h)(?<orig_len>\h\h)(?<len>\h\h)(?<data>\h*)\Z/

    def self.dehex(data)
      data.gsub(/([A-Fa-f0-9]{1,2})/) { $1.hex.chr }
    end

    def self.decode(encoded)
      encoded.strip!
      unless match = PACKET_RE.match(encoded)
        raise ArgumentError.new("Invalid packet")
      end

      self.new(match[:channel].to_i(16),
               match[:orig_len].to_i(16),
               match[:len].to_i(16),
               dehex(match[:data])
              )
    end
  end
end
