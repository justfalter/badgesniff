#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdio.h>
#include <stdlib.h>

#define REG_TRX_STATUS_TRX_STATUS_MASK 0x1F 

#define TRX_FRAME_BUFFER_OFFSET 0x180
#define TRX_FRAME_BUFFER(index) (*(volatile uint8_t *)(TRX_FRAME_BUFFER_OFFSET + (index)))

#define IRQ_STATUS_CLEAR_VALUE 0

#define CHANNEL_BASE 0xb
#define CHANNEL_INIT 0x19
#define CHANNEL_MAX 0x1f

#include <util/setbaud.h>

#define BADGE_MSG_INFO 'I'
#define BADGE_MSG_HELP '?'
#define BADGE_MSG_PACKET 'P'
#define BADGE_MSG_CAP_ENABLED 'X'
#define BADGE_MSG_CHANNEL 'C'
// If '1', bad frames are allowed. 
// If '0', bad frames are not allowed.
#define BADGE_MSG_BAD_CRC_ALLOW 'B'

#define BADGE_CMD_HELP '?'
#define BADGE_CMD_BAD_CRC_DROP '1'
#define BADGE_CMD_BAD_CRC_ALLOW '2'
#define BADGE_CMD_BAD_CRC_SHOW 'B'
#define BADGE_CMD_CHAN_NEXT 'n'
#define BADGE_CMD_CHAN_PREV 'p'
#define BADGE_CMD_CHAN_SHOW 'c'
#define BADGE_CMD_CHAN_SET 'C'
#define BADGE_CMD_CAP_START 'X'
#define BADGE_CMD_CAP_STOP 'x'

//
// Variables
//
volatile uint8_t current_channel = CHANNEL_BASE;
uint8_t frame_length = 0;
uint8_t packet_logging = 1;
uint8_t packet_channel = 0;
uint8_t allow_bad_frames = 1;

//
// Functions
//

void led_init()
{
  DDRF |= 0xFF;
  DDRE |= ((1 << DDE4));
}

void led_status_on()
{
  PORTE |= (1 << PORTE4);
}


static int uart_putchar(char c, FILE *stream)
{
    loop_until_bit_is_set(UCSR0A, UDRE0);
    UDR0 = c;
    return 0;
}

static int uart_getchar(FILE *stream) {
    loop_until_bit_is_set(UCSR0A, RXC0); /* Wait until data exists. */
    return UDR0;
}

static FILE uart_stdout = FDEV_SETUP_STREAM(uart_putchar, NULL,
                                             _FDEV_SETUP_WRITE);

static FILE uart_stdin =  FDEV_SETUP_STREAM(NULL, uart_getchar, 
                                             _FDEV_SETUP_READ);


void uart_init(void) {
    UBRR0H = UBRRH_VALUE;
    UBRR0L = UBRRL_VALUE;

#if USE_2X
    UCSR0A |= _BV(U2X0);
#else
    UCSR0A &= ~(_BV(U2X0));
#endif

    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00); /* 8-bit data */ 
    UCSR0B = _BV(RXEN0) | _BV(TXEN0);   /* Enable RX and TX */

    stdout = &uart_stdout;
    stdin = &uart_stdin;
}


// Writes a message to the serial interface. 
//  code - The message code
//  fmt  - The format string for the message
//  ...  - Arguments for the format string.
//
void serial_msg(char code, const char * fmt, ...)
{
  va_list args;
  uint8_t reenable_interrupts = 0;
  // Check to see if interrupts are enabled, and disable them if need be.
  // This ensures that we can print our message without being... interrupted.
  if (SREG_struct.i) {
    reenable_interrupts = 1;
    cli();
  }

  printf("%c:", code);
  va_start(args, fmt);
  vprintf(fmt, args);
  va_end(args);
  printf("\r\n");

  // Re-enable interrupts, if needed.
  if (reenable_interrupts)
    sei();
}

void log_help(char cmd, char * message) 
{
  serial_msg(BADGE_MSG_HELP, "%c - %s", cmd, message);
}

void log_info(char * message) 
{
  serial_msg(BADGE_MSG_INFO, "%s", message);
}

void log_channel()
{
  serial_msg(BADGE_MSG_CHANNEL, "0x%02x", current_channel);
}

void log_bad_crc_setting()
{
  serial_msg(BADGE_MSG_BAD_CRC_ALLOW, "%d", allow_bad_frames);
}

void log_cap_setting()
{
  serial_msg(BADGE_MSG_CAP_ENABLED, "%d", packet_logging);
}

void print_packet(volatile uint8_t * buffer, uint8_t len, uint8_t orig_len, uint8_t channel) 
{
  int i;
  char * output = (char*) malloc((2*len)+1);

  for (i = 0; i < len; i++)
    sprintf(output + (i * 2), "%02x", buffer[i]);
  // Don't need to null terminate, as sprintf takes care of that.
  serial_msg(BADGE_MSG_PACKET, "%02x%02x%02x%s", channel, orig_len, len, output);
  free(output);
}

void set_rf_state(uint8_t state)
{
  TRX_STATE = CMD_FORCE_TRX_OFF;
  TRX_STATE = state;
  while (state != (TRX_STATUS & REG_TRX_STATUS_TRX_STATUS_MASK));
}

ISR(TRX24_RX_START_vect)
{
  // Keep track of the channel that we got our packet on.
  // You can't rely upon it being correct when read during 
  // TRX24_RX_END
  packet_channel = PHY_CC_CCA_struct.channel;
}

ISR(TRX24_RX_END_vect)
{
  if (packet_logging) 
  {
    // Ignore stuff with bad CRC's
    if (allow_bad_frames|| PHY_RSSI_struct.rx_crc_valid)
    {

    frame_length = TST_RX_LENGTH_struct.rx_length;

    if (frame_length > 127)
      frame_length = 127;

    print_packet((volatile uint8_t *) TRX_FRAME_BUFFER_OFFSET, 
        frame_length, 
        TST_RX_LENGTH_struct.rx_length,
        packet_channel);

    }
  }
}

void set_channel(uint8_t channel)
{
  if (channel > CHANNEL_MAX || channel < CHANNEL_BASE)
  {
    log_info("Invalid channel.");
    log_channel();
    return;
  }
  current_channel = channel;
  PHY_CC_CCA_struct.channel = channel;
  log_channel();
}

void hop_channel(int8_t dir)
{
  uint8_t new_channel;
  if(dir < 0)
    new_channel = current_channel - 1;
  else
    new_channel = current_channel + 1;

  if (new_channel > CHANNEL_MAX) 
    new_channel = CHANNEL_BASE;
  else if (new_channel < CHANNEL_BASE)
    new_channel = CHANNEL_MAX;

  set_channel(new_channel);
}

void rf_init(void)
{
  // Reset the tranceiver.
  TRXPR_struct.trxrst = 1;

  // Turn it off.
  TRX_STATE = CMD_FORCE_TRX_OFF;

  IRQ_STATUS = IRQ_STATUS_CLEAR_VALUE;
  IRQ_MASK_struct.rx_start_en = 1;
  IRQ_MASK_struct.rx_end_en = 1;

  // Set the initial channel.
  set_channel(CHANNEL_INIT);

  // Zero-out all the addresing.
  PAN_ID_0 = 0;
  PAN_ID_1 = 0;

  SHORT_ADDR_0 = 0;
  SHORT_ADDR_1 = 0;

  IEEE_ADDR_0 = 0;
  IEEE_ADDR_1 = 0;
  IEEE_ADDR_2 = 0;
  IEEE_ADDR_3 = 0;
  IEEE_ADDR_4 = 0;
  IEEE_ADDR_5 = 0;
  IEEE_ADDR_6 = 0;
  IEEE_ADDR_7 = 0;

  TRX_CTRL_2_struct.rx_safe_mode = 0;
  XAH_CTRL_1_struct.aack_ack_time = 0;
  XAH_CTRL_0_struct.slotted_operation = 0;
  CSMA_SEED_1_struct.aack_i_am_coord = 0;
  CSMA_SEED_1_struct.aack_set_pd = 0;
  CSMA_SEED_1_struct.aack_fvn_mode = 0;

  // Make sure we can receive reserved frames.
  XAH_CTRL_1_struct.aack_upld_res_ft = 1;
  // Ensure that we do not filter reserved stuff.
  XAH_CTRL_1_struct.aack_fltr_res_ft = 0;
  // Disable ACK'ng.
  CSMA_SEED_1_struct.aack_dis_ack = 1;
  // Enable promiscious mode.
  XAH_CTRL_1_struct.aack_prom_mode = 1;
}

int main()
{
  DDRF |= 0xFF;
  DDRE |= ((1 << DDE4) | (1 << DDE3));



  char cmd;
  unsigned int new_channel = 0;
  cli();
  led_init();
  uart_init();
  rf_init();
  sei();

  led_status_on();

  set_rf_state(CMD_RX_ON);

  log_info("Ready");
  log_channel();
  log_bad_crc_setting();

  while (1)
  {
    cmd = fgetc(stdin);
    switch(cmd) {
      case BADGE_CMD_CHAN_SET:
        fscanf(stdin, "%02x", &new_channel);
        set_channel(new_channel);
        break;
      case BADGE_CMD_CHAN_NEXT:
        hop_channel(1);
        break;
      case BADGE_CMD_CHAN_PREV:
        hop_channel(-1);
        break;
      case BADGE_CMD_CHAN_SHOW:
        log_channel();
        break;
      case BADGE_CMD_BAD_CRC_ALLOW:
        allow_bad_frames = 1;
        log_bad_crc_setting();
        break;
      case BADGE_CMD_BAD_CRC_DROP:
        allow_bad_frames = 0;
        log_bad_crc_setting();
        break;
      case BADGE_CMD_BAD_CRC_SHOW:
        log_bad_crc_setting();
        break;
      case BADGE_CMD_HELP:
        log_help(BADGE_CMD_CHAN_SET, "Set the channel. Expects two hex characters.");
        log_help(BADGE_CMD_CHAN_NEXT, "Hops to the next channel.");
        log_help(BADGE_CMD_CHAN_PREV, "Hops to the previous channel.");
        log_help(BADGE_CMD_CHAN_SHOW, "Shows the current channel.");
        log_help(BADGE_CMD_BAD_CRC_ALLOW, "Enables the capture of packets with bad CRC.");
        log_help(BADGE_CMD_BAD_CRC_DROP, "Disables the capture of packets with bad CRC.");
        log_help(BADGE_CMD_BAD_CRC_SHOW, "Shows the current bad CRC setting.");
        log_help(BADGE_CMD_CAP_START, "Enables the capture of packets.");
        log_help(BADGE_CMD_CAP_STOP, "Disables the capture of packets.");
        log_help(BADGE_CMD_HELP, "Prints useful stuff, like this.");
        break;
      case BADGE_CMD_CAP_START:
        packet_logging = 1; 
        break;
      case BADGE_CMD_CAP_STOP:
        packet_logging = 0; 
        break;
    }

  }

  return 0;
}
