#!/usr/bin/env python3
"""Offline MPEG-TS contract test; no Pi or capture hardware is required."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest


ENCODER = Path(__file__).resolve().parents[1] / "scripts/h264_ts_ffmpeg.sh"


class H264TsTest(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory(prefix="portsdown4-ntsc-")
        self.addCleanup(self.tempdir.cleanup)
        self.folder = Path(self.tempdir.name)

    def encode(self, output, standard, audio=False, deinterlace=False,
               video_encoder=None):
        args = [
            str(ENCODER), "--source", "testsrc", "--output", str(output),
            "--standard", standard, "--video-bitrate", "800000",
            "--muxrate", "1200000", "--duration", "2",
            "--pmt-pid", "4095", "--service-name", "NTSC Test",
        ]
        if audio:
            args += ["--audio-device", "testtone", "--audio-bitrate", "48000"]
        if deinterlace:
            args += ["--deinterlace"]
        if video_encoder:
            args += ["--video-encoder", video_encoder]
        subprocess.run(args, check=True, capture_output=True, text=True, timeout=30)

    def probe(self, output):
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-count_frames", "-show_programs",
             "-show_streams", "-of", "json", str(output)],
            check=True, capture_output=True, text=True, timeout=30,
        )
        return json.loads(result.stdout)

    def assert_transport_stream(self, output):
        data = output.read_bytes()
        self.assertGreater(len(data), 188 * 50)
        self.assertEqual(len(data) % 188, 0)
        self.assertTrue(all(data[index] == 0x47 for index in range(0, len(data), 188)))

    def assert_decodes(self, output):
        subprocess.run(
            ["ffmpeg", "-v", "error", "-xerror", "-i", str(output),
             "-map", "0", "-f", "null", "-"],
            check=True, capture_output=True, text=True, timeout=30,
        )

    def assert_ntsc_cadence(self, output):
        result = subprocess.run(
            ["ffprobe", "-v", "error", "-select_streams", "v:0",
             "-show_entries", "stream=time_base,r_frame_rate",
             "-show_entries", "frame=best_effort_timestamp",
             "-of", "json", str(output)],
            check=True, capture_output=True, text=True, timeout=30,
        )
        probe = json.loads(result.stdout)
        self.assertEqual(probe["streams"][0]["time_base"], "1/90000")
        self.assertEqual(probe["streams"][0]["r_frame_rate"], "30000/1001")
        timestamps = [int(frame["best_effort_timestamp"])
                      for frame in probe["frames"]]
        self.assertGreater(len(timestamps), 30)
        deltas = {next_pts - pts
                  for pts, next_pts in zip(timestamps, timestamps[1:])}
        self.assertEqual(deltas, {3003})

    def test_ntsc_video_and_audio(self):
        output = self.folder / "ntsc.ts"
        self.encode(output, "ntsc", audio=True)
        self.assert_transport_stream(output)
        self.assert_decodes(output)
        program = self.probe(output)["programs"][0]
        self.assertEqual(program["pmt_pid"], 4095)
        self.assertEqual(program["pcr_pid"], 4096)
        self.assertEqual(program["tags"]["service_name"], "NTSC Test")
        video, audio = program["streams"]
        self.assertEqual((video["codec_name"], video["width"], video["height"]),
                         ("h264", 720, 480))
        self.assert_ntsc_cadence(output)
        self.assertEqual(video["id"], "0x1000")
        self.assertEqual(audio["codec_name"], "aac")
        self.assertEqual(audio["id"], "0x1001")

    def test_pal_video(self):
        output = self.folder / "pal.ts"
        self.encode(output, "pal")
        self.assert_transport_stream(output)
        self.assert_decodes(output)
        video = self.probe(output)["streams"][0]
        self.assertEqual((video["width"], video["height"], video["avg_frame_rate"]),
                         (720, 576, "25/1"))

    def test_auto_encoder_produces_valid_ntsc(self):
        output = self.folder / "ntsc-auto.ts"
        self.encode(output, "ntsc", video_encoder="auto")
        self.assert_transport_stream(output)
        self.assert_decodes(output)
        self.assert_ntsc_cadence(output)

    def test_fifo_output_used_by_rf_modulators(self):
        fifo = self.folder / "videots"
        output = self.folder / "captured.ts"
        os.mkfifo(fifo)
        received = []

        def drain_fifo():
            with fifo.open("rb") as source:
                received.append(source.read())

        reader = threading.Thread(target=drain_fifo, daemon=True)
        reader.start()
        self.encode(fifo, "ntsc", deinterlace=True)
        reader.join(timeout=5)
        self.assertFalse(reader.is_alive(), "encoder did not close the FIFO")
        output.write_bytes(received[0])
        self.assert_transport_stream(output)


if __name__ == "__main__":
    unittest.main()
