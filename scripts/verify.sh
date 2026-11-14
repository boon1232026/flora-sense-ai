#!/usr/bin/env bash
set -euo pipefail

make -C backend test
(cd ai-engine && python3 -m unittest discover -s tests -v)
(cd mobile-app && flutter analyze && flutter test)
./scripts/smoke_simulator.sh

echo "Scaffold verification complete. ESP-IDF and Docker checks require their toolchains."
