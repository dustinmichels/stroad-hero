#!/usr/bin/env python3
"""Run the lean Godot test suite in isolated headless processes."""

import os
import selectors
import signal
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
GODOT_BIN = os.environ.get("GODOT_BIN") or shutil.which("godot") or DEFAULT_GODOT

TEST_SCENE = "res://tests/main_tests.tscn"

INNER_TESTS = [
    "--test-find-blocker",
    "--test-priority-arbitration",
    "--test-exit-priority",
    "--test-frontage-contracts",
    "--test-speed-variation",
    "--test-shortcut-contracts",
]

EXTENDED_TESTS = [
    "--test-deadlock-watchdog",
    "--test-merge-gap",
    "--test-right-turn-following",
    "--test-mats-blocker",
    "--test-objectives",
    "--test-car-headlights",
    "--test-day-weather",
    "--test-police-siren",
    "--test-reverse-safety",
    "--test-drive-thru",
    "--test-lifecycle",
    "--test-cramped-inn",
    "--test-cramped-inn-dropoff",
    "--test-strip-mall",
    "--test-smell-store",
    "--test-smell-gas",
    "--test-frontage",
    "--test-objective-manager",
    "--test-mats-cart",
    "--test-mats-collision",
    "--test-mats-sprint",
    "--test-start-screen",
    "--test-startup",
    "--test-verify-render",
    "--test-world-bounds",
    "--test-character-editor",
    "--test-retro-filter",
    "--test-grass-shortcut",
    "--test-sidewalk-shortcut",
    "--test-traffic-stop",
    "--test-bus-stop",
]
BENCHMARKS = [
    "--bench-physics",
    "--bench-physics-walk",
    "--bench-gameplay",
    "--bench-gameplay-compat",
    "--bench-tour",
]
# Benchmarks that open a window for realtime graphical capture
WINDOWED_TESTS = {
    "--bench-gameplay",
    "--bench-gameplay-compat",
    "--bench-tour",
}
# --bench-tour: 6 s boot + warmup + day/night (3 s settle + 11 waypoints x 4 s) + dusk (3 s + 10 s sweep)
TOUR_DEFAULT_WARMUP = 120
TOUR_BASE_TIMEOUT = 240
DEFAULT_TIMEOUT = 120
FAILURE_MARKERS = (b"SCRIPT ERROR:", b"Assertion failed", b"CrashHandlerException")



def stop_process(proc: subprocess.Popen) -> None:
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except ProcessLookupError:
        pass


def run_single_test(
    test_flag: str,
    timeout: int = DEFAULT_TIMEOUT,
    runtime_args: list[str] | None = None,
    fixed_fps: int | None = None,
    main_pack: str | None = None,
    gpu_profile: bool = False,
):
    cmd = [
        GODOT_BIN,
    ]
    if test_flag not in WINDOWED_TESTS and not test_flag.startswith("--bench-gameplay"):
        cmd.append("--headless")
    if test_flag == "--bench-gameplay-compat":
        cmd.extend(["--rendering-method", "gl_compatibility", "--force-web-shadows"])
    if fixed_fps is not None:
        cmd.extend(["--fixed-fps", str(fixed_fps)])
    if gpu_profile:
        # Metal reports no GPU timestamps; the per-pass profile needs Vulkan (MoltenVK on macOS).
        cmd.extend(["--rendering-driver", "vulkan", "--gpu-profile"])
    # A main pack replaces the project directory: the exported (baked) build runs instead of res://.
    cmd.extend(["--main-pack", main_pack] if main_pack else ["--path", "."])
    cmd.extend([
        TEST_SCENE,
        "--",
        test_flag,
        *(runtime_args or []),
        *(["--gpu-profile"] if gpu_profile else []),
    ])
    started = time.monotonic()
    proc = None
    selector = selectors.DefaultSelector()
    output = bytearray()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        assert proc.stdout is not None
        selector.register(proc.stdout, selectors.EVENT_READ)
        deadline = started + timeout

        while proc.poll() is None:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                stop_process(proc)
                remainder, _ = proc.communicate()
                output.extend(remainder or b"")
                return (test_flag, "TIMEOUT", time.monotonic() - started, output.decode(errors="replace"))

            for key, _mask in selector.select(min(0.1, remaining)):
                chunk = os.read(key.fd, 65536)
                if not chunk:
                    continue
                output.extend(chunk)
                if any(marker in output for marker in FAILURE_MARKERS):
                    stop_process(proc)
                    remainder, _ = proc.communicate()
                    output.extend(remainder or b"")
                    return (test_flag, "FAIL", time.monotonic() - started, output.decode(errors="replace"))

        remainder, _ = proc.communicate()
        output.extend(remainder or b"")
        text = output.decode(errors="replace")
        has_error = proc.returncode != 0 or any(
            marker.decode() in text for marker in FAILURE_MARKERS
        )
        return (
            test_flag,
            "FAIL" if has_error else "PASS",
            time.monotonic() - started,
            text,
        )
    except Exception as exc:
        if proc is not None and proc.poll() is None:
            stop_process(proc)
        return (test_flag, f"ERROR: {exc}", time.monotonic() - started, "")
    finally:
        selector.close()


def split_gpu_profile(output: str) -> tuple[str, list[str]]:
    """Remove engine --gpu-profile blocks from a --bench-tour log and summarize them.

    The engine prints a block of per-pass GPU averages about once a second. Blocks printed
    between BENCH_TOUR_SAMPLE begin/end markers are averaged per phase/waypoint.
    """
    kept: list[str] = []
    samples: dict[str, list[dict[str, float]]] = {}
    current: str | None = None
    block: dict[str, float] | None = None
    for line in output.splitlines():
        if line.startswith("GPU PROFILE (total "):
            block = {"total": float(line.split("total ", 1)[1].split("ms", 1)[0])}
            if current is not None:
                samples[current].append(block)
            continue
        if block is not None and line.startswith("\t-"):
            name, _, ms = line[2:].rpartition(": ")
            block[name] = float(ms.strip().removesuffix("ms"))
            continue
        block = None
        if line.startswith("BENCH_TOUR_SAMPLE: begin "):
            current = line.split("begin ", 1)[1].strip()
            samples.setdefault(current, [])
        elif line.startswith("BENCH_TOUR_SAMPLE: end"):
            current = None
        else:
            kept.append(line)

    summary = ["GPU PROFILE per waypoint (ms, mean of ~1 s engine blocks; top passes):"]
    for key, blocks in samples.items():
        if not blocks:
            summary.append(f"  {key:22s} no GPU PROFILE blocks")
            continue
        # vp_begin_/vp_end_<rid> are per-viewport timestamp markers, not passes.
        names = {name for b in blocks for name in b if not name.startswith("vp_")}
        means = {name: sum(b.get(name, 0.0) for b in blocks) / len(blocks) for name in names}
        total = means.pop("total")
        top = sorted(means.items(), key=lambda kv: kv[1], reverse=True)[:8]
        passes = ", ".join(f"{name} {ms:.2f}" for name, ms in top)
        summary.append(f"  {key:22s} total {total:5.2f} (n={len(blocks)}) | {passes}")
    return "\n".join(kept), summary


def main():
    if not os.path.isfile(GODOT_BIN):
        print(f"Error: Godot binary not found at '{GODOT_BIN}'", file=sys.stderr)
        sys.exit(1)

    args = sys.argv[1:]
    # Strip any leading '--' forwarded by mise
    if args and args[0] == "--":
        args = args[1:]
    runtime_args = [
        arg
        for arg in args
        if arg in ("--bake", "--profile-traffic")
        or arg.startswith(
            ("--duration=", "--physics-ticks=", "--seed=", "--warmup=", "--tour-phases=", "--tour-wps=")
        )
    ]
    args = [arg for arg in args if arg not in runtime_args]
    gpu_profile = "--gpu-profile" in args
    args = [arg for arg in args if arg != "--gpu-profile"]

    fixed_fps: int | None = None
    main_pack: str | None = None
    cleaned_args: list[str] = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--cpu":
            fixed_fps = 60
            i += 1
        elif arg.startswith("--fixed-fps="):
            fixed_fps = int(arg.split("=", 1)[1])
            i += 1
        elif arg.startswith("--main-pack="):
            main_pack = arg.split("=", 1)[1]
            i += 1
        elif arg == "--main-pack" and i + 1 < len(args):
            main_pack = args[i + 1]
            i += 2
        elif arg == "--fixed-fps":
            if i + 1 < len(args) and args[i + 1].isdigit():
                fixed_fps = int(args[i + 1])
                i += 2
            else:
                fixed_fps = 60
                i += 1
        else:
            cleaned_args.append(arg)
            i += 1
    args = cleaned_args
    if main_pack and not os.path.isfile(main_pack):
        print(f"Error: main pack '{main_pack}' not found (run: mise run export-mac-pack)", file=sys.stderr)
        sys.exit(1)
    timeout = int(os.environ.get("TEST_TIMEOUT", DEFAULT_TIMEOUT))
    tour_warmup = next(
        (float(a.split("=", 1)[1]) for a in runtime_args if a.startswith("--warmup=")),
        TOUR_DEFAULT_WARMUP,
    )
    tour_timeout = max(timeout, int(TOUR_BASE_TIMEOUT + tour_warmup))
    all_tests = INNER_TESTS + EXTENDED_TESTS
    all_flags = set(all_tests + BENCHMARKS) | WINDOWED_TESTS

    if "--help" in args or "-h" in args:
        print("Usage: mise run test [OPTIONS | TEST_FLAGS...]")
        print("\nOptions:")
        print("  mise run test                  Run the lean inner suite")
        print("  mise run test --extended       Run inner and extended tests")
        print("  mise run test --list           List tests and benchmarks")
        print("  mise run bench                 Run manual benchmarks (gameplay benchmarks open a window)")
        print("  mise run bench --bench-tour    Run only the named benchmark(s)")
        print("  --bench-tour options: --seed=N --warmup=SEC --tour-phases=day,dusk,night --tour-wps=a,b --bake")
        print("  --gpu-profile                  Vulkan per-pass GPU times per tour waypoint (engine --gpu-profile)")
        print("  --main-pack=/tmp/stroad_mac.pck  Run from the exported baked pack (mise run export-mac-pack)")
        print("  mise run test --fixed-fps 60   Run in fixed-FPS CPU mode (frames run back-to-back)")
        print("  mise run test -- <test-flag>   Run specific test flags")
        sys.exit(0)

    if "--list" in args:
        for heading, flags in (
            ("Inner tests", INNER_TESTS),
            ("Extended tests", EXTENDED_TESTS),
            ("Benchmarks", BENCHMARKS),
        ):
            print(f"{heading}:")
            for flag in flags:
                note = " (opens a window)" if flag in WINDOWED_TESTS else ""
                print(f"  {flag}{note}")
        sys.exit(0)

    if "--extended" in args:
        tests_to_run = all_tests
    elif "--bench" in args:
        tests_to_run = [arg for arg in args if arg in BENCHMARKS] or BENCHMARKS
    elif args:
        unknown = [arg for arg in args if arg not in all_flags]
        if unknown:
            print(f"Unknown test flag(s): {', '.join(unknown)}", file=sys.stderr)
            sys.exit(2)
        tests_to_run = args
    else:
        tests_to_run = INNER_TESTS

    # Filter out empty or duplicate flags
    tests_to_run = [t for t in tests_to_run if t.strip()]

    print(f"Running {len(tests_to_run)} test(s) using Godot at: {GODOT_BIN}\n")

    start_time = time.time()
    failures = 0

    max_workers = (
        1
        if all(flag in BENCHMARKS for flag in tests_to_run)
        else min(6, len(tests_to_run))
    )
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {
            pool.submit(
                run_single_test,
                flag,
                tour_timeout if flag == "--bench-tour" else timeout,
                runtime_args,
                fixed_fps,
                main_pack,
                gpu_profile,
            ): flag
            for flag in tests_to_run
        }
        for future in as_completed(futures):
            test_flag, status, duration, output = future.result()
            if gpu_profile and test_flag == "--bench-tour":
                output, gpu_summary = split_gpu_profile(output)
                output += "\n" + "\n".join(gpu_summary)
            if status == "PASS":
                print(f"[{status:7s}] {test_flag:30s} ({duration:.2f}s)")
                if test_flag in BENCHMARKS or test_flag in WINDOWED_TESTS:
                    lines = [l for l in output.strip().splitlines() if l.strip()]
                    for l in lines:
                        print(f"    {l}")
            else:
                failures += 1
                print(f"[{status:7s}] {test_flag:30s} ({duration:.2f}s)")
                lines = [l for l in output.strip().splitlines() if l.strip()]
                tail = "\n    ".join(lines[-8:]) if lines else "No output"
                print(f"    Output tail:\n    {tail}\n")

    total_time = time.time() - start_time
    passed = len(tests_to_run) - failures
    print(f"\nResults: {passed}/{len(tests_to_run)} passed in {total_time:.2f}s")

    if failures > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
