#!/bin/bash
# Frontend test runner script

set -e

cd "$(dirname "$0")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running 5/3/1 Frontend Tests${NC}"
echo "================================"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed or not in PATH${NC}"
    exit 1
fi

# Get flutter packages
echo -e "\n${YELLOW}Getting packages...${NC}"
flutter pub get

# Run tests based on arguments
case "${1:-all}" in
    "all")
        echo -e "\n${YELLOW}Running all tests...${NC}"
        flutter test
        ;;
    "coverage")
        echo -e "\n${YELLOW}Running tests with coverage...${NC}"
        flutter test --coverage
        echo -e "\n${GREEN}Coverage report generated in coverage/lcov.info${NC}"

        # Generate HTML report if lcov is installed
        if command -v genhtml &> /dev/null; then
            genhtml coverage/lcov.info -o coverage/html --quiet
            echo -e "${GREEN}HTML coverage report: coverage/html/index.html${NC}"
        fi
        ;;
    "models")
        echo -e "\n${YELLOW}Running model tests...${NC}"
        flutter test test/models/
        ;;
    "watch")
        echo -e "\n${YELLOW}Running tests in watch mode...${NC}"
        flutter test --watch
        ;;
    *)
        echo -e "\n${YELLOW}Running tests matching: $1${NC}"
        flutter test --name "$1"
        ;;
esac

echo -e "\n${GREEN}Tests completed!${NC}"
