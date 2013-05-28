# Introduction

badgesniff allows you to leverage the 802.15.4 radio on the Thotcon 0x4 badge. 
There are two components to this project:
- firmware that will put the badge into 'sniffer' mode. 
- badgesniff-ruby - an application that interfaces with the badge, saving captured packets to a pcap or pcapng file.
- You can open up the pcap w/ Wireshark while badgesniff is running.
- Exciting!

## Hardware required

#### REMOVE THE BATTERY BEFORE DOING ANY OF THIS STUFF

Seriously. You don't want exploding batteries, or chips. One power-source at a time!

#### Serial TTL interface
I used a buspirate for this, but any FTDI-based USB-TTL Serial interface will do.

#### AVR ISP programmer
Any AVR ISP programmer will do, however it's probably easiest to use a buspirate.

#### 8x header pins
*You solder them :)*

- 6 for the ICSP header
- 2 for the TX/RX serial pins


## Software Dependencies

### firmware
- avr-libc
- avr-gcc
- cmake
- make

### badgesniff-ruby
- ruby 1.9.3
- bundler

# Using Ubuntu 12.04 LTS and buspirate

- On my system, my buspirate shows up as /dev/ttyUSB0

## Dependencies
```
sudo apt-get install build-essential cmake avrdude avr-libc gcc-avr ruby1.9.3
sudo gem1.9.3 install bundler
```

## Hook buspirate up to badge for AVR ISP programming
Based on [this doc](http://dangerousprototypes.com/docs/Bus_Pirate_AVR_Programming#AVR_ISP_Header)

Hook the buspirate up to the ICSP header on the badge. 
```
Buspirate ->  Badge
-------------------
MISO      ->  MISO
MOSI      ->  MOSI
GND       ->  GND
+3.3v     ->  Vcc
CS        ->  Reset
CLK       ->  SCK
```

## Flashing the badge with badgesniff

- Create the build directory 
```
mkdir firmware/build
cd firmware/build
```

- Setup the build. Obviously, replace /dev/ttyUSB0 with your device.
```
cmake -DCMAKE_TOOLCHAIN_FILE=../avr-toolchain.cmake -DAVR_PROGRAMMER=buspirate -DAVRDUDE_OPTIONS="-P/dev/ttyUSB0" ../
```

- Build the flash
```
make
```

- Flash the badge. This part can take awhile with the buspirate, as it isn't the speediest AVR programmer.
```
sudo make install
```

- Your badge is now programmed with the badgesniff flash image! If you hook directly up to the serial interface on the badge (baud at 38400), you will now be able to interact directly with the sniffer (type '?' for help). However, I make all of this easier for you with badgesniff-ruby, below! 

## Hook the buspirate up in serial for serial mode.
```
Buspirate ->  Badge
-------------------
MISO      ->  TXD
MOSI      ->  RXD
GND       ->  GND
+3.3v     ->  Vcc
```

## Running badgesniff-ruby

- Install deps
```
cd badgesniff-ruby
bundle install --path .bundle
```

- Start up badgesniff. Needs to be run as root.
```
sudo bundle exec bin/badgesniff.rb -p /dev/ttyUSB0 -w out.pcap
```

- You should see something like: 
```
channel_next      - go to next channel
channel_prev      - go to previous channel
channel_show      - show current channel
channel_set(NUM)  - Set the chanenl to NUM
channel_scan(NUM) - Scan each channel. Dwell on channel for NUM seconds (default 0.1)
help              - this text
Press <enter> to switch between monitor / console mode
Packets captured: 8
```

- Packets immediately begin saving into out.pcap

- Press enter and you'll see the console.
```
(ch: 25) (pkts: 31) > 
```

- You can initiate a scan of all channels, dwelling on each one for 1 second:
```
(ch: 25) (pkts: 31) > channel_scan 1
.....................done
{25=>10}
```

- In the above case, we captured ten packets on channel 25. 

- Set the channel to 25:
```
(ch: 15) (pkts: 1798) > channel_set 25
Setting channel to 25... 25
(ch: 25) (pkts: 1798) > 
```

- type 'quit' or hit ctrl-c to exit.

# Restoring the badge to its original Thotcon 0x4 behavior

- Hook the badge up for AVR ISP programming mode. 
- Go back into the build directory for the flash image
- The following command will restore the original flash image and fuse settings for the chip. 
```
sudo make restore_thotcon_flash
```
