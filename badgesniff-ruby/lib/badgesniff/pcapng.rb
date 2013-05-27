require 'bindata'

module BadgeSniff
  class PcapNgOption < BinData::Record
    endian :little
    uint16 :opt_code
    uint16 :opt_len, :value => lambda { data.length }
    string :data
    string :padding, :length => lambda { calc_padding() }

    def calc_padding
      data_mod = data.length % 4
      return 0 if data_mod == 0
      return 4 - data_mod
    end
  end

  class PcapNgSecitonHeader < BinData::Record
    endian :little

    uint32 :block_type, :value => 0x0a0d0d0a
    uint32 :total_len1, :value => lambda { self.num_bytes }
    uint32 :magic, :value => 0x1A2B3C4D
    uint16 :major_version, :initial_value => 1
    uint16 :minor_version, :initial_value => 0
    int64  :section_length, :initial_value => -1
    string :options
    uint32 :total_len2, :value => lambda { self.num_bytes }
  end

  class PcapNgInterfaceHeader < BinData::Record
    endian :little

    uint32 :block_type, :initial_value => 1
    uint32 :total_len1, :value => lambda { self.num_bytes }
    uint16 :link_type, :initial_value => 195
    uint16 :reserved, :initial_value => 0
    uint32 :snaplen, :initial_value => 65535
    string :options
    uint32 :total_len2, :value => lambda { self.num_bytes }

    def self.default_if
      ret = self.new
      opt_s = ""
      tsresol = PcapNgOption.new
      tsresol.opt_code = 9
      tsresol.data = 6.chr
      opt_s << tsresol.to_binary_s
      opt_end = PcapNgOption.new
      opt_end.opt_code = 0
      opt_s << opt_end.to_binary_s
      ret.options = opt_s
      ret
    end
  end

  class PcapNgPacket < BinData::Record
    endian :little

    uint32 :block_type, :value => 6
    uint32 :total_len1, :value => lambda { self.num_bytes }
    uint32 :interface_id, :initial_value => 0
    uint32 :timestamp_h, :initial_value => 0
    uint32 :timestamp_l, :initial_value => 0
    uint32 :capture_length, :initial_value => 0
    uint32 :orig_length, :initial_value => 0
    string :packet_data
    string :padding, :length => lambda { calc_padding() }
    string :options
    uint32 :total_len2, :value => lambda { self.num_bytes }

    def calc_padding
      data_mod = packet_data.length % 4
      return 0 if data_mod == 0
      return 4 - data_mod
    end
  end

  class PcapNgFile
    attr_reader :filename
    def initialize(filename)
      @filename = filename
      @fio = File.open(filename, "wb")
      @fio.sync = true
      @pkt = PcapNgPacket.new
      write_file_header()
    end

    # Writes a pcap file-header.
    def write_file_header()
      @fio.write(PcapNgSecitonHeader.new.to_binary_s)
      ifheader = PcapNgInterfaceHeader.default_if
      @fio.write(ifheader.to_binary_s)
    end

    def write(packet)
      ts = (Time.now.to_f * (10 ** 6)).to_i
      @pkt.capture_length = packet.length
      @pkt.orig_length = packet.orig_length
      @pkt.packet_data = packet.data
      @pkt.timestamp_h = ts >> 32
      @pkt.timestamp_l = ts & 0xffffffff
      channel_info = PcapNgOption.new()
      channel_info.opt_code = 1
      channel_info.data = "Zigbee Channel: #{packet.channel}"
      @pkt.options = channel_info.to_binary_s
      @fio.write(@pkt.to_binary_s)
    end

    def close
      @fio.close
    end
  end
end
