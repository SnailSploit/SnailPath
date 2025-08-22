# Snailpath 🐌⚡

**Smart, low–false-positive directory & route discovery** for modern web apps.
Async scanner with HTTP/2 (and optional HTTP/3), soft-404 suppression, a JS/sourcemap route miner, adaptive concurrency, API-aware branching, and polished outputs (HTML, JSONL, evidence, Burp/ZAP replay pack).


## Table of Contents

* [Why Snailpath?](#why-snailpath)
* [Features](#features)
* [Install](#install)
* [Quick Start](#quick-start)
* [CLI Reference](#cli-reference)
* [Outputs](#outputs)
* [How It Works (Brief)](#how-it-works-brief)
* [Tips & Patterns](#tips--patterns)
* [Tiny Test Server](#tiny-test-server)
* [Docker](#docker)
* [CI](#ci)
* [Contributing](#contributing)
* [Security & Ethics](#security--ethics)
* [Roadmap](#roadmap)
* [License](#license)

## Why Snailpath?

Other busters are great at fast brute-forcing. Snailpath goes after **coverage** and **signal quality** on modern stacks:

* **SPA/JS-heavy sites:** pull routes from HTML/JS and sourcemaps where wordlists miss.
* **Zero-FP focus:** combine auto-calibration with SimHash similarity to suppress wildcard 200s and soft-404s.
* **Operator UX:** readable HTML report, evidence files for proof, and a drop-in replay pack for Burp/ZAP.
* **Budgets & resiliency:** resumable scans, queue checkpoints, adaptive concurrency, and graceful fallbacks.

## Features

* **Async engine** (HTTP/2) with connection pooling and retries.
* **HTTP/3 (QUIC) path** via `aioquic` for same-origin `GET/HEAD` (flag: `--h3`) with automatic fallback.
* **Zero-FP mode** (`--zero-fp`): auto-calibrate on random miss paths + SimHash similarity filtering.
* **JS route miner** (`--routes js,links`): extract path candidates from HTML, JS bundles, and `//# sourceMappingURL=` sourcemaps.
* **Param/verb auto-branching**: when a hit looks like an API, try common query params and light method tricks.
* **Adaptive concurrency**: ramps up until p95 latency or error rate crosses thresholds, then backs off.
* **Recursion (depth-1)** and scope guards; link mining for HTML pages.
* **Outputs**: JSONL (machine), **HTML report** (human), **evidence** (headers + body snippet), **replay pack** (.http).
* **Budgets & resumability**: stop by time/request budgets; resume from previous JSONL; checkpoint remaining queue.
* **Pipx-ready packaging**, **Dockerfile**, **GitHub Actions CI**, **tests**, and a **tiny test server**.

## Install

### From Source (Local Dev)

```bash
pip install .
# optional HTTP/3 support:
pip install 'aioquic>=0.9.25'
```

### pipx (Once Published)

```bash
pipx install snailpath
# optional HTTP/3:
pipx inject snailpath 'aioquic>=0.9.25'
```

### Requirements

* Python 3.9+ (tested on 3.9–3.12)

## Quick Start

```bash
snailpath https://example.com wordlists/small.txt \
  -c 80 -r --zero-fp --routes js,links --h3 \
  --include 200,204,301-308 -x php -x bak \
  -o out/target.jsonl --report out/target.html \
  --evidence out/evidence --replay-pack out/replay.http
```

### Resume & Checkpoint

```bash
# skip paths already found
snailpath https://example.com wl.txt --resume-from out/target.jsonl -o out/target.jsonl

# store remaining queue when budgets stop the scan
snailpath https://example.com wl.txt --budget-requests 10000 --checkpoint-out out/remaining.txt
```

## CLI Reference

**Positional**

* `base_url` – e.g. `https://target.tld`
* `wordlist` – path to a wordlist file

**Common Flags**

* `-c, --concurrency <int>` – max concurrent requests (default 60)
* `-t, --timeout <sec>` – per-request timeout (default 10)
* `-r, --recurse` – enable shallow recursion (depth-1)
* `-x, --ext <ext>` – try extension (repeatable): `-x php -x bak`
* `--include "<codes/ranges>"` – e.g. `200,204,301-303`
* `--exclude "<codes/ranges>"`
* `-o, --jsonl <path>` – write JSONL findings
* `--report <path>` – write HTML report
* `--evidence <dir>` – save headers and 2KB body snippet per hit
* `--replay-pack <path>` – write raw HTTP requests (.http) for Burp/ZAP
* `--checkpoint-out <path>` – save remaining queue if scan stops early
* `--resume-from <jsonl>` – skip paths present in a prior JSONL
* `--proxy <url>` – e.g. `http://127.0.0.1:8080`
* `--header "Name: Value"` – custom header (repeatable)
* `--method <HEAD|GET>` – primary probe method (default HEAD)
* `--zero-fp` – soft-404 suppression (auto-cal + similarity)
* `--routes <list>` – route miners: `js,links`
* `--budget-requests <N>` – stop after N requests
* `--budget-seconds <S>` – stop after S seconds
* `--h3` – prefer HTTP/3 (best-effort via `aioquic`)
* `--no-adaptive` – disable adaptive concurrency

## Outputs

### JSONL (Machine-Readable)

Each line is a JSON object. Example:

```json
{
  "url": "https://example.com/admin",
  "path": "/admin",
  "code": 200,
  "length": 1234,
  "title": "Admin Portal",
  "headers": { "content-type": "text/html; charset=utf-8" },
  "reason": "interesting-status,has-title,nontrivial-size",
  "body_snippet": "<!doctype html>..."
}
```

### HTML Report (Human)

A self-contained HTML file with summary and colorized findings.

### Evidence Directory

For each hit, saves:

* `<status>_<path>.headers.txt`
* `<status>_<path>.body.txt` (first 2KB)

### Replay Pack (.http)

Raw HTTP/1.1 request blocks suitable for "Paste raw" in Burp/ZAP or manual replay.

## How It Works (Brief)

* **Engine:** `httpx.AsyncClient` with HTTP/2 by default; optional HTTP/3 path (`aioquic`) for same-origin `GET/HEAD`.
* **Zero-FP mode:** randomly probes improbable paths to build a baseline (status/length) and computes 64-bit SimHash over tokenized text. A result is filtered if it's sufficiently similar to the baseline soft-404s.
* **JS route miner:** fetches HTML, finds `<script src>`, pulls paths from JS text, and, when present, follows `//# sourceMappingURL=` to parse sourcemaps and mine additional routes.
* **Adaptive concurrency:** tracks p95 latency and error rate; increases concurrency when healthy, decreases under pressure.
* **API heuristics:** when a response looks like JSON or an `/api/` path, tries a small set of params (`debug`, `q`, `page`, …) and light conditional/range probing.
* **Recursion:** conservative depth-1 with link mining; scope guards avoid runaway expansion.

## Tips & Patterns

* **Stealthy recon:** use `--method HEAD` with `--include 200,204,301-308` and enable `--zero-fp`.
* **Heavy recon on SPAs:** add `--routes js,links`, consider `--h3` where CDNs support QUIC.
* **Triage fast:** generate `--report` and `--replay-pack`, then validate in Burp/ZAP.
* **CI-safe budgets:** run with `--budget-requests` or `--budget-seconds` and `--checkpoint-out`.

## Tiny Test Server

A minimal server to exercise success paths and soft-404 detection.

```bash
python tools/testserver.py
# serves:
#  /exists1..20  -> 200 OK unique bodies
#  /soft404/*    -> 200 OK soft-404 template
#  everything else -> 404
```

Example run against it:

```bash
snailpath http://127.0.0.1:8000 wordlists/small.txt \
  --zero-fp -o out.jsonl --report out.html
```

## Docker

```bash
docker build -t snailpath:latest .
docker run --rm -it snailpath:latest https://target.tld wordlists/small.txt -o out.jsonl
```

## CI

GitHub Actions workflow (`.github/workflows/ci.yml`) runs lint/basic tests on Python 3.9–3.12.
Add tests in `tests/` (see example) and keep features behind flags.

## Contributing

* Keep experimental features behind flags (e.g., `--h3`, `--zero-fp`).
* Add/extend tests (we ship a tiny server for local checks).
* Maintain output schema stability; document changes in `CHANGELOG.md`.
* Open PRs/issues—clear repro steps and expected behavior help a lot.

## Security & Ethics

Use Snailpath **only** on targets you own or have permission to test.
Report vulnerabilities privately first. See `SECURITY.md` for contact details.

## Roadmap

* Priority queue with **novelty scoring** (SimHash diversity) to reorder crawl branches.
* Expanded API heuristics and verb probing.
* More output formats (CSV, JUnit) and richer HTML triage.
* Deeper recursion modes with strict scope controls.

## License

MIT — see `LICENSE`.

---

### Getting Started

* Wordlists: `wordlists/small.txt`
* Example commands: see [Quick Start](#quick-start)
* Need help? Open an issue with your command, logs, and environment details.
