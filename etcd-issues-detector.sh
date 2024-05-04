#!/bin/bash

# Check if jq is installed
jq_check() {
    if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required but not found. Please install it."
    exit 1
    fi
}

# Function to display etcd errors
errors() {
    local logs_dir="namespaces"
    local output_arr=()
    local error_patterns=(
        "waiting for ReadIndex response took too long, retrying"
        "etcdserver: request timed out"
        "slow fdatasync"
        "\"apply request took too long\""
        "\"leader failed to send out heartbeat on time; took too long, leader is overloaded likely from slow disk\""
        "local node might have slow network"
        "elected leader"
        "lost leader"
        "wal: sync duration"
        "the clock difference against peer"
        "lease not found"
        "rafthttp: failed to read"
        "server is likely overloaded"
        "lost the tcp streaming"
        "sending buffer is full"
        "health errors"
    )

    for log_file in "${logs_arr[@]}"; do
        for error_pattern in "${error_patterns[@]}"; do
            if grep -q -E "$error_pattern" "$logs_dir/$log_file"; then
                local error_count=$(grep -c -E "$error_pattern" "$logs_dir/$log_file")
                output_arr+=(
                    "$(echo "$log_file" | awk -F/ '{ print $NF }')"\
                    "$(echo "$log_file" | awk -F/ '{ print $NF-2 }')"\
                    "$(echo "$error_pattern" | awk -F': ' '{ print $2 }') | $error_count"
                )
            fi
        done
    done

    if [ "${#output_arr[@]}" != 0 ]; then
        printf '%s\n' "${output_arr[@]}" | column -t -s '|'
        printf "\n"
    fi
}

# Function to display etcd statistics
stats() {
    local logs_dir="namespaces"
    local duration_arr=()

    for log_file in "${logs_arr[@]}"; do
        local error_pattern='took too long.*expec'
        local min_ms
        local max ms
        local sum=0
        local count=0

        while IFS= read -r line; do
            local compact_ms
            local duration=$(jq -r '.took' <<< "$line")

            if [[ $duration =~ [1-9]m[0-9] ]]; then
                min_ms=$(echo "scale=5;($(echo $duration | grep -Eo '[1-9]m' | sed 's/m//')*60000)/1" | bc)
                sec_ms=$(echo "scale=5;($(echo $duration | sed -E 's/[1-9]+m//' | grep -Eo '[1-9]?\.[0-9]+')*1000)/1" | bc)
                compact_ms=$(echo "scale=5;$min_ms + $sec_ms" | bc)
            elif [[ $duration =~ [1-9]s ]]; then
                compact_ms=$(echo "scale=5;($(echo $duration | sed 's/s//')*1000)/1" | bc)
            else
                compact_ms=$(echo $duration | sed 's/ms//')
            fi

            if [ -z "$min_ms" ] || (( $(echo "$compact_ms < $min_ms" | bc -l) )); then
                min_ms=$compact_ms
            fi

            if [ -z "$max_ms" ] || (( $(echo "$compact_ms > $max_ms" | bc -l) )); then
                max_ms=$compact_ms
            fi
            
            sum=$(echo "$sum + $compact_ms" | bc)
            ((count++))
            duration_arr+=($compact_ms)
        done < <(grep -E "$error_pattern" "$logs_dir/$log_file" | jq -c '.[]')

        local average=$(echo "scale=5; $sum / $count" | bc)
        local sorted_arr=($(printf "%s\n" "${duration_arr[@]}" | sort -n))
        local len=${#sorted_arr[@]}
        local duration

        if ((len % 2 == 0)); then
            local mid1=$((len / 2 - 1))
            local mid2=$((len / 2))
            duration=$(echo "scale=5; (${sorted_arr[$mid1]} + ${sorted_arr[$mid2]}) / 2" | bc)
        else
            local mid=$((len / 2))
            duration=${sorted_arr[$mid]}
        fi
        printf "Stats about etcd 'took long' messages: $(echo "$log_file" | awk -F/ '{ print $(NF-2) }')\n"
        printf "\tMaximum: ${max_ms}ms\n"
        printf "\tMinimum: ${min_ms}ms\n"
        printf "\tDuration: ${duration}ms\n"
        printf "\tAverage: ${average}ms\n"
        printf "\tCount: ${count}\n\n"
    done
}

# Function to search etcd logs
search_etcd() {
    local logs_dir="namespaces"
    local output_arr=()
    local error_pattern='took too long.*expec'

    for log_file in "${logs_arr[@]}"; do
        local namespace=$(echo "$log_file" | awk -F/ '{ print $(NF-2) }')
        local count=$(grep -c -E "$error_pattern" "$logs_dir/$log_file")
        output_arr+=("$namespace|$(basename "$log_file")|$count")
    done

    if [ "${#output_arr[@]}" != 0 ]; then
        printf '%s\n' "${output_arr[@]}" | column -t -s '|'
        printf "\n"
    else
        printf '%s\n' "No results found for: $error_pattern"
    fi
}

show_help() {
    cat << EOF
USAGE: $(basename "$0")
etcd-issues-detector is a simple script which provides reporting on etcd errors
in a must-gather/inspect to pinpoint when slowness is occurring.

Options:
  --errors           Displays known errors in the etcd logs along with their count
  --stats            Displays statistics and calculates Avg, Max, Min, and duration times for etcd errors
  --ttl              Displays 'took too long' errors
  --pod <pod_name>   Specify the name of the pod to search              
  --date <date>      Specify the date in YYYY-MM-DD format               
  --time <time>      Opens Pod Logs in less with specified time; Specify the time HH:MM format
  --help             Shows this help message

EOF
}

# Main function
main() {
    local logs_arr=("etcd")
    local logs="current"

 # Check if in must-gather folder
    if [ -d ! "namespaces" ]; then
        echo "ERROR: 'namespaces' directory not found. Please run this script inside a must-gather folder."
        exit 1
    fi

# Verify jq is installed
    jq_check

    local errors=false
    local stats=false
    local search_etcd_cmd=""

  # Parse command line arguments
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --errors) errors=true ;;
            --stats) stats=true ;;
            --pod) pod="$2"; shift ;;
            --date) date="$2"; shift ;;
            --time) time="$2"; shift ;;
            --ttl) search_etcd_cmd="ttl" ;;
            -h | --help) show_help; exit 0 ;;
            *) echo "Unknown option: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    if [[ "$errors" = true ]]; then
        errors "$logs" "$logs_dir" "${logs_arr[@]}"
    fi

    if [[ "$stats" = true ]]; then
        stats "$logs" "$logs_dir" "${logs_arr[@]}"
    fi

    case "$search_etcd_cmd" in
        ttl) search_etcd "$logs" "$logs_dir" "${logs_arr[@]}" ;;
    esac
}

main "$@"
