#!/usr/bin/env python3
"""
Transcribe audio with Whisper, then extract key takeaways and insights.
Usage:
  python3 mac-transcribe.py <audio_file> [--model base|small|medium|large]
"""
import sys
import os
import argparse
import whisper


def transcribe(audio_path, model_name="base"):
    if not os.path.exists(audio_path):
        print(f"File not found: {audio_path}")
        sys.exit(1)

    print(f"Loading Whisper model '{model_name}'...")
    model = whisper.load_model(model_name)

    print(f"Loading audio: {audio_path}")
    # Load audio with soundfile to avoid requiring ffmpeg
    import soundfile as sf
    audio_array, sr = sf.read(audio_path, dtype="float32")
    # Convert to mono if stereo
    if audio_array.ndim > 1:
        audio_array = audio_array.mean(axis=1)
    # Resample to 16 kHz if needed using simple linear interpolation
    if sr != 16000:
        import numpy as np
        old_len = len(audio_array)
        new_len = int(old_len * 16000 / sr)
        audio_array = np.interp(
            np.linspace(0, old_len - 1, new_len),
            np.arange(old_len),
            audio_array,
        )
        # Ensure float32 for Whisper
        audio_array = audio_array.astype(np.float32)

    print(f"Transcribing...")
    result = model.transcribe(audio_array, verbose=False)

    # Save transcript alongside audio
    base, _ = os.path.splitext(audio_path)
    transcript_path = base + "_transcript.txt"
    with open(transcript_path, "w") as f:
        f.write(result["text"])
    print(f"Transcript saved to: {transcript_path}")

    return result["text"], transcript_path


def extract_insights(text):
    """
    Use a lightweight heuristic + prompt-ready formatting for LLM insight extraction.
    Returns structured markdown.
    """
    lines = [l.strip() for l in text.split(".") if len(l.strip()) > 10]

    # Simple keyword-based extraction as a first pass
    decisions = []
    actions = []
    concerns = []
    for line in lines:
        lower = line.lower()
        if any(w in lower for w in ["decide", "decision", "agreed", "approve", "go with", "choose", "select"]):
            decisions.append(line)
        if any(w in lower for w in ["action", "todo", "task", "follow up", "follow-up", "need to", "will do", "should"]):
            actions.append(line)
        if any(w in lower for w in ["risk", "issue", "problem", "concern", "blocker", "challenge", " worried"]):
            concerns.append(line)

    md = "# Meeting Takeaways & Insights\n\n"
    md += "## Decisions Made\n"
    if decisions:
        for d in decisions[:10]:
            md += f"- {d}\n"
    else:
        md += "_No explicit decisions detected._\n"

    md += "\n## Action Items\n"
    if actions:
        for a in actions[:10]:
            md += f"- {a}\n"
    else:
        md += "_No explicit action items detected._\n"

    md += "\n## Risks / Concerns\n"
    if concerns:
        for c in concerns[:10]:
            md += f"- {c}\n"
    else:
        md += "_No explicit concerns detected._\n"

    md += "\n---\n\n## Full Transcript\n\n"
    md += text
    return md


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio and extract insights")
    parser.add_argument("audio", help="Path to audio file")
    parser.add_argument("--model", default="base", choices=["tiny", "base", "small", "medium", "large"])
    parser.add_argument("--insights-only", action="store_true", help="Skip saving full transcript, only output insights")
    args = parser.parse_args()

    text, transcript_path = transcribe(args.audio, model_name=args.model)

    insights_md = extract_insights(text)
    base, _ = os.path.splitext(args.audio)
    insights_path = base + "_insights.md"
    with open(insights_path, "w") as f:
        f.write(insights_md)
    print(f"Insights saved to: {insights_path}")

    if not args.insights_only:
        print("\n" + "=" * 60)
        print(insights_md)
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        # Only print the structured part before ---
        print(insights_md.split("---")[0])
        print("=" * 60)


if __name__ == "__main__":
    main()
