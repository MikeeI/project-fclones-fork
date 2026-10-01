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
started_at=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)
revision=$(git -C "$root" rev-parse HEAD)
result="$results/$(date -u +%Y%m%dT%H%M%S.%N)-${revision:0:7}.json"
binary_hash=$(sha256sum -- "$binary")
binary_hash=${binary_hash%% *}
log=$(mktemp)
native_result=$(mktemp)
command=$(jq -rn --arg binary "$binary" --arg dataset "$dataset" --arg threads "$THREADS" \
    '[$binary, "group", "--threads", ("main:" + $threads), "--threads", ("default:" + $threads),
      "--hash-fn", "metro", "--hidden", "--no-ignore", $dataset] | @sh')

# Publish a started record before execution so even a hard kill leaves evidence.
jq -n --arg started_at "$started_at" --arg dataset "$dataset" --arg command "$command" \
    --arg revision "$revision" --arg binary_hash "$binary_hash" \
    --argjson warmup_runs "$WARMUP_RUNS" --argjson measured_runs "$MEASURED_RUNS" \
    --argjson time_limit "${TIME_LIMIT%s}" \
    '{status: "running", exit_code: null, results: [], metadata: {
        started_at: $started_at, dataset: $dataset, command: $command,
        checkout_revision: $revision, binary_sha256: $binary_hash,
        warmup_runs: $warmup_runs, requested_runs: $measured_runs, time_limit_seconds: $time_limit
    }}' >"$result"

save_result() {
    local status=$1 outcome=failed
    trap - EXIT
    case "$status" in
    0) outcome=complete ;;
    124) outcome=timed_out ;;
    130 | 143) outcome=interrupted ;;
    esac

    # Hyperfine exports timings only on completion; preserve partial raw output on failure.
    jq --arg outcome "$outcome" --argjson status "$status" \
        --arg finished_at "$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)" \
        --rawfile diagnostics "$log" --rawfile native "$native_result" \
        '. + {status: $outcome, exit_code: $status, finished_at: $finished_at,
            diagnostics: $diagnostics,
            results: (if $status == 0 then ($native | fromjson | .results) else [] end)}
        + (if $status != 0 and ($native | length) > 0 then {partial_export: $native} else {} end)' \
        "$result" >"$result.tmp"
    mv -- "$result.tmp" "$result"
    rm -f -- "$log" "$native_result"

    if [[ $status == 0 ]]; then
        jq -r --arg result "$result" '.results[0] |
            "benchmark: ok", "runs: \(.times | length)", "median_seconds: \(.median)",
            "stddev_seconds: \(.stddev)", "result: \($result)"' "$result"
    else
        printf 'benchmark: %s (exit %s)\nresult: %s\n' "$outcome" "$status" "$result" >&2
        jq -r '.diagnostics' "$result" >&2
    fi
    exit "$status"
}
trap 'save_result "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Device discovery touches unrelated automounts even for local scans.
# Mask /mnt only inside a private namespace; host mounts remain untouched.
# Namespace setup is outside the measured commands, and file-hash caching stays disabled.
if unshare --mount --propagation private -- bash -c \
    'mount -t tmpfs -o size=4k,nosuid,nodev,noexec benchmark-local /mnt && exec "$@"' \
    bash timeout --kill-after="$KILL_GRACE" "$TIME_LIMIT" \
    hyperfine --shell=none --warmup "$WARMUP_RUNS" --runs "$MEASURED_RUNS" \
    --style basic --export-json "$native_result" "$command" >"$log" 2>&1; then
    save_result 0
else
    save_result "$?"
fi
