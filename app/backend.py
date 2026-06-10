#!/usr/bin/env python3
"""
MeetRecorder Backend API
Wraps the existing Python scripts and provides a REST API for the frontend.
"""
import os
import sys
import json
import glob
import time
import signal
import subprocess
import threading
from datetime import datetime
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

PROJECT_ROOT = os.environ.get("MEETRECORDER_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN_DIR = os.path.join(PROJECT_ROOT, "bin")
PYTHON_DIR = os.path.join(PROJECT_ROOT, "src/python")
DEFAULT_OUTPUT_DIR = os.path.expanduser("~/Desktop/recordings")
PID_FILE = "/tmp/meetrecord.pid"
LAST_FILE = "/tmp/meetrecord.lastfile"
SETTINGS_FILE = os.path.expanduser("~/.config/meetrecorder/settings.json")

STATIC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
app = Flask(__name__, static_folder=STATIC_DIR, static_url_path="")
CORS(app)

# ── Helpers ──────────────────────────────────────────────────────────────────

def _run(cmd, **kwargs):
    env = os.environ.copy()
    env["PATH"] = f"{BIN_DIR}:{os.path.expanduser('~/bin')}:{env.get('PATH', '')}"
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, env=env, **kwargs)

def _get_pid():
    try:
        with open(PID_FILE) as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None

def _is_recording():
    pid = _get_pid()
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, OSError):
        return False

def _get_settings():
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {
            "outputDir": DEFAULT_OUTPUT_DIR,
            "micDevice": None,
            "systemDevice": "Background Music",
            "sampleRate": 48000,
            "whisperModel": "base",
            "autoTranscribe": False,
            "language": "auto",
            "launchAtLogin": False,
            "menuBarStyle": "icon",
        }

def _save_settings(settings):
    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
    with open(SETTINGS_FILE, "w") as f:
        json.dump(settings, f, indent=2)

def _list_recordings():
    out_dir = _get_settings().get("outputDir", DEFAULT_OUTPUT_DIR)
    out_dir = os.path.expanduser(out_dir)
    if not os.path.isdir(out_dir):
        return []
    files = []
    for path in glob.glob(os.path.join(out_dir, "*.wav")):
        basename = os.path.basename(path)
        stat = os.stat(path)
        name, ext = os.path.splitext(basename)
        # Determine type from suffix
        if "_mic" in name:
            track_type = "mic"
            base_name = name.replace("_mic", "")
        elif "_system" in name:
            track_type = "system"
            base_name = name.replace("_system", "")
        elif "_combined" in name:
            track_type = "combined"
            base_name = name.replace("_combined", "")
        else:
            track_type = "single"
            base_name = name
        
        # Check for transcript/insights
        transcript_path = os.path.join(out_dir, base_name + "_transcript.txt")
        insights_path = os.path.join(out_dir, base_name + "_insights.md")
        has_transcript = os.path.exists(transcript_path)
        has_insights = os.path.exists(insights_path)
        
        # Duration estimate from file size (rough: 48kHz stereo 16bit = 192KB/s)
        duration = stat.st_size / 192000 if track_type in ("combined", "single") else stat.st_size / 96000
        
        files.append({
            "id": base_name,
            "filename": basename,
            "path": path,
            "type": track_type,
            "baseName": base_name,
            "size": stat.st_size,
            "modified": stat.st_mtime,
            "duration": round(duration, 1),
            "hasTranscript": has_transcript,
            "hasInsights": has_insights,
            "transcriptPath": transcript_path if has_transcript else None,
            "insightsPath": insights_path if has_insights else None,
        })
    # Group by base name
    groups = {}
    for f in files:
        bid = f["baseName"]
        if bid not in groups:
            groups[bid] = {
                "id": bid,
                "baseName": bid,
                "modified": f["modified"],
                "tracks": [],
                "duration": 0,
                "hasTranscript": False,
                "hasInsights": False,
            }
        groups[bid]["tracks"].append(f)
        groups[bid]["modified"] = max(groups[bid]["modified"], f["modified"])
        groups[bid]["duration"] = max(groups[bid]["duration"], f["duration"])
        if f["hasTranscript"]:
            groups[bid]["hasTranscript"] = True
            groups[bid]["transcriptPath"] = f["transcriptPath"]
        if f["hasInsights"]:
            groups[bid]["hasInsights"] = True
            groups[bid]["insightsPath"] = f["insightsPath"]
    
    result = sorted(groups.values(), key=lambda x: x["modified"], reverse=True)
    return result

# ── API Routes ───────────────────────────────────────────────────────────────

@app.route("/api/status")
def api_status():
    recording = _is_recording()
    pid = _get_pid()
    name = None
    if os.path.exists(LAST_FILE):
        with open(LAST_FILE) as f:
            name = f.read().strip()
    return jsonify({
        "recording": recording,
        "pid": pid,
        "recordingName": name,
        "settings": _get_settings(),
    })

@app.route("/api/start", methods=["POST"])
def api_start():
    if _is_recording():
        return jsonify({"error": "Already recording"}), 409
    data = request.get_json(silent=True) or {}
    name = data.get("name")
    device = data.get("device")
    cmd_parts = [sys.executable, os.path.join(PROJECT_ROOT, "bin/meetrecord")]
    if name:
        cmd_parts += ["--name", name]
    if device is not None:
        cmd_parts += ["--device", str(device)]
    env = os.environ.copy()
    env["PATH"] = f"{BIN_DIR}:{os.path.expanduser('~/bin')}:{env.get('PATH', '')}"
    proc = subprocess.Popen(cmd_parts, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    # Wait briefly for PID file to be written
    for _ in range(20):
        if os.path.exists(PID_FILE):
            break
        time.sleep(0.1)
    return jsonify({"started": True, "pid": proc.pid})

@app.route("/api/stop", methods=["POST"])
def api_stop():
    if not _is_recording():
        return jsonify({"error": "Not recording"}), 409
    data = request.get_json(silent=True) or {}
    transcribe = data.get("transcribe", False)
    model = data.get("model", _get_settings().get("whisperModel", "base"))
    cmd = [sys.executable, os.path.join(PROJECT_ROOT, "bin/meetstop")]
    if transcribe:
        cmd += ["--transcribe", "--model", model]
    env = os.environ.copy()
    env["PATH"] = f"{BIN_DIR}:{os.path.expanduser('~/bin')}:{env.get('PATH', '')}"
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    return jsonify({"stopped": True})

@app.route("/api/recordings")
def api_recordings():
    return jsonify(_list_recordings())

@app.route("/api/recording/<recording_id>/transcribe", methods=["POST"])
def api_transcribe(recording_id):
    settings = _get_settings()
    out_dir = os.path.expanduser(settings.get("outputDir", DEFAULT_OUTPUT_DIR))
    # Find the combined or single file for this recording
    combined = os.path.join(out_dir, f"{recording_id}_combined.wav")
    single = os.path.join(out_dir, f"{recording_id}.wav")
    target = combined if os.path.exists(combined) else (single if os.path.exists(single) else None)
    if not target:
        return jsonify({"error": "Recording not found"}), 404
    model = request.get_json(silent=True) or {}
    model_name = model.get("model", settings.get("whisperModel", "base"))
    env = os.environ.copy()
    env["PATH"] = f"{BIN_DIR}:{os.path.expanduser('~/bin')}:{env.get('PATH', '')}"
    subprocess.Popen([
        sys.executable,
        os.path.join(PROJECT_ROOT, "src/python/mac-transcribe.py"),
        target,
        "--model", model_name,
    ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    return jsonify({"transcribing": True})

@app.route("/api/recording/<recording_id>/transcript")
def api_transcript(recording_id):
    settings = _get_settings()
    out_dir = os.path.expanduser(settings.get("outputDir", DEFAULT_OUTPUT_DIR))
    path = os.path.join(out_dir, f"{recording_id}_transcript.txt")
    if not os.path.exists(path):
        return jsonify({"error": "Transcript not found"}), 404
    with open(path) as f:
        text = f.read()
    # Simple line splitting with timestamps (heuristic)
    lines = []
    for para in text.split("\n"):
        para = para.strip()
        if not para:
            continue
        lines.append({"speaker": "Speaker", "timestamp": "--:--", "text": para})
    return jsonify({"text": text, "lines": lines})

@app.route("/api/recording/<recording_id>/insights")
def api_insights(recording_id):
    settings = _get_settings()
    out_dir = os.path.expanduser(settings.get("outputDir", DEFAULT_OUTPUT_DIR))
    path = os.path.join(out_dir, f"{recording_id}_insights.md")
    if not os.path.exists(path):
        return jsonify({"error": "Insights not found"}), 404
    with open(path) as f:
        text = f.read()
    # Parse sections
    sections = {"decisions": [], "actions": [], "risks": [], "full": text}
    current = None
    for line in text.split("\n"):
        if line.startswith("## Decisions"):
            current = "decisions"
        elif line.startswith("## Action Items"):
            current = "actions"
        elif line.startswith("## Risks"):
            current = "risks"
        elif line.startswith("## Full Transcript"):
            current = None
        elif current and line.strip().startswith("- "):
            sections[current].append(line.strip()[2:])
    return jsonify(sections)

@app.route("/api/recording/<recording_id>", methods=["DELETE"])
def api_delete(recording_id):
    settings = _get_settings()
    out_dir = os.path.expanduser(settings.get("outputDir", DEFAULT_OUTPUT_DIR))
    deleted = []
    for suffix in ["", "_combined", "_mic", "_system"]:
        for ext in [".wav", "_transcript.txt", "_insights.md"]:
            if suffix == "" and "_transcript" in ext:
                # For single recordings, transcript uses base name
                pass
            elif suffix != "" and ext == ".wav":
                pass
            elif suffix == "" and ext == "_insights.md":
                pass
            else:
                continue
            path = os.path.join(out_dir, f"{recording_id}{suffix}{ext}")
            if os.path.exists(path):
                os.remove(path)
                deleted.append(path)
    # Also try pattern-based delete
    for pattern in [f"{recording_id}*.wav", f"{recording_id}*_transcript.txt", f"{recording_id}*_insights.md"]:
        for f in glob.glob(os.path.join(out_dir, pattern)):
            if os.path.exists(f):
                os.remove(f)
                if f not in deleted:
                    deleted.append(f)
    return jsonify({"deleted": len(deleted)})

@app.route("/api/devices")
def api_devices():
    try:
        import sounddevice as sd
        devices = sd.query_devices()
        inputs = []
        outputs = []
        for i, dev in enumerate(devices):
            d = {"index": i, "name": dev["name"], "channels": dev["max_input_channels"]}
            if dev["max_input_channels"] > 0:
                inputs.append(d)
            if dev["max_output_channels"] > 0:
                outputs.append({"index": i, "name": dev["name"], "channels": dev["max_output_channels"]})
        return jsonify({"inputs": inputs, "outputs": outputs, "defaultInput": sd.default.device[0], "defaultOutput": sd.default.device[1]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/settings", methods=["GET"])
def api_get_settings():
    return jsonify(_get_settings())

@app.route("/api/settings", methods=["POST"])
def api_post_settings():
    data = request.get_json(silent=True) or {}
    settings = _get_settings()
    settings.update(data)
    _save_settings(settings)
    return jsonify(settings)

# Serve audio files
@app.route("/api/audio/<recording_id>")
def api_audio(recording_id):
    settings = _get_settings()
    out_dir = os.path.expanduser(settings.get("outputDir", DEFAULT_OUTPUT_DIR))
    track = request.args.get("track", "combined")
    if track == "combined":
        filename = f"{recording_id}_combined.wav"
    elif track == "mic":
        filename = f"{recording_id}_mic.wav"
    elif track == "system":
        filename = f"{recording_id}_system.wav"
    else:
        filename = f"{recording_id}.wav"
    path = os.path.join(out_dir, filename)
    if not os.path.exists(path):
        return jsonify({"error": "File not found"}), 404
    return send_from_directory(out_dir, filename)

# ── SPA catch-all ────────────────────────────────────────────────────────────

@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def catch_all(path):
    return send_from_directory("static", "index.html")

# ── Main ─────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    port = int(os.environ.get("MEETRECORDER_PORT", 8742))
    print(f"MeetRecorder backend starting on http://localhost:{port}")
    app.run(host="127.0.0.1", port=port, debug=False, threaded=True)
