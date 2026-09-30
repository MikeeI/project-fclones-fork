#!/usr/bin/env bash
set -euo pipefail

readonly WARMUP_RUNS=1
readonly MEASURED_RUNS=3
readonly TIME_LIMIT=29s
readonly KILL_GRACE=1s
readonly THREADS=8

if [[ $# == 1 && $1 == --help ]]; then
    printf 'Usage: bash benchmark.sh DIRECTORY\nRequires Linux, mount privileges, hyperfine and jq; build target/release/fclones first.\n'
    exit 0
fi
if [[ $# != 1 ]]; then
    printf 'Usage: bash benchmark.sh DIRECTORY\n' >&2
    exit 2
fi

root=$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")
readonly root
readonly binary="$root/target/release/fclones"
readonly results="$root/benchmarks/results"
dataset=$(realpath -e -- "$1")
readonly dataset
if [[ ! -d $dataset || ! -x $binary ]]; then
    printf 'benchmark: requires a directory and target/release/fclones; build with cargo build --release --locked -p fclones\n' >&2
    exit 2
fi
if [[ $dataset == /mnt || $dataset == /mnt/* || "$results/" == "$dataset/"* ]]; then
    printf 'benchmark: choose a local directory outside /mnt that does not contain benchmarks/results\n' >&2
    exit 2
fi
for tool in hyperfine jq timeout unshare mount; do
    command -v "$tool" >/dev/null || {
        printf 'benchmark: missing %s\n' "$tool" >&2
        exit 2
    }
done

mkdir -p -- "$results"
result="$results/$(date -u +%Y%m%dT%H%M%S.%N)-$(git -C "$root" rev-parse --short HEAD).json"
log=$(mktemp)
trap 'rm -f -- "$log"' EXIT
command=$(jq -rn --arg binary "$binary" --arg dataset "$dataset" --arg threads "$THREADS" \
    '[$binary, "group", "--threads", ("main:" + $threads), "--threads", ("default:" + $threads),
      "--hash-fn", "metro", "--hidden", "--no-ignore", $dataset] | @sh')

# Device discovery touches unrelated automounts even for local scans.
# Mask /mnt only inside a private namespace; host mounts remain untouched.
# Namespace setup is outside the measured commands, and file-hash caching stays disabled.
if unshare --mount --propagation private -- bash -c \
    'mount -t tmpfs -o size=4k,nosuid,nodev,noexec benchmark-local /mnt && exec "$@"' \
    bash timeout --kill-after="$KILL_GRACE" "$TIME_LIMIT" \
    hyperfine --shell=none --warmup "$WARMUP_RUNS" --runs "$MEASURED_RUNS" \
    --style basic --export-json "$result" "$command" >"$log" 2>&1; then
    jq -r --arg result "$result" '.results[0] |
        "benchmark: ok", "runs: \(.times | length)", "median_seconds: \(.median)",
        "stddev_seconds: \(.stddev)", "result: \($result)"' "$result"
else
    status=$?
    printf 'benchmark: failed (exit %s); no completed comparison result\n' "$status" >&2
    cat -- "$log" >&2
    exit "$status"
fi
