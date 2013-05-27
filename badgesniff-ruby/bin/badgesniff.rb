#!/usr/bin/env ruby
#
require 'pathname'
$:.unshift((Pathname.new(__FILE__).dirname + "../lib").to_s)
require 'optparse'
require 'ostruct'
require 'badgesniff'
require 'badgesniff/badge_io/direct_serial'
require 'badgesniff/badge_io/buspirate'

class BadgeSniffOpts
  attr_accessor :port, :device_type, :pcap_format, :pcap_file
  def initialize
    @port = nil
    @device_type = :buspirate
    @pcap_format = nil
    @pcap_file = nil
  end

  def self.parse(args)
    options = self.new

    opt_parser = OptionParser.new do |opts|
      opts.on("-t", "--type [DEVICE_TYPE]", [:buspirate, :serial], 
              "Device type (either 'buspirate' or 'serial'). Defaults to buspirate.") do |t|
        options.device_type = t
      end

      opts.on("-p", "--port [PATH]", "Path to device port (ex: /dev/ttyUSB0)") do |t|
        unless File.chardev?(t)
          puts "Error: not a character device: #{t}"
          puts opts
          exit
        end

        options.port = t
      end

      opts.on("-w", "--write [PCAPFILE]", "File to write packets into. Should end with either .pcap or .pcapng") do |t|
        if t.end_with?(".pcap")
          options.pcap_format = :pcap
        elsif t.end_with?(".pcapng")
          options.pcap_format = :pcapng
        else 
          puts "Unknown file type: #{t}."
          puts opts
          exit
        end
        options.pcap_file = t
      end

      opts.separator ""

      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end

    opt_parser.parse!(args)

    if options.port.nil?
      puts "ERROR: Missing --port specification"
      puts opt_parser
      exit
    end

    return options
  end
end

opts = BadgeSniffOpts.parse(ARGV)

pcap = nil
if opts.pcap_format == :pcapng
  pcap = BadgeSniff::PcapNgFile.new(opts.pcap_file)
else 
  pcap = BadgeSniff::PcapFile.new(opts.pcap_file)
end

io = nil
if opts.device_type == :buspirate
  io = BadgeSniff::BusPirate.new(opts.port)
else 
  io = BadgeSniff::DirectSerial.new(opts.port)
end

badgeio = BadgeSniff::BadgeIO.new(io)

sniffer = BadgeSniff::Sniffer.new(badgeio, pcap)
ui = BadgeSniff::UI.new(sniffer)
ui.__run


