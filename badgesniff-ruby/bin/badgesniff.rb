#!/usr/bin/env ruby
#
require 'pathname'
$:.unshift((Pathname.new(__FILE__).dirname + "../lib").to_s)
require 'badgesniff'

filename = "out.pcapng"
pcapng = BadgeSniff::PcapNgFile.new(filename)
badgeio = BadgeSniff::BadgeIO.new("/dev/tty.usbserial-AD01V6MX")

sniffer = BadgeSniff::Sniffer.new(badgeio, pcapng)
ui = BadgeSniff::UI.new(sniffer)
ui.__run


