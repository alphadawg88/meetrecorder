#!/usr/bin/env python3
"""
Dual-channel meeting recorder for macOS.
Records microphone + system audio (via Background Music loopback) simultaneously.
Saves separate tracks + a combined stereo file (L=mic, R=system).
Streams to disk incrementally to avoid unbounded memory growth on long meetings.
"""
import sys
import os
import datetime
import argparse
import signal

import sounddevice as sd
import soundfile as sf
import numpy as np


DEFAULT_OUTPUT_DIR = os.path.expanduser("~/Desktop/recordings")
DEFAULT_SYSTEM_DEVICE_NAME = "Background Music"
DEFAULT_SAMPLERATE = 48000


def find_device_index(name_substring, kind="input"):
    devices = sd.query_devices()
    exact_match = None
    substring_match = None
    for i, dev in enumerate(devices):
        dev_name = dev["name"]
        if kind == "input" and dev["max_input_channels"] <= 0:
            continue
        if kind == "output" and dev["max_output_channels"] <= 0:
            continue
        if dev_name.lower() == name_substring.lower():
            exact_match = i
        elif substring_match is None and name_substring.lower() in dev_name.lower():
            substring_match = i
    return exact_match if exact_match is not None else substring_match


def list_devices():
    print("\nAvailable input devices:")
    devices = sd.query_devices()
    for i, dev in enumerate(devices):
        if dev["max_input_channels"] > 0:
            marker = " [DEFAULT]" if i == sd.default.device[0] else ""
            print(f"  {i}: {dev['name']} — {dev['max_input_channels']} ch{marker}")
    print()


def record_dual(base_path, mic_device=None, system_device=None, samplerate=DEFAULT_SAMPLERATE):
    os.makedirs(os.path.dirname(base_path) or ".", exist_ok=True)

    mic_idx = mic_device if mic_device is not None else sd.default.device[0]
    sys_idx = system_device if system_device is not None else find_device_index(DEFAULT_SYSTEM_DEVICE_NAME)

    if sys_idx is None:
        print(f"ERROR: '{DEFAULT_SYSTEM_DEVICE_NAME}' input device not found.")
        print("Ensure Background Music is installed and its app is running.")
        sys.exit(1)

    mic_name = sd.query_devices(mic_idx)["name"]
    sys_name = sd.query_devices(sys_idx)["name"]
    print(f"Mic   : {mic_name} (idx {mic_idx})")
    print(f"System: {sys_name} (idx {sys_idx})")
    print("Press Ctrl+C to stop...\n")

    mic_path = f"{base_path}_mic.wav"
    sys_path = f"{base_path}_system.wav"
    comb_path = f"{base_path}_combined.wav"

    running = True

    # Determine channel counts
    mic_ch = min(sd.query_devices(mic_idx)["max_input_channels"], 1)
    sys_ch = min(sd.query_devices(sys_idx)["max_input_channels"], 2)

    mic_file = sf.SoundFile(mic_path, mode="w", samplerate=samplerate, channels=mic_ch, subtype="PCM_16")
    sys_file = sf.SoundFile(sys_path, mode="w", samplerate=samplerate, channels=sys_ch, subtype="PCM_16")

    def mic_callback(indata, frames, time_info, status):
        if status:
            print(f"Mic status: {status}", file=sys.stderr)
        mic_file.write(indata)

    def sys_callback(indata, frames, time_info, status):
        if status:
            print(f"System status: {status}", file=sys.stderr)
        sys_file.write(indata)

    def stop_handler(signum, frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGINT, stop_handler)
    signal.signal(signal.SIGTERM, stop_handler)

    try:
        with sd.InputStream(device=mic_idx, samplerate=samplerate, channels=mic_ch, dtype=np.float32, callback=mic_callback), \
             sd.InputStream(device=sys_idx, samplerate=samplerate, channels=sys_ch, dtype=np.float32, callback=sys_callback):
            while running:
                sd.sleep(100)
    finally:
        mic_file.close()
        sys_file.close()

    # Build combined stereo file from the two on-disk recordings
    try:
        mic_audio, _ = sf.read(mic_path, dtype="float32")
        sys_audio, _ = sf.read(sys_path, dtype="float32")
    except Exception as e:
        print(f"ERROR reading recorded files for combine: {e}", file=sys.stderr)
        sys.exit(1)

    if len(mic_audio) == 0 or len(sys_audio) == 0:
        print("No audio captured on one or both channels.")
        return

    # Ensure same length
    min_len = min(len(mic_audio), len(sys_audio))
    mic_audio = mic_audio[:min_len]
    sys_audio = sys_audio[:min_len]

    # Convert mic to mono if needed
    if mic_audio.ndim > 1:
        mic_audio = mic_audio.mean(axis=1)

    # Convert system to mono for combined mix
    if sys_audio.ndim > 1:
        sys_mono = sys_audio.mean(axis=1)
    else:
        sys_mono = sys_audio

    # Combined stereo: L = mic, R = system
    combined = np.column_stack((mic_audio, sys_mono))
    sf.write(comb_path, combined, samplerate)

    duration = min_len / samplerate
    print(f"\nSaved {duration:.1f}s:")
    print(f"  Mic      : {mic_path}")
    print(f"  System   : {sys_path}")
    print(f"  Combined : {comb_path}")


def main():
    parser = argparse.ArgumentParser(description="Dual meeting recorder (mic + system audio)")
    parser.add_argument("--list", action="store_true", help="List input devices")
    parser.add_argument("--device", type=int, default=None, help="Microphone device index")
    parser.add_argument("--system-device", type=int, default=None, help="System audio device index (default: Background Music)")
    parser.add_argument("--name", type=str, default=None, help="Base name for output files")
    parser.add_argument("--out-dir", type=str, default=DEFAULT_OUTPUT_DIR, help="Output directory")
    args = parser.parse_args()

    if args.list:
        list_devices()
        return

    name = args.name or datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    base_path = os.path.join(os.path.expanduser(args.out_dir), name)
    record_dual(base_path, mic_device=args.device, system_device=args.system_device)


if __name__ == "__main__":
    main()
