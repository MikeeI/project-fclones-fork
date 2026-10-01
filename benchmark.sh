#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

readonly WARMUP_RUNS=1
readonly MEASURED_RUNS=3
readonly TIME_LIMIT=29s
readonly KILL_GRACE=1s
readonly DEFAULT_THREADS=8
readonly DEFAULT_HASH_FN=metro
readonly DEFAULT_DEVICE_POOL=default
readonly main_threads="${BENCHMARK_MAIN_THREADS:-$DEFAULT_THREADS}"
readonly random_threads="${BENCHMARK_RANDOM_THREADS:-$DEFAULT_THREADS}"
readonly sequential_threads="${BENCHMARK_SEQUENTIAL_THREADS:-$random_threads}"
readonly hash_fn="${BENCHMARK_HASH_FN:-$DEFAULT_HASH_FN}"
readonly device_pool="${BENCHMARK_DEVICE_POOL:-$DEFAULT_DEVICE_POOL}"
cache_home="${BENCHMARK_CACHE_HOME-}"
json_output=false
if [[ ${1-} == --json ]]; then
    json_output=true
    shift
fi

if [[ $# == 1 && $1 == --help ]]; then
    printf 'Usage: bash benchmark.sh [--json] DIRECTORY\nRequires Linux, mount privileges, hyperfine, jq and GNU time; build release binary and examples first.\nOverrides: BENCHMARK_MAIN_THREADS, BENCHMARK_RANDOM_THREADS, BENCHMARK_SEQUENTIAL_THREADS,\nBENCHMARK_DEVICE_POOL, BENCHMARK_HASH_FN, BENCHMARK_BINARY.\nBENCHMARK_DEVICE_POOL=native leaves per-device defaults unchanged.\nBENCHMARK_CACHE_HOME is restricted to disposable /tmp/fclones-ssd-* corpora and caches.\n'
    exit 0
fi
if [[ $# != 1 ]]; then
    printf 'Usage: bash benchmark.sh [--json] DIRECTORY\n' >&2
    exit 2
fi

root=$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")
readonly root
readonly binary="${BENCHMARK_BINARY:-$root/target/release/fclones}"
readonly inspector="$root/target/release/examples/device-info"
readonly results="$root/benchmarks/results"
dataset=$(realpath -e -- "$1")
readonly dataset
if [[ ! -d $dataset || ! -x $binary || ! -x $inspector ]]; then
    printf 'benchmark: requires a directory, release binary and device-info; run cargo build --release --locked -p fclones --examples --bin fclones\n' >&2
    exit 2
fi
for count in "$main_threads" "$random_threads" "$sequential_threads"; do
    if [[ ! $count =~ ^[1-9][0-9]*$ ]]; then
        printf 'benchmark: thread counts must be positive integers\n' >&2
        exit 2
    fi
done
case "$hash_fn" in
metro | xxhash | blake3 | sha256 | sha512 | sha3-256 | sha3-512) ;;
*)
    printf 'benchmark: unsupported hash function: %s\n' "$hash_fn" >&2
    exit 2
    ;;
esac
if [[ -n $cache_home ]]; then
    cache_home=$(realpath -m -- "$cache_home")
    if [[ $dataset != /tmp/fclones-ssd-*/* || $cache_home != /tmp/fclones-ssd-*/* || "$cache_home/" == "$dataset/"* ]]; then
        printf 'benchmark: hash caching requires a disposable corpus and separate cache under /tmp/fclones-ssd-*\n' >&2
        exit 2
    fi
    mkdir -p -- "$cache_home"
fi
readonly cache_home
if [[ $dataset == /mnt || $dataset == /mnt/* || "$results/" == "$dataset/"* ]]; then
    printf 'benchmark: choose a local directory outside /mnt that does not contain benchmarks/results\n' >&2
    exit 2
fi
for tool in hyperfine jq timeout unshare mount /usr/bin/time; do
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
usage=$(mktemp)
devices=$(mktemp)
scan_args=(--threads "main:$main_threads")
if [[ $device_pool != native ]]; then
    scan_args+=(--threads "$device_pool:$random_threads,$sequential_threads")
fi
# Keep report generation in the measured path without copying report payloads into diagnostics.
scan_args+=(--hash-fn "$hash_fn" --hidden --no-ignore --output /dev/null "$dataset")
scan=("$binary" group "${scan_args[@]}")
if [[ -n $cache_home ]]; then
    scan=(env "XDG_CACHE_HOME=$cache_home" "${scan[@]}" --cache)
fi
command=$(jq -rn --args '[$ARGS.positional[]] | @sh' -- \
    /usr/bin/time -f '%M %U %S %e' -a -o "$usage" "${scan[@]}")

# Publish a started record before execution so even a hard kill leaves evidence.
# The application may drop file pages under low free memory, so warmup alone cannot prove cache residency.
jq -n --arg started_at "$started_at" --arg dataset "$dataset" --arg command "$command" \
    --arg revision "$revision" --arg binary_hash "$binary_hash" \
    --argjson warmup_runs "$WARMUP_RUNS" --argjson measured_runs "$MEASURED_RUNS" \
    --argjson time_limit "${TIME_LIMIT%s}" --arg hash_fn "$hash_fn" \
    --arg cache_home "$cache_home" \
    '{status: "running", exit_code: null, results: [], metadata: {
        started_at: $started_at, dataset: $dataset, command: $command,
        checkout_revision: $revision, binary_sha256: $binary_hash,
        hash_fn: $hash_fn, hash_cache_home: $cache_home,
        page_cache: "no host-wide flush; warmup is not a residency guarantee; application policy unchanged",
        devices: null, warmup_runs: $warmup_runs,
        requested_runs: $measured_runs, time_limit_seconds: $time_limit
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
        --rawfile diagnostics "$log" --rawfile native "$native_result" --rawfile usage "$usage" \
        '. + {status: $outcome, exit_code: $status, finished_at: $finished_at,
            diagnostics: $diagnostics,
            resource_samples: ($usage | split("\n") | map(select(test("^[0-9]+ [0-9.]+ [0-9.]+ [0-9.]+$"))) |
                map(split(" ") | {max_rss_kib: (.[0] | tonumber),
                    user_seconds: (.[1] | tonumber), system_seconds: (.[2] | tonumber),
                    elapsed_seconds: (.[3] | tonumber)})),
            results: (if $status == 0 then ($native | fromjson | .results) else [] end)}
        + (if $status != 0 and ($native | length) > 0 then {partial_export: $native} else {} end)' \
        "$result" >"$result.tmp"
    mv -- "$result.tmp" "$result"
    rm -f -- "$log" "$native_result" "$usage" "$devices"

    if [[ $json_output == true ]]; then
        jq . "$result"
    fi
    if [[ $status == 0 && $json_output == false ]]; then
        jq -r --arg result "$result" '.results[0] |
            "benchmark: ok", "runs: \(.times | length)", "median_seconds: \(.median)",
            "stddev_seconds: \(.stddev)", "result: \($result)"' "$result"
    elif [[ $status != 0 ]]; then
        printf 'benchmark: %s (exit %s)\nresult: %s\n' "$outcome" "$status" "$result" >&2
        jq -r '.diagnostics' "$result" >&2
    fi
    exit "$status"
}
trap 'save_result "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Inspect the same device mapping inside the same mount namespace as the measured command.
unshare --mount --propagation private -- bash -c \
    'mount -t tmpfs -o size=4k,nosuid,nodev,noexec benchmark-local /mnt && exec "$@"' \
    bash "$inspector" --json "${scan_args[@]}" >"$devices" 2>>"$log"
jq --slurpfile devices "$devices" '.metadata.devices = $devices[0]' "$result" >"$result.tmp"
mv -- "$result.tmp" "$result"

# Device discovery touches unrelated automounts even for local scans.
# Mask /mnt only inside a private namespace; host mounts remain untouched.
# Namespace setup is outside the measured commands; real datasets never use the hash cache.
if unshare --mount --propagation private -- bash -c \
    'mount -t tmpfs -o size=4k,nosuid,nodev,noexec benchmark-local /mnt && exec "$@"' \
    bash timeout --kill-after="$KILL_GRACE" "$TIME_LIMIT" \
    hyperfine --shell=none --warmup "$WARMUP_RUNS" --runs "$MEASURED_RUNS" \
    --show-output --export-json "$native_result" "$command" >"$log" 2>&1; then
    save_result 0
else
    save_result "$?"
fi
