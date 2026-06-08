#!/usr/bin/env python3
"""
Meeting recorder for macOS.
Captures microphone + system audio (via Background Music virtual device).
Saves mic, system, and combined stereo (L=mic, R=system) WAV files.
"""
import sys
import os
import signal
import datetime
import argparse
import subprocess
import time
import threading

import sounddevice as sd
import soundfile as sf
import numpy as np


def list_devices():
    print("\nAvailable input devices (microphones):")
    devices = sd.query_devices()
    for i, dev in enumerate(devices):
        if dev["max_input_channels"] > 0:
            marker = " [DEFAULT IN]" if i == sd.default.device[0] else ""
            print(f"  {i}: {dev['name']} — {dev['max_input_channels']} ch{marker}")
    print("\nAvailable output devices:")
    for i, dev in enumerate(devices):
        if dev["max_output_channels"] > 0:
            marker = " [DEFAULT OUT]" if i == sd.default.device[1] else ""
            print(f"  {i}: {dev['name']} — {dev['max_output_channels']} ch{marker}")
    print()


def get_default_output_name():
    try:
        return sd.query_devices(kind="output")["name"]
    except Exception:
        return None


def set_default_output(name_substring):
    tool = os.path.expanduser("~/.hermes/scripts/set-default-output")
    if os.path.exists(tool):
        try:
            subprocess.run([tool, name_substring], check=True, capture_output=True)
            return True
        except Exception:
            pass
    return False


def launch_background_music():
    try:
        subprocess.run(["pgrep", "-x", "Background Music"], check=True, capture_output=True)
    except subprocess.CalledProcessError:
        subprocess.Popen(["open", "-a", "Background Music"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1.5)


def find_device_index_by_name(substring):
    devices = sd.query_devices()
    for i, dev in enumerate(devices):
        if substring.lower() in dev["name"].lower() and dev["max_input_channels"] > 0:
            return i
    return None


def record(output_path, device=None, samplerate=48000, channels=1):
    """Simple single-device recorder (legacy mode)."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    if device is not None:
        sd.default.device = (device, sd.default.device[1])

    print(f"Recording from: {sd.query_devices(sd.default.device[0])['name']}")
    print(f"Output: {output_path}")
    print("Press Ctrl+C to stop recording...\n")

    buffer = []

    def callback(indata, frames, time_info, status):
        if status:
            print(f"Status: {status}", file=sys.stderr)
        buffer.append(indata.copy())

    try:
        with sd.InputStream(
            samplerate=samplerate,
            channels=channels,
            dtype=np.float32,
            callback=callback,
        ):
            while True:
                sd.sleep(1000)
    except KeyboardInterrupt:
        pass

    if not buffer:
        print("No audio captured.")
        return

    audio = np.concatenate(buffer, axis=0)
    sf.write(output_path, audio, samplerate)
    duration = len(audio) / samplerate
    print(f"\nSaved {duration:.1f}s to {output_path}")


def record_dual(out_dir, name, mic_device=None, system_device_name="Background Music"):
    """Record mic + system audio simultaneously, save combined stereo."""
    os.makedirs(out_dir, exist_ok=True)

    # Setup: save current output, switch to Background Music, launch app
    original_output = get_default_output_name()
    launch_background_music()
    if original_output and system_device_name.lower() not in original_output.lower():
        set_default_output(system_device_name)
        time.sleep(0.5)

    # Find devices
    mic_idx = mic_device if mic_device is not None else sd.default.device[0]
    system_idx = find_device_index_by_name(system_device_name)

    if system_idx is None:
        print(f"System audio device '{system_device_name}' not found. Falling back to mic-only.")
        out_file = os.path.join(out_dir, f"{name}.wav")
        record(out_file, device=mic_idx)
        return out_file, None, None

    mic_name = sd.query_devices(mic_idx)["name"]
    system_name = sd.query_devices(system_idx)["name"]

    mic_path = os.path.join(out_dir, f"{name}_mic.wav")
    system_path = os.path.join(out_dir, f"{name}_system.wav")
    combined_path = os.path.join(out_dir, f"{name}_combined.wav")

    print(f"Mic:      {mic_name} (dev {mic_idx})")
    print(f"System:   {system_name} (dev {system_idx})")
    print(f"Output:   {combined_path}")
    print("Press Ctrl+C to stop recording...\n")

    mic_buffer = []
    system_buffer = []
    stop_event = threading.Event()

    def mic_callback(indata, frames, time_info, status):
        if status:
            print(f"Mic status: {status}", file=sys.stderr)
        mic_buffer.append(indata.copy())

    def system_callback(indata, frames, time_info, status):
        if status:
            print(f"System status: {status}", file=sys.stderr)
        system_buffer.append(indata.copy())

    mic_stream = sd.InputStream(device=mic_idx, samplerate=48000, channels=1, dtype=np.float32, callback=mic_callback)
    system_stream = sd.InputStream(device=system_idx, samplerate=48000, channels=2, dtype=np.float32, callback=system_callback)

    mic_stream.start()
    system_stream.start()

    try:
        while not stop_event.is_set():
            sd.sleep(100)
    except KeyboardInterrupt:
        pass

    mic_stream.stop()
    system_stream.stop()
    mic_stream.close()
    system_stream.close()

    # Restore original output
    if original_output and system_device_name.lower() not in original_output.lower():
        set_default_output(original_output)

    if not mic_buffer or not system_buffer:
        print("No audio captured.")
        return None, None, None

    mic_audio = np.concatenate(mic_buffer, axis=0)
    system_audio = np.concatenate(system_buffer, axis=0)

    # Save individual files
    sf.write(mic_path, mic_audio, 48000)
    sf.write(system_path, system_audio, 48000)

    # Create combined stereo: L = mic, R = system (downmixed to mono)
    min_len = min(len(mic_audio), len(system_audio))
    mic_mono = mic_audio[:min_len, 0] if mic_audio.ndim > 1 else mic_audio[:min_len]
    system_mono = system_audio[:min_len].mean(axis=1) if system_audio.ndim > 1 else system_audio[:min_len]

    # Ensure both are 1D
    mic_mono = np.asarray(mic_mono).flatten()
    system_mono = np.asarray(system_mono).flatten()

    stereo = np.column_stack((mic_mono, system_mono))
    sf.write(combined_path, stereo, 48000)

    duration = min_len / 48000
    print(f"\nSaved {duration:.1f}s:")
    print(f"  Mic:      {mic_path}")
    print(f"  System:   {system_path}")
    print(f"  Combined: {combined_path}")

    return mic_path, system_path, combined_path


def main():
    parser = argparse.ArgumentParser(description="Record meeting audio on macOS")
    parser.add_argument("--list", action="store_true", help="List audio devices")
    parser.add_argument("--device", type=int, default=None, help="Input device index for mic")
    parser.add_argument("--out", type=str, default=None, help="Output file path (legacy single-device mode)")
    parser.add_argument("--name", type=str, default=None, help="Base name for files")
    parser.add_argument("--system", type=str, default="Background Music", help="System audio device name substring")
    parser.add_argument("--mic-only", action="store_true", help="Record microphone only (no system audio)")
    args = parser.parse_args()

    if args.list:
        list_devices()
        return

    out_dir = os.path.expanduser("~/Desktop/recordings")
    name = args.name or datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    if args.out:
        # Legacy single-file mode
        record(args.out, device=args.device)
    elif args.mic_only:
        out_file = os.path.join(out_dir, f"{name}.wav")
        record(out_file, device=args.device)
    else:
        record_dual(out_dir, name, mic_device=args.device, system_device_name=args.system)


if __name__ == "__main__":
    main()
