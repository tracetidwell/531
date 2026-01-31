#!/bin/bash

SERVICE_NAME="531-backend"

# Find the most recent application log group (by creation time, most recent first)
get_log_group() {
    aws logs describe-log-groups \
        --log-group-name-prefix "/aws/apprunner/$SERVICE_NAME" \
        --query 'logGroups[?contains(logGroupName, `application`)] | sort_by(@, &creationTime) | [-1].logGroupName' \
        --output text
}

LOG_GROUP=$(get_log_group)

if [ "$LOG_GROUP" == "None" ] || [ -z "$LOG_GROUP" ]; then
    echo "Error: No log group found for $SERVICE_NAME"
    echo "Available log groups:"
    aws logs describe-log-groups --log-group-name-prefix "/aws/apprunner" --query 'logGroups[*].logGroupName' --output table
    exit 1
fi

echo "Using log group: $LOG_GROUP"
echo ""

show_menu() {
    echo "App Runner Log Viewer"
    echo "====================="
    echo "1) Tail logs (real-time)"
    echo "2) Recent logs (last 100 entries)"
    echo "3) Errors only (last hour)"
    echo "4) Errors only (last 24 hours)"
    echo "5) List log streams"
    echo "6) Exit"
    echo ""
    read -p "Select option: " choice
}

format_logs() {
    # Format JSON log events with timestamps
    python3 -c "
import sys
import json
from datetime import datetime

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        event = json.loads(line)
        ts = event.get('timestamp', 0)
        msg = event.get('message', line)
        dt = datetime.fromtimestamp(ts / 1000).strftime('%Y-%m-%d %H:%M:%S')
        print(f'[{dt}] {msg}')
    except:
        print(line)
" 2>/dev/null || cat
}

tail_logs() {
    echo "Tailing logs (Ctrl+C to stop)..."
    aws logs tail "$LOG_GROUP" --follow --format short
}

recent_logs() {
    echo "Fetching recent logs..."
    STREAM=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --query 'logStreams[0].logStreamName' \
        --output text)

    if [ "$STREAM" == "None" ] || [ -z "$STREAM" ]; then
        echo "No log streams found"
        return
    fi

    echo "Log stream: $STREAM"
    echo "---"
    aws logs get-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$STREAM" \
        --limit 100 \
        --output json | python3 -c "
import sys
import json
from datetime import datetime

data = json.load(sys.stdin)
for event in data.get('events', []):
    ts = event.get('timestamp', 0)
    msg = event.get('message', '')
    dt = datetime.fromtimestamp(ts / 1000).strftime('%Y-%m-%d %H:%M:%S')
    print(f'[{dt}] {msg}')
"
}

errors_last_hour() {
    echo "Fetching errors from last hour..."
    START_TIME=$(date -d '1 hour ago' +%s 2>/dev/null || date -v-1H +%s)000
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "?ERROR ?error ?Error ?exception ?Exception ?Traceback" \
        --start-time "$START_TIME" \
        --output json | python3 -c "
import sys
import json
from datetime import datetime

data = json.load(sys.stdin)
for event in data.get('events', []):
    ts = event.get('timestamp', 0)
    msg = event.get('message', '')
    dt = datetime.fromtimestamp(ts / 1000).strftime('%Y-%m-%d %H:%M:%S')
    print(f'[{dt}] {msg}')
"
}

errors_last_day() {
    echo "Fetching errors from last 24 hours..."
    START_TIME=$(date -d '24 hours ago' +%s 2>/dev/null || date -v-24H +%s)000
    aws logs filter-log-events \
        --log-group-name "$LOG_GROUP" \
        --filter-pattern "?ERROR ?error ?Error ?exception ?Exception ?Traceback" \
        --start-time "$START_TIME" \
        --output json | python3 -c "
import sys
import json
from datetime import datetime

data = json.load(sys.stdin)
for event in data.get('events', []):
    ts = event.get('timestamp', 0)
    msg = event.get('message', '')
    dt = datetime.fromtimestamp(ts / 1000).strftime('%Y-%m-%d %H:%M:%S')
    print(f'[{dt}] {msg}')
"
}

list_streams() {
    echo "Recent log streams:"
    aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --limit 10 \
        --output json | python3 -c "
import sys
import json
from datetime import datetime

data = json.load(sys.stdin)
header = 'Stream Name'
header2 = 'Last Event'
print(f'{header:<60} {header2:>20}')
print('-' * 82)
for stream in data.get('logStreams', []):
    name = stream.get('logStreamName', '')[:58]
    ts = stream.get('lastEventTimestamp', 0)
    if ts:
        dt = datetime.fromtimestamp(ts / 1000).strftime('%Y-%m-%d %H:%M:%S')
    else:
        dt = 'N/A'
    print(f'{name:<60} {dt:>20}')
"
}

# Allow direct command line argument
if [ -n "$1" ]; then
    choice=$1
else
    show_menu
fi

case $choice in
    1) tail_logs ;;
    2) recent_logs ;;
    3) errors_last_hour ;;
    4) errors_last_day ;;
    5) list_streams ;;
    6) exit 0 ;;
    *) echo "Invalid option" ;;
esac
