import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "docs/lab11/logs"
OUT.mkdir(parents=True, exist_ok=True)
DB = ROOT / "backend/data/mealmate.db"
def digest():
    return hashlib.sha256(DB.read_bytes()).hexdigest() if DB.exists() else None

def main():
    before = digest()
    temporary = Path(tempfile.mkdtemp(prefix="mealmate-lab11-"))
    python = ROOT / "backend/.venv/Scripts/python.exe"
    if not python.exists():
        python = Path(sys.executable)
    results = {"database_sha256_before": before, "runs": []}
    env = dict(os.environ, PYTHONIOENCODING="utf-8", PYTHONUTF8="1")
    jobs = []
    for name, target in [("unit", "tests/lab11/test_unit.py"), ("integration", "tests/lab11/test_integration.py"), ("functional", "tests/lab11/test_functional.py"), ("backend_all", "tests")]:
        jobs.append((name, [str(python), "-m", "pytest", target, "-v", "-o", "junit_family=xunit1", "--junitxml=" + str(OUT / (name + ".xml")), "--basetemp=" + str(temporary / name)], ROOT / "backend"))
    flutter = shutil.which("flutter")
    if not flutter:
        raise RuntimeError("flutter not found on PATH")
    for name, args in [("flutter_analyze", ["analyze"]), ("flutter_test", ["test", "--reporter", "json"])]:
        jobs.append((name, ["cmd.exe", "/d", "/c", flutter, *args], ROOT))
    for name, command, cwd in jobs:
        print("RUN " + name, flush=True)
        start = time.monotonic()
        stamp = dt.datetime.now(dt.timezone.utc).isoformat()
        completed = subprocess.run(command, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
        suffix = ".jsonl" if name == "flutter_test" else ".txt"
        (OUT / (name + suffix)).write_text(completed.stdout, encoding="utf-8")
        entry = {"name": name, "command": subprocess.list2cmdline(command), "cwd": str(cwd), "started_utc": stamp, "seconds": round(time.monotonic()-start, 2), "exit_code": completed.returncode, "log": name + suffix}
        results["runs"].append(entry)
        print(f"DONE {name}: exit={completed.returncode}; {entry['seconds']}s", flush=True)
        if name != "flutter_test":
            print(completed.stdout[-1800:], flush=True)
        results["database_sha256_after"] = digest()
        (OUT / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
    if before != digest():
        print("WARNING: production database file hash changed", flush=True)
    return int(any(run["exit_code"] for run in results["runs"]))

if __name__ == "__main__":
    raise SystemExit(main())
