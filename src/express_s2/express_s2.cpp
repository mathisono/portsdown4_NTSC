// Experimental DVB-S2 I/Q sender for the DATV-Express raw-16 USB firmware.
// Not connected to the Portsdown GUI. Default mode never opens USB or RF.
#include <cerrno>
#include <csignal>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <getopt.h>
#include <limits>
#include <type_traits>

#include "libdvbmod.h"
#include "express.h"

static volatile std::sig_atomic_t stop_requested = 0;

static void request_stop(int)
{
    stop_requested = 1;
}

static void usage(const char *program)
{
    std::fprintf(stderr,
        "Usage: %s [--input TS_FILE] [--symbol-rate HZ] [--max-packets N] "
        "[--tx --frequency HZ]\n"
        "Default: offline QPSK 1/2 DVB-S2 probe with 1000 null packets.\n"
        "--tx requires a TS input and RF frequency; output is held at maximum "
        "attenuation.\n", program);
}

static bool parse_positive_int(const char *text, int *value)
{
    if (text == nullptr || *text == '\0') return false;
    char *end = nullptr;
    errno = 0;
    const long parsed = std::strtol(text, &end, 10);
    if (errno != 0 || *end != '\0' || parsed <= 0 ||
        parsed > std::numeric_limits<int>::max()) return false;
    *value = static_cast<int>(parsed);
    return true;
}

static bool parse_frequency(const char *text, uint64_t *value)
{
    if (text == nullptr || *text == '\0') return false;
    char *end = nullptr;
    errno = 0;
    const unsigned long long parsed = std::strtoull(text, &end, 10);
    if (errno != 0 || *end != '\0' || parsed < 100000000ULL ||
        parsed > 3000000000ULL) return false;
    *value = parsed;
    return true;
}

int main(int argc, char **argv)
{
    static const option options[] = {
        {"input", required_argument, nullptr, 'i'},
        {"symbol-rate", required_argument, nullptr, 's'},
        {"frequency", required_argument, nullptr, 'f'},
        {"max-packets", required_argument, nullptr, 'n'},
        {"tx", no_argument, nullptr, 't'},
        {"help", no_argument, nullptr, 'h'},
        {nullptr, 0, nullptr, 0}
    };
    const char *input_path = nullptr;
    int symbol_rate = 333000;
    uint64_t frequency = 0;
    int max_packets = 0;
    bool transmit = false;
    while (true) {
        const int opt = getopt_long(argc, argv, "i:s:f:n:th", options, nullptr);
        if (opt == -1) break;
        switch (opt) {
        case 'i': input_path = optarg; break;
        case 's':
            if (!parse_positive_int(optarg, &symbol_rate) || symbol_rate > 10000000) {
                usage(argv[0]); return 2;
            }
            break;
        case 'f':
            if (!parse_frequency(optarg, &frequency)) { usage(argv[0]); return 2; }
            break;
        case 'n':
            if (!parse_positive_int(optarg, &max_packets)) { usage(argv[0]); return 2; }
            break;
        case 't': transmit = true; break;
        case 'h': usage(argv[0]); return 0;
        default: usage(argv[0]); return 2;
        }
    }
    if (optind != argc || (transmit && (!input_path || !frequency)) ||
        (!transmit && frequency)) {
        usage(argv[0]);
        return 2;
    }
    if (!input_path && max_packets == 0) max_packets = 1000;

    FILE *input = nullptr;
    if (input_path) {
        input = std::strcmp(input_path, "-") == 0 ? stdin : std::fopen(input_path, "rb");
        if (!input) {
            std::perror(input_path);
            return 1;
        }
    }

    // The raw-16 board path, like G4GUO's Windows S2 path, accepts one
    // physical-layer complex symbol per input symbol. No rate change here.
    const int net_bitrate = Dvbs2Init(symbol_rate, CR_1_2, M_QPSK,
                                     0, RO_0_35, 1, false);
    if (net_bitrate <= 0) {
        std::fprintf(stderr, "DVB-S2 modulator initialization failed\n");
        if (input && input != stdin) std::fclose(input);
        return 1;
    }

    if (transmit) {
        std::signal(SIGINT, request_stop);
        std::signal(SIGTERM, request_stop);
        if (express_init("datvexpress16.ihx", "datvexpressraw16.rbf") != EXP_OK) {
            std::fprintf(stderr, "DATV-Express raw-16 initialization failed\n");
            if (input && input != stdin) std::fclose(input);
            return 1;
        }
        express_set_level(47); // Maximum built-in attenuation for bring-up.
        express_set_freq(static_cast<double>(frequency));
        if (express_set_sr(symbol_rate) < 0) {
            std::fprintf(stderr, "DATV-Express symbol-rate setup failed\n");
            express_deinit();
            if (input && input != stdin) std::fclose(input);
            return 1;
        }
    }

    static_assert(sizeof(sfcmplx) == sizeof(scmplx), "I/Q sample size differs");
    static_assert(alignof(sfcmplx) == alignof(scmplx), "I/Q alignment differs");
    uint8_t packet[188] = {0x47, 0x1f, 0xff, 0x10};
    int packets = 0;
    int frames = 0;
    long long samples_sent = 0;
    int result = 0;
    bool tx_enabled = false;
    while (!stop_requested && (max_packets == 0 || packets < max_packets)) {
        if (input) {
            const size_t bytes = std::fread(packet, 1, sizeof(packet), input);
            if (bytes == 0 && std::feof(input)) break;
            if (bytes != sizeof(packet)) {
                std::fprintf(stderr, "Short or failed TS packet read\n");
                result = 1;
                break;
            }
            if (packet[0] != 0x47) {
                std::fprintf(stderr, "MPEG-TS sync byte missing at packet %d\n", packets);
                result = 1;
                break;
            }
        } else {
            packet[3] = static_cast<uint8_t>(0x10 | (packets & 0x0f));
        }
        const int sample_count = Dvbs2AddTsPacket(packet);
        ++packets;
        if (sample_count <= 0) continue;
        const sfcmplx *frame = Dvbs2_get_IQ();
        if (!frame || sample_count > 130000) {
            std::fprintf(stderr, "Invalid DVB-S2 I/Q frame\n");
            result = 1;
            break;
        }
        if (transmit) {
            if (!tx_enabled) {
                express_transmit();
                tx_enabled = true;
            }
            if (express_write_16_bit_samples_checked(
                    reinterpret_cast<const scmplx *>(frame), sample_count) < 0) {
                std::fprintf(stderr, "DATV-Express USB I/Q transfer failed\n");
                result = 1;
                break;
            }
        }
        ++frames;
        samples_sent += sample_count;
    }

    if (transmit) express_deinit(); // Returns the board to receive mode.
    if (input && input != stdin) std::fclose(input);
    std::fprintf(stderr, "mode=%s net_bitrate=%d packets=%d frames=%d samples=%lld\n",
                 transmit ? "tx" : "offline", net_bitrate, packets, frames, samples_sent);
    if (frames == 0) return 1;
    return result;
}
