#!/bin/bash

# 5/3/1 Training App Startup Script
# This script starts the backend and Flutter app (web or mobile)

set -e  # Exit on error

echo "========================================="
echo "Starting 5/3/1 Training App"
echo "========================================="
echo ""

# Prompt for platform choice
echo "Choose platform:"
echo "  1) Web (Chrome)"
echo "  2) Mobile (Android Emulator)"
echo ""
read -p "Enter choice [1-2]: " platform_choice

# Validate input
if [[ ! "$platform_choice" =~ ^[1-2]$ ]]; then
    echo "Error: Invalid choice. Please enter 1 or 2."
    exit 1
fi

# Set platform based on choice
if [ "$platform_choice" == "1" ]; then
    PLATFORM="web"
    PLATFORM_NAME="Web (Chrome)"
    FLUTTER_DEVICE="chrome"
else
    PLATFORM="mobile"
    PLATFORM_NAME="Mobile (Android Emulator)"
    FLUTTER_DEVICE=""  # Will use default emulator
fi

echo ""
echo "Selected platform: $PLATFORM_NAME"
echo "========================================="
echo ""

# Check if backend directory exists
if [ ! -d "/home/trace/Documents/531/backend" ]; then
    echo "Error: Backend directory not found!"
    exit 1
fi

# Check if frontend directory exists
if [ ! -d "/home/trace/Documents/531/frontend" ]; then
    echo "Error: Frontend directory not found!"
    exit 1
fi

# Start backend
echo ""
if [ "$PLATFORM" == "web" ]; then
    echo "[1/2] Starting FastAPI backend..."
else
    echo "[1/4] Starting FastAPI backend..."
fi
cd /home/trace/Documents/531/backend

# Use virtual environment Python to run uvicorn
venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/531-backend.log 2>&1 &
BACKEND_PID=$!
echo "Backend started (PID: $BACKEND_PID)"

# Wait for backend to start
if [ "$PLATFORM" == "web" ]; then
    echo "[2/2] Waiting for backend to initialize..."
else
    echo "[2/4] Waiting for backend to initialize..."
fi
sleep 5

# Verify backend is running
if curl -s http://localhost:8000/docs > /dev/null 2>&1; then
    echo "Backend is ready! ✓"
else
    echo "Warning: Backend might not be ready yet (continuing anyway)"
fi

# Start emulator only if mobile platform selected
if [ "$PLATFORM" == "mobile" ]; then
    echo ""
    echo "[3/4] Starting Android emulator..."
    flutter emulators --launch Medium_Phone_API_36.1 > /tmp/531-emulator.log 2>&1 &
    EMULATOR_PID=$!

    echo "Waiting for emulator to boot..."
    echo "(This may take 30-60 seconds on first boot)"

    # Wait for emulator to be ready
    timeout=120  # 2 minutes timeout
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if adb devices | grep -q "emulator.*device$"; then
            echo "Emulator is ready! ✓"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo "  Still waiting... ($elapsed seconds)"
    done

    if [ $elapsed -ge $timeout ]; then
        echo "Warning: Emulator took longer than expected (continuing anyway)"
    fi

    # Give emulator a bit more time to fully boot
    sleep 5

    STEP_NUM="[4/4]"
else
    # Web platform - skip emulator
    echo ""
    STEP_NUM="[2/2]"
fi

# Run Flutter app
echo ""
echo "$STEP_NUM Launching Flutter app on $PLATFORM_NAME..."
cd /home/trace/Documents/531/frontend

echo ""
echo "========================================="
echo "App is starting on $PLATFORM_NAME!"
echo "========================================="
echo ""
echo "Hot reload commands:"
echo "  r - Hot reload"
echo "  R - Hot restart"
echo "  q - Quit app"
echo ""
echo "Backend logs: /tmp/531-backend.log"
if [ "$PLATFORM" == "mobile" ]; then
    echo "Emulator logs: /tmp/531-emulator.log"
fi
echo ""
if [ "$PLATFORM" == "web" ]; then
    echo "Web app will open in Chrome"
fi
echo "Press Ctrl+C to stop everything"
echo "========================================="
echo ""

# Run Flutter (this blocks until app exits)
if [ "$PLATFORM" == "web" ]; then
    flutter run -d chrome
else
    flutter run
fi

# Cleanup function
cleanup() {
    echo ""
    echo "========================================="
    echo "Shutting down..."
    echo "========================================="

    if [ ! -z "$BACKEND_PID" ]; then
        echo "Stopping backend (PID: $BACKEND_PID)..."
        kill $BACKEND_PID 2>/dev/null || true
    fi

    if [ "$PLATFORM" == "mobile" ]; then
        echo "Stopping emulator..."
        adb emu kill 2>/dev/null || true
    fi

    echo "Cleanup complete!"
}

# Register cleanup function to run on script exit
trap cleanup EXIT
