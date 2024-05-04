# etcd Issues Detector

This script provides reporting on etcd errors in a must-gather/inspect to pinpoint when slowness is occurring.

## Usage
./etcd-issues-detector.sh [options]

### Options

- `--errors`: Displays known errors in the etcd logs along with their count.
- `--stats`: Displays statistics and calculates Avg, Max, Min, and duration times for etcd errors.
- `--pod <pod_name>`: Specify the name of the pod to search.
- `--date <date>`: Specify the date in YYYY-MM-DD format.
- `--time <time>`: Opens Pod Logs in less with specified time; Specify the time HH:MM format.
- `--ttl`: Displays 'took too long' errors.
- `-h` or `--help`: Shows this help message.

## Prerequisites

- This script requires `jq` to be installed. If `jq` is not installed, it will prompt you to install it.

## How to Use

1. Place the script (`etcd-issues-detector.sh`) in the root directory of your must-gather/inspect folder.
2. Open a terminal and navigate to the must-gather/inspect folder.
3. Run the script with desired options.

## Example

To display known errors in the etcd logs along with their count:
./etcd-issues-detector.sh --errors

To display statistics for etcd errors:
./etcd-issues-detector.sh --stats

## Notes

- Make sure to run this script inside a must-gather/inspect folder.
- Ensure that the `namespaces` directory is present in the must-gather/inspect folder.
