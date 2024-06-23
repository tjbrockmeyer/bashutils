#!/usr/bin/env bash
# shellcheck disable=SC2034

# the top-level directory of the repo including these script utils
# usage: "$HOME_REPO"/some/path
HOME_REPO="$(cd "$__THIS_DIR" && git rev-parse --show-toplevel)"

# the top-level directory of the repo including the cwd
# usage: "$TOP"/some/path
REPO="$(git rev-parse --show-toplevel)"
