#!/usr/bin/env python3
"""Headless Godot test runner for stroad-hero.

Runs built-in scenario and unit test flags defined in main.gd.
"""

import os
import re
import shutil
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
GODOT_BIN = os.environ.get("GODOT_BIN") or shutil.which("godot") or DEFAULT_GODOT

FAST_TESTS = [
    "--test-find-blocker",
    "--test-reverse-safety",
    "--test-priority-arbitration",
    "--test-exit-priority",
    "--test-deadlock-watchdog",
    "--test-mats-blocker",
    "--test-mats-walk",
    "--test-objective-manager",
    "--test-objectives",
    "--test-mats-cart",
    "--test-mats-collision",
    "--test-start-screen",
]

SCENARIO_TESTS = [
    "--test-drive-thru",
    "--test-merge-reentry",
    "--test-merge-gap",
    "--test-lifecycle",
    "--test-cramped-inn",
    "--test-strip-mall",
    "--test-smell-store",
    "--test-smell-gas",
    "--test-right-turn-following",
]

DEFAULT_TIMEOUT = 60


def discover_test_flags() -> list[str]:
    """Dynamically scan main.gd for test flags, prioritizing fast tests."""
    found: set[str] = set()
    if os.path.isfile("main.gd"):
        with open("main.gd", "r", encoding="utf-8") as f:
            for match in re.findall(r'"(--test-[a-z0-9-]+)"', f.read()):
                if match != "--test-mats-interaction":  # alias for --test-mats-blocker
                    found.add(match)

    ordered = [t for t in FAST_TESTS if t in found]
    ordered += [t for t in SCENARIO_TESTS if t in found]
    ordered += [t for t in sorted(found) if t not in ordered]
    return ordered if ordered else (FAST_TESTS + SCENARIO_TESTS)


def run_single_test(test_flag: str, timeout: int = DEFAULT_TIMEOUT):
    cmd = [GODOT_BIN, "--headless", "--path", ".", "--", test_flag]
    t0 = time.time()
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
        )
        try:
            output, _ = proc.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            except ProcessLookupError:
                pass
            output, _ = proc.communicate()
            return (test_flag, "TIMEOUT", time.time() - t0, output or "")

        duration = time.time() - t0
        has_error = (
            proc.returncode != 0
            or "SCRIPT ERROR:" in output
            or "Assertion failed" in output
            or "CrashHandlerException" in output
        )
        status = "PASS" if not has_error else "FAIL"
        return (test_flag, status, duration, output)
    except Exception as e:
        duration = time.time() - t0
        return (test_flag, f"ERROR: {e}", duration, "")


def main():
    if not os.path.isfile(GODOT_BIN):
        print(f"Error: Godot binary not found at '{GODOT_BIN}'", file=sys.stderr)
        sys.exit(1)

    args = sys.argv[1:]
    # Strip any leading '--' forwarded by mise
    if args and args[0] == "--":
        args = args[1:]

    timeout = int(os.environ.get("TEST_TIMEOUT", DEFAULT_TIMEOUT))
    all_tests = discover_test_flags()

    if "--help" in args or "-h" in args:
        print("Usage: mise run test [FLAGS...]")
        print("\nOptions:")
        print("  mise run test                  Run all tests in parallel (~45s)")
        print("  mise run test --fast           Run fast unit tests only (< 3s)")
        print("  mise run test --list           List all available test flags")
        print(
            "  mise run test -- <test-flag>   Run a specific test flag (e.g. --test-find-blocker)"
        )
        sys.exit(0)

    if "--list" in args:
        print("Fast tests:")
        for t in FAST_TESTS:
            if t in all_tests:
                print(f"  {t}")
        print("\nScenario tests:")
        for t in all_tests:
            if t not in FAST_TESTS:
                print(f"  {t}")
        sys.exit(0)

    if "--fast" in args:
        tests_to_run = [t for t in FAST_TESTS if t in all_tests]
        args.remove("--fast")
    elif args:
        tests_to_run = args
    else:
        tests_to_run = all_tests

    # Filter out empty or duplicate flags
    tests_to_run = [t for t in tests_to_run if t.strip()]

    print(f"Running {len(tests_to_run)} test(s) using Godot at: {GODOT_BIN}\n")

    start_time = time.time()
    results = []
    failures = 0

    max_workers = min(6, len(tests_to_run))
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(run_single_test, t, timeout): t for t in tests_to_run}
        for future in as_completed(futures):
            test_flag, status, duration, output = future.result()
            results.append((test_flag, status, duration, output))
            if status == "PASS":
                print(f"[{status:7s}] {test_flag:30s} ({duration:.2f}s)")
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
