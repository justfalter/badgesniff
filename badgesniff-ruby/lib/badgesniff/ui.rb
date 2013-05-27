require 'ripl'

module BadgeSniff
  module RiplNoPrintResult
    def print_result(result)
    end
  end
  Ripl::Shell.include RiplNoPrintResult

  class UI
    def initialize(sniffer)
      @sniffer = sniffer
      @interactive = true
      $stdin.sync = true
      @history_file = '~/.badgesniff_history'
    end

    def __run
      Signal.trap("INT") do
        self.stop()
      end
      help()
      monitor()
      Ripl.start :binding => binding, 
        :argv => [],
        :prompt => lambda { sprintf("(ch: %d) (pkts: %d) > ", 
                                    @sniffer.last_channel,
                                    @sniffer.count)},
        :history => @history_file,
        :irbrc => false,
        :riplrc => false
    end

    def packet_count
      puts "Packets captured: #{@sniffer.count}"
    end

    def channel_show
      print "Current channel: "
      channel = @sniffer.channel_show
      puts channel
    end

    def channel_next
      print "Going to next channel.... "
      new_channel = @sniffer.channel_next
      puts new_channel
    end

    def channel_prev 
      print "Going to previous channel.... "
      new_channel = @sniffer.channel_prev
      puts new_channel
    end

    def channel_set new_channel
      print "Setting channel to #{new_channel}... "
      the_channel = @sniffer.channel_set new_channel
      puts "#{new_channel}"
    end

    def channel_scan dwell = 0.1
      first_channel = @sniffer.channel_show
      @sniffer.clear_channel_counts
      loop do
        print '.'
        sleep dwell
        chan = @sniffer.channel_next
        break if chan == first_channel
      end
      puts "done"
      require 'pp'
      pp @sniffer.channel_counts
    end

    def stop
      puts "stopping the sniffer"
      @sniffer.stop()
      exit
      nil
    end

    def monitor
      loop do
        # Adds a bit of a delay, as well as checks to see if we should bounce.
        return if select([$stdin], nil, nil, 0.1)
        print "Packets captured: #{@sniffer.count}\r"
      end
    end

    def help
      puts "   channel_next      - go to next channel"
      puts "   channel_prev      - go to previous channel"
      puts "   channel_show      - show current channel"
      puts "   channel_set(NUM)  - Set the chanenl to NUM"
      puts "   channel_scan(NUM) - Scan each channel. Dwell on channel for NUM seconds (default 0.1)"
      puts "   stop              - stop sniffing and exit"
      puts "   help              - this text"
      puts ""
      puts " Press <enter> to switch between monitor / console mode"
    end
  end
end

