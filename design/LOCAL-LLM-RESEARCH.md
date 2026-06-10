# Local LLM Research for MeetRecorder

## Objective

Replace cloud APIs (OpenAI Whisper + Anthropic Claude) with locally-hosted
models that are **light**, **accurate**, and **native to macOS / Apple
Silicon**.

---

## 1. Transcription (Replace OpenAI Whisper API)

### Recommended: WhisperKit

**Repo:** `argmaxinc/WhisperKit`  
**Language:** Swift (native)  
**Backend:** Core ML / Apple Neural Engine (ANE)  
**Model sizes:** tiny (~39 MB), base (~74 MB), small (~244 MB), medium (~744 MB), large-v3 (~1.5 GB)

| Criterion | Assessment |
|-----------|------------|
| **Weight** | Small model (244 MB) is sufficient for clear meeting audio. Medium (744 MB) for noisy rooms or heavy accents. |
| **Accuracy** | On-par with OpenAI Whisper API at the same model size. Argmax publishes WER benchmarks on the repo. |
| **Speed** | Real-time on M-series chips using ANE. Small model transcribes 1 hr of audio in ~3 min on M3. |
| **Languages** | English, Cantonese (`zh`), Mandarin (`zh`) all supported via the same multilingual checkpoint. |
| **Integration** | Swift Package Manager. No Python runtime, no Docker, no external daemon. |
| **Privacy** | 100 % on-device. Audio never leaves the Mac. |

**Sample integration:**

```swift
import WhisperKit

let pipe = try await WhisperKit(model: "small", computeOptions: .init(
    audioEncoderComputeUnits: .cpuAndNeuralEngine,
    textDecoderComputeUnits: .cpuAndNeuralEngine
))
let result = try await pipe.transcribe(audioPath: "recording.wav")
```

**Recommendation:** Start with `small` for general use. Offer `medium` as an
optional download in Settings for users who need higher accuracy. `tiny` is
only for emergency low-battery mode.

### Alternative: whisper.cpp

**Repo:** `ggerganov/whisper.cpp`  
**Pros:** Very mature, huge community, supports Core ML conversion.  
**Cons:** C++ based; Swift integration requires bridging headers or wrapping
the CLI. Less ergonomic than WhisperKit for pure-Swift apps.

**Verdict:** Use whisper.cpp only if you need exotic features (e.g., custom
ggml quantizations, streaming diarization) that WhisperKit does not yet
expose.

---

## 2. Summarization / Structured Extraction (Replace Anthropic Claude API)

### Recommended Stack: MLX Swift + mlx-swift-examples LLM

**Repos:**
- `ml-explore/mlx-swift` — core tensor / GPU compute framework by Apple
- `ml-explore/mlx-swift-examples` — reference LLM inference app + `LLM` module

| Criterion | Assessment |
|-----------|------------|
| **Weight** | 7B models quantised to 4-bit run in ~4–5 GB of unified memory. Comfortable on 16 GB Macs; tight on 8 GB. |
| **Accuracy** | Comparable to Claude 3 Haiku for structured extraction tasks at 7B scale. |
| **Speed** | ~20–40 tokens/sec on M3 Pro (7B 4-bit). A 30-minute meeting transcript (~6K tokens) processes in under 2 minutes. |
| **Languages** | Depends on model choice (see below). |
| **Integration** | Swift Package Manager. Models download from HuggingFace at first launch. |
| **Context** | 32K+ tokens typical for modern 7B instruct models. Enough for 45–60 min meetings. |

### Top Model Recommendations

#### A. Qwen2.5-7B-Instruct (MLX) — **Best Overall for MeetRecorder**

- **Why:** Alibaba's Qwen family is the current leader in Chinese + English
  bilingual performance. Cantonese is handled well via the `zh` code or
  explicitly in the prompt.
- **Context:** 32K tokens.
- **Size:** ~4.2 GB at 4-bit (Q4_K_M).
- **Strength:** Excellent instruction following. Produces clean Markdown,
  YAML frontmatter, and bullet lists with high reliability.
- **Download:** `mlx-community/Qwen2.5-7B-Instruct-4bit`

#### B. Llama-3.1-8B-Instruct (MLX) — **Best Generalist**

- **Why:** Meta's strongest small model. 128K context window.
- **Size:** ~4.5 GB at 4-bit.
- **Strength:** Superior long-context handling if you record 90+ minute
  meetings. Slightly weaker in Chinese-to-English translation than Qwen.
- **Download:** `mlx-community/Meta-Llama-3.1-8B-Instruct-4bit`

#### C. DeepSeek-R1-Distill-Qwen-7B (MLX) — **Best for Extraction Quality**

- **Why:** Distilled reasoning model. "Thinks" before outputting structured
  data, which reduces hallucinated action items.
- **Size:** ~4.5 GB.
- **Trade-off:** ~2× slower because it emits reasoning tokens before the
  final answer. Good for accuracy-at-all-costs users.
- **Download:** `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit`

#### D. Phi-4 (14B) — **If the User Has 32 GB+ RAM**

- **Why:** Microsoft's Phi-4 punches above its weight. Near-Claude-Sonnet
  quality on structured tasks.
- **Size:** ~9 GB at 4-bit.
- **Verdict:** Not "light" by the user's definition. Mention only as a
  future premium tier.

### Prompt Engineering for Local Models

Claude is forgiving; 7B local models need discipline. Use this template:

```markdown
You are a meeting assistant. Given the transcript below, produce structured
output in this exact format:

---
date: ISO-8601
duration: MM:SS
title: inferred from content
tags: ["meeting"]
---

## Executive Summary
3 sentences max.

## Key Takeaways & Action Items
- [Owner] Action item text

## Detailed Notes
Bullet points.

## Translated Transcript
Full transcript in {{target_language}}.

Rules:
- Do not add sections not listed above.
- If no action items exist, write "None identified."
- Use the same language as the transcript for Detailed Notes.

Transcript:
{{transcript}}
```

Local models benefit from **low temperature (0.1–0.3)** and a **repetition
penalty (1.05–1.1)** to keep YAML clean.

---

## 3. Integration Architecture

```
┌─────────────────────────────────────────────┐
│              MeetRecorder (SwiftUI)          │
├─────────────────────────────────────────────┤
│  Audio Engine (ScreenCaptureKit + AVAudio)  │
│         ↓                                   │
│  WhisperKit.transcribe(audioPath)           │
│         ↓                                   │
│  Local LLM via MLX.swift (generate)         │
│         ↓                                   │
│  MarkdownExporter.write(vaultPath)          │
└─────────────────────────────────────────────┘
```

### Dependency Additions to `project.yml`

```yaml
dependencies:
  - package: WhisperKit
  - package: MLXLLM
  - package: KeyboardShortcuts
  - package: LaunchAtLogin
packages:
  WhisperKit:
    url: https://github.com/argmaxinc/WhisperKit
    from: 0.10.0
  MLXLLM:
    url: https://github.com/ml-explore/mlx-swift-examples
    from: 2.0.0
```

> **Note:** `mlx-swift-examples` is a monorepo. Import only the `LLM` target
> via SPM to avoid pulling in unnecessary training code.

### First-Run Model Download UX

Local models are too large to bundle. Add a "Models" pane in Settings:

| Model | Status | Size |
|-------|--------|------|
| Whisper Small | Downloaded | 244 MB |
| Whisper Medium | Download | 744 MB |
| Qwen 2.5 7B | Downloaded | 4.2 GB |

Use `URLSession` with `.allowsExpensiveNetworkAccess(false)` so models
download only on Wi-Fi. Store in `Application Support/MeetRecorder/Models`.

---

## 4. Fallback Strategy

If a user is on an Intel Mac or an 8 GB M1, local inference may be too slow.
Preserve the existing cloud-API path as a fallback:

```swift
enum InferenceBackend {
    case local(model: LocalModel)
    case cloud(openAI: String, anthropic: String)
}
```

Default to `.local` on Apple Silicon with 16 GB+. Default to `.cloud` on
Intel or 8 GB machines, with a Settings toggle to override.

---

## 5. Summary Table

| Task | Cloud (Current) | Local Replacement | Model / Framework | RAM | Quality |
|------|-----------------|-------------------|-------------------|-----|---------|
| Transcription | OpenAI Whisper API | WhisperKit | `small` or `medium` | 0.2–0.7 GB | Equal |
| Summarization | Claude 3.5 Sonnet | MLX Swift | Qwen2.5-7B-4bit | ~4.5 GB | Near-Haiku |
| Fallback | — | Ollama (external) | Any GGUF | Varies | Varies |

**Bottom line:** The WhisperKit + Qwen2.5-7B-MLX stack gives you fully
private, on-device meeting intelligence on any M-series Mac with 16 GB RAM.
The quality gap versus cloud APIs is small enough that most users will prefer
the privacy and zero-latency trade-off.
