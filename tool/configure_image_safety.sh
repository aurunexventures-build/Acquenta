#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
printf 'Acquenta photo safety — store the existing Google Vision key securely.\n'
read -r -s -p 'Paste Google Vision API key (hidden): ' ACQUENTA_VISION_KEY
printf '\n'
if [ -z "$ACQUENTA_VISION_KEY" ]; then printf 'No key entered. Nothing changed.\n'; exit 1; fi
export ACQUENTA_VISION_KEY
node tool/configure_image_safety.cjs
unset ACQUENTA_VISION_KEY
