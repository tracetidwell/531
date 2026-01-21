#!/bin/bash

# 5/3/1 Training App Stop Script
# Stops all running components

echo "Stopping 5/3/1 Training App..."

# Stop backend
echo "Stopping backend..."
pkill -f "uvicorn app.main:app" || echo "Backend not running"

# Stop emulator
echo "Stopping emulator..."
adb emu kill 2>/dev/null || echo "Emulator not running"

# Stop any Flutter processes
echo "Stopping Flutter processes..."
pkill -f "flutter run" || echo "Flutter not running"

echo "All components stopped!"
