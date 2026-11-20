"""Executa as suítes do MutaLabs e preserva os resultados de cada processo."""
import argparse
import os
import platform
import re
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path

BASE = Path(__file__).resolve().parent
SUITES = dict(campaign_rc2=104, bosses_rc3=78, regression_rc2=37,
              miniboss_rc2=21, traversal_rc2=21, dodge_rc3=7)
parser = argparse.ArgumentParser()
parser.add_argument("--godot", default="godot")
parser.add_argument("--projeto", type=Path, required=True)
parser.add_argument("--suite", choices=SUITES)
args = parser.parse_args()
root = args.projeto.resolve()
selected = [args.suite] if args.suite else list(SUITES)
if not (root / "project.godot").is_file():
    parser.error("Indique a pasta extraída que contém project.godot.")
for suite in selected:
    rel = Path("tests") / (suite + ".gd")
    if not (root / rel).is_file() or (root / rel).read_bytes() != (BASE / rel).read_bytes():
        parser.error(f"Arquivo ausente ou diferente da suíte RC3: {rel}")
out = BASE / "execucoes" / datetime.now().strftime("%Y%m%d-%H%M%S-%f")
out.mkdir(parents=True)
print(f"Relatórios: {out}", flush=True)
with tempfile.TemporaryDirectory() as profile:
    env = dict(os.environ, APPDATA=profile, XDG_DATA_HOME=profile)
    def run(options, name):
        result = subprocess.run([args.godot, *options], env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=240)
        (out / (name + ".txt")).write_bytes(result.stdout)
        return result.returncode, result.stdout.decode("utf-8", errors="replace")
    try:
        rc, version = run(["--version"], "versao")
        if rc:
            sys.exit("Falha ao consultar a versão do Godot.")
        (out / "ambiente.txt").write_text(f"{datetime.now().astimezone().isoformat()}\n{platform.platform()}\n{version}", encoding="utf-8")
        common = ["--headless", "--path", str(root)]
        rc, _ = run(common + ["--import"], "importacao")
        if rc:
            sys.exit("Falha na importação. Consulte importacao.txt.")
        failed = False
        total = 0
        with (out / "resumo.txt").open("w", encoding="utf-8") as report:
            for suite in selected:
                rc, log = run(common + ["--fixed-fps", "60", "--script", f"res://tests/{suite}.gd"], suite)
                passes = len(re.findall(r"^PASS\b", log, re.M))
                ok = rc == 0 and passes == SUITES[suite] and not re.search(r"^(FAIL\b|SCRIPT ERROR|ERROR:)", log, re.M)
                failed |= not ok
                total += passes
                line = f"{suite}: {passes}/{SUITES[suite]} PASS | saída {rc} | {'OK' if ok else 'REVISAR'}"
                print(line, flush=True)
                print(line, file=report, flush=True)
            print(f"Total de PASS: {total}", file=report)
        sys.exit(int(failed))
    except (OSError, subprocess.TimeoutExpired) as exc:
        sys.exit(f"Execução interrompida: {exc}")
