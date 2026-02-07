#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

if grep -R --line-number $'\t' DeployBarApp Packages DeployBarTests DeployBarUITests >/tmp/deploybar-tabs.txt 2>/dev/null; then
  echo "Tabs detected in source files:"
  cat /tmp/deploybar-tabs.txt
  fail=1
fi

if grep -R --line-number 'FIXME\|TODO' DeployBarApp Packages >/tmp/deploybar-todo.txt 2>/dev/null; then
  echo "FIXME/TODO markers detected in source files:"
  cat /tmp/deploybar-todo.txt
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "Lint checks passed"
