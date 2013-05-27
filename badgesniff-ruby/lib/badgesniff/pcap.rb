
module BadgeSniff
  class PcapFile
    attr_reader :filename
    def initialize(filename)
      @filename = filename
      @fio = File.open(filename, "wb")
      @fio.sync = true
      write_file_header()
    end

    private

    # Writes a pcap file-header.
    def write_file_header()
      @fio.write([
        0xa1b2c3d4,           # Magic
        2,                    # Major version
        4,                    # Minor version
        Time.now.gmt_offset,  # GMT offset
        0,                    # sigfigs
        65535,                # snaplen
        195                   # LINKTYPE_IEEE802_15_4 - http://www.tcpdump.org/linktypes.html
      ].pack("LSSlLLL"))
    end

    public

    # Write a packet to the pcap file.
    def write(packet)
      # Write the packet header.
      ts = Time.now
      @fio.write([
        ts.to_i,
        ts.nsec / 1_000_000,
        packet.length,
        packet.orig_length,
      ].pack("LLLL"))
      @fio.write(packet.data)
    end

    def close
      @fio.close
    end
  end
end
