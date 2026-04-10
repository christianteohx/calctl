#!/usr/bin/env bash
set -euo pipefail

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

echo "Configured local git hooks to use .githooks/"
echo "Now pre-commit will run gitleaks on each commit."
