#!/usr/bin/env bash
# Lints and format-checks the framework layer with gdtoolkit (gdlint and
# gdformat, settings in .gdlintrc). Part of tools/ci.sh; run it alone with
#   tools/lint.sh          # check
#   tools/lint.sh --fix    # reformat in place
# Install once: pip install "gdtoolkit==4.*"
# The older scripts/ tree is not covered yet; add paths here as they are
# brought up to the rules.
set -uo pipefail
cd "$(dirname "$0")/.."
PATHS=(framework addons/vox_import tests/unit tools/tests/test_framework_vox.gd tools/tests/test_framework_props.gd tools/tests/test_framework_world.gd)
if ! command -v gdlint >/dev/null; then
	echo "gdlint not installed (pip install gdtoolkit); skipping lint"
	exit 0
fi
if [ "${1:-}" = "--fix" ]; then
	gdformat "${PATHS[@]}"
	exit $?
fi
fail=0
gdlint "${PATHS[@]}" || fail=1
gdformat --check "${PATHS[@]}" || fail=1
exit $fail
