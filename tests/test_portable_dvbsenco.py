#!/usr/bin/env python3
"""Compare the portable DVB-S encoder with the ARM32 assembly's table/offset logic."""

import ctypes
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src'


class PiInfo(ctypes.Structure):
    _fields_ = [('memory', ctypes.c_int), ('processor', ctypes.c_int),
                ('i2c_device', ctypes.c_int), ('model', ctypes.c_int),
                ('manufacturer', ctypes.c_int), ('pcb_revision', ctypes.c_int),
                ('warranty_bit', ctypes.c_int), ('revision_number', ctypes.c_int),
                ('peripheral_base', ctypes.c_uint32)]


def table(name, length):
    asm = (SRC / 'dvbsenco8.s').read_text()
    section = asm.split(f'{name}:', 1)[1].split('\n\n', 1)[0]
    values = bytes(int(value, 16) for value in re.findall(r'0x[0-9a-fA-F]+', section))
    assert len(values) == length
    return values


class AssemblyReference:
    def __init__(self):
        self.energy = table('energytable', 1504)
        self.log = table('reed1table', 256)
        self.rs = table('reed2table', 4096)
        self.slots = bytearray(32 * 256)
        self.count = 0
        self.energy_index = 0

    def encode(self, packet):
        packet = bytearray(packet)
        if self.count % 8 == 0:
            self.energy_index = 0
        packet[0] = 0xb8 if self.count % 8 == 0 else 0x47
        packet = bytearray(byte ^ mask for byte, mask in
                           zip(packet, self.energy[self.energy_index:self.energy_index + 188]))
        self.energy_index += 188
        packet.extend(bytes(17))
        for byte in packet[:188]:
            feedback = self.log[byte ^ packet[188]]
            if feedback == 0xff:
                packet[188:204] = packet[189:205]
            else:
                packet[188:204] = bytes(packet[189 + j] ^ self.rs[feedback * 16 + j]
                                        for j in range(16))
        slot = (self.count & 31) * 256
        for i, byte in enumerate(packet[:204]):
            self.slots[(slot + i + (i % 12) * 256) & 8191] = byte
        self.count += 1
        return bytes(self.slots[slot:slot + 204])


class PortableEncoderTest(unittest.TestCase):
    def test_legacy_table_and_interleaver_equivalence(self):
        with tempfile.TemporaryDirectory() as temp:
            temp = Path(temp)
            subprocess.run(['python3', str(SRC / 'generate_dvbsenco_tables.py'),
                            str(SRC / 'dvbsenco8.s'), str(temp / 'dvbsenco8_tables.h')], check=True)
            shutil.copyfile(SRC / 'dvbsenco8_portable.c', temp / 'dvbsenco8_portable.c')
            library = temp / 'encoder.so'
            subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', '-shared',
                            '-fPIC', str(temp / 'dvbsenco8_portable.c'),
                            '-o', str(library)], check=True)
            encoder = ctypes.CDLL(str(library))
            encoder.dvbsenco.argtypes = [ctypes.POINTER(ctypes.c_ubyte)]
            encoder.dvbsenco.restype = ctypes.POINTER(ctypes.c_ubyte)
            encoder.dvbsenco_init()
            reference = AssemblyReference()
            for n in range(96):
                packet = bytes([0x47] + [(n * 17 + i * 29) & 255 for i in range(187)])
                data = (ctypes.c_ubyte * 208)(*packet)
                actual = bytes(encoder.dvbsenco(data)[:204])
                self.assertEqual(actual, reference.encode(packet), f'packet {n}')
            encoder.dvbsenco_init()
            data = (ctypes.c_ubyte * 208)(*bytes([0x47] + [0] * 187))
            self.assertEqual(bytes(encoder.dvbsenco(data)[:204]),
                             AssemblyReference().encode(bytes([0x47] + [0] * 187)))

    def test_pi4_revision_uses_bcm2711_peripheral_base(self):
        with tempfile.TemporaryDirectory() as temp:
            library = Path(temp) / 'revision.so'
            subprocess.run(['cc', '-shared', '-fPIC', str(SRC / 'raspberry_pi_revision.c'),
                            '-o', str(library)], check=True)
            revision = ctypes.CDLL(str(library))
            revision.getRaspberryPiInformationForRevision.argtypes = [
                ctypes.c_int, ctypes.POINTER(PiInfo)]
            info = PiInfo()
            self.assertEqual(revision.getRaspberryPiInformationForRevision(0xc03111,
                                                                            ctypes.byref(info)), 2)
            self.assertEqual(info.processor, 2711)
            self.assertEqual(info.peripheral_base, 0xfe000000)

    def test_live_pi4_revision_when_running_on_pi4(self):
        model_path = Path('/proc/device-tree/model')
        if not model_path.exists() or b'Raspberry Pi 4' not in model_path.read_bytes():
            self.skipTest('requires Raspberry Pi 4')

        with tempfile.TemporaryDirectory() as temp:
            library = Path(temp) / 'revision.so'
            subprocess.run(['cc', '-shared', '-fPIC', str(SRC / 'raspberry_pi_revision.c'),
                            '-o', str(library)], check=True)
            revision = ctypes.CDLL(str(library))
            revision.getRaspberryPiInformation.argtypes = [ctypes.POINTER(PiInfo)]
            info = PiInfo()
            self.assertEqual(revision.getRaspberryPiInformation(ctypes.byref(info)), 2)
            self.assertEqual(info.processor, 2711)
            self.assertEqual(info.peripheral_base, 0xfe000000)


if __name__ == '__main__':
    unittest.main()
