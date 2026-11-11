/* Portable equivalent of the DVB-S energy, RS(204,188) and convolutional
 * interleaver stages in dvbsenco8.s. The assembly tables are generated into
 * dvbsenco8_tables.h at build time to keep one source of constants. */
#include <stdint.h>
#include <string.h>

#include "dvbsenco8_tables.h"

enum { PACKET_BYTES = 188, CODED_BYTES = 204, PACKET_SLOTS = 32,
       SLOT_BYTES = 256, INTERLEAVER_BYTES = PACKET_SLOTS * SLOT_BYTES };

static uint8_t interleaved[INTERLEAVER_BYTES];
static uint32_t packet_count;
static unsigned energy_index;

void dvbsenco_init(void)
{
    memset(interleaved, 0, sizeof(interleaved));
    packet_count = 0;
    energy_index = 0;
}

void energy(unsigned char *input, unsigned char *output)
{
    unsigned index = energy_index;
    unsigned i;
    if ((packet_count & 7) == 0)
        index = 0;
    input[0] = (packet_count & 7) == 0 ? 0xb8 : 0x47;
    for (i = 0; i < PACKET_BYTES; ++i)
        output[i] = input[i] ^ energytable[index + i];
    energy_index = index + PACKET_BYTES;
}

void reed(unsigned char *packet)
{
    unsigned i, j;
    /* One extra zero byte is read when the 16 parity bytes shift. */
    memset(packet + PACKET_BYTES, 0, 17);
    for (i = 0; i < PACKET_BYTES; ++i) {
        unsigned feedback = reed1table[packet[i] ^ packet[PACKET_BYTES]];
        if (feedback == 0xff) {
            memmove(packet + PACKET_BYTES, packet + PACKET_BYTES + 1, 15);
            packet[PACKET_BYTES + 15] = 0;
        } else {
            for (j = 0; j < 16; ++j)
                packet[PACKET_BYTES + j] =
                    packet[PACKET_BYTES + j + 1] ^ reed2table[feedback * 16 + j];
        }
    }
}

unsigned char *interleave(unsigned char *packet)
{
    unsigned slot = (packet_count & (PACKET_SLOTS - 1)) * SLOT_BYTES;
    unsigned i;
    for (i = 0; i < CODED_BYTES; ++i) {
        unsigned offset = i + ((i % 12) * SLOT_BYTES);
        interleaved[(slot + offset) & (INTERLEAVER_BYTES - 1)] = packet[i];
    }
    ++packet_count;
    return interleaved + slot;
}

unsigned char *dvbsenco(unsigned char *packet)
{
    uint8_t work[CODED_BYTES + 1];
    energy(packet, work);
    reed(work);
    return interleave(work);
}
