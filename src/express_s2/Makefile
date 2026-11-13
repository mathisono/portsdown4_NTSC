CXX ?= g++
LIBDVBMOD_DIR ?= ../limesdr_toolbox/libdvbmod/libdvbmod
CXXFLAGS ?= -O2 -Wall -Wextra -std=c++17
CXXFLAGS += -I$(LIBDVBMOD_DIR) -I../dvb_t_stack/src $(shell pkg-config --cflags libusb-1.0)
LDLIBS += $(LIBDVBMOD_DIR)/lib/libdvbmod.a $(shell pkg-config --libs libusb-1.0) -lm -pthread

.PHONY: all clean
all: express_s2

express_s2: express_s2.cpp ../dvb_t_stack/src/express.cpp $(LIBDVBMOD_DIR)/lib/libdvbmod.a
	$(CXX) $(CXXFLAGS) $< ../dvb_t_stack/src/express.cpp -o $@ $(LDLIBS)

clean:
	rm -f express_s2
