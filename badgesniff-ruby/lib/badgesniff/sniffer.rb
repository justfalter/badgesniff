require 'thread'

module BadgeSniff
  class Sniffer
    attr_reader :count, :last_channel
    def initialize(badgeio, pcap)
      @badgeio = badgeio
      @pcap = pcap
      @count = 0
      @channel_counts = Hash.new {|h,k| h[k] = 0}
      @processing_thread = init_processing_thread()
      @cmd_queue = SizedQueue.new(1)
      @response_queue = Queue.new
      @last_channel = -1
    end

    def init_processing_thread
      @running = true
      Thread.new do
        while @running == true
          # Process a response, if any.
          msg, param = @badgeio.get_badge_msg()
          unless msg.nil?
            process_badge_msg(msg, param)
          end

          # Process commands, if any.
          if @cmd_queue.size() > 0
            cmd, params = @cmd_queue.pop()
            @badgeio.send(cmd, *params)
          end
        end
      end
    end

    def send_cmd(cmd, params, expected_msg)
      @response_queue.clear
      @cmd_queue.push([cmd, params])
      loop do
        msg, response_params = @response_queue.pop
        next unless msg == expected_msg
        return response_params
      end
    end

    def channel_set new_channel
      return send_cmd(:channel_set, [new_channel], :channel)
    end

    def channel_next
      return send_cmd(:channel_next, [], :channel)
    end

    def channel_prev 
      return send_cmd(:channel_prev, [], :channel)
    end

    def channel_show
      return send_cmd(:channel_show, [], :channel)
    end

    def clear_channel_counts
      @channel_counts.clear
    end

    def channel_counts
      @channel_counts
    end

    def stop
      @running = false
      @badgeio.stop()
      if @processing_thread.join(4).nil?
        warn "Failed to shut down badgeio."
        @processing_thread.kill
      end
      @pcap.close()
      puts "Saved #{@count} packets to #{@pcap.filename}"
    end

    def process_badge_msg(msg, param)
      param.strip!
      case msg 
      when 'C'
        @last_channel = param.to_i(16)
        @response_queue.push([:channel, @last_channel])
      when 'P'
        @count += 1
        begin
          packet = BadgeSniff::Packet.decode(param)
        rescue => e
          #warn "Invalid packet: #{param}"
          return
        end
        @last_channel = packet.channel
        @channel_counts[packet.channel] += 1
        @pcap.write(packet)
        #print "Packets: #{@count}\r"
      end
    end
  end
end
