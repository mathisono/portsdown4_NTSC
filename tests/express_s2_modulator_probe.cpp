// Offline native-build probe for the external F5OEO libdvbmod dependency.
// This does not open the DATV-Express USB board or assert RF correctness.
#include <cstdint>
#include <cstdio>

#include "libdvbmod.h"

int main()
{
    constexpr int symbol_rate = 333000;
    constexpr int upsample = 2;
    const int net_bitrate = Dvbs2Init(symbol_rate, CR_1_2, M_QPSK,
                                     0, RO_0_35, upsample, false);
    if (net_bitrate <= 0) {
        std::fprintf(stderr, "DVB-S2 initialization failed\n");
        return 1;
    }

    uint8_t null_packet[188] = {0x47, 0x1f, 0xff, 0x10};
    for (int packet_number = 0; packet_number < 4000; ++packet_number) {
        null_packet[3] = static_cast<uint8_t>(0x10 | (packet_number & 0x0f));
        const int samples = Dvbs2AddTsPacket(null_packet);
        if (samples <= 0)
            continue;
        if (samples > 130000) {
            std::fprintf(stderr, "Unexpected DVB-S2 frame length: %d\n", samples);
            return 1;
        }
        const sfcmplx *frame = Dvbs2_get_IQ();
        if (frame == nullptr) {
            std::fprintf(stderr, "DVB-S2 modulator returned no I/Q frame\n");
            return 1;
        }
        bool nonzero = false;
        for (int i = 0; i < samples; ++i)
            nonzero |= (frame[i].re != 0 || frame[i].im != 0);
        if (!nonzero) {
            std::fprintf(stderr, "DVB-S2 I/Q frame is all zero\n");
            return 1;
        }
        std::printf("DVB-S2 I/Q generated: net_bitrate=%d samples=%d first_iq=%d,%d\n",
                    net_bitrate, samples, frame[0].re, frame[0].im);
        return 0;
    }

    std::fprintf(stderr, "DVB-S2 modulator produced no frame after 4000 packets\n");
    return 1;
}
