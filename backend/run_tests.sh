#!/bin/bash
# Run backend tests for 5/3/1 Training App

set -e

cd "$(dirname "$0")"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  5/3/1 Training App - Backend Tests   ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Parse arguments
VERBOSE=""
COVERAGE=""
PATTERN=""
FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        --cov|--coverage)
            COVERAGE="--cov=app --cov-report=term-missing"
            shift
            ;;
        --html)
            COVERAGE="--cov=app --cov-report=html --cov-report=term-missing"
            shift
            ;;
        -k)
            PATTERN="-k $2"
            shift 2
            ;;
        -f|--file)
            FILE="tests/$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./run_tests.sh [options]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose     Verbose output"
            echo "  --cov, --coverage Run with coverage report"
            echo "  --html            Run with HTML coverage report (opens htmlcov/index.html)"
            echo "  -k PATTERN        Run tests matching pattern"
            echo "  -f, --file FILE   Run specific test file (e.g., test_workouts.py)"
            echo "  -h, --help        Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./run_tests.sh                    # Run all tests"
            echo "  ./run_tests.sh -v                 # Run with verbose output"
            echo "  ./run_tests.sh --cov              # Run with coverage"
            echo "  ./run_tests.sh -k amrap           # Run tests matching 'amrap'"
            echo "  ./run_tests.sh -f test_workouts.py # Run specific file"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo -e "${RED}pytest not found. Installing dependencies...${NC}"
    pip install -r requirements.txt
fi

# Build the pytest command
CMD="pytest $VERBOSE $COVERAGE $PATTERN $FILE"

echo -e "${YELLOW}Running: $CMD${NC}"
echo ""

# Run tests
$CMD

# Check result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  All tests passed!                    ${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  Some tests failed                    ${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi

# Open HTML coverage report if generated
if [[ "$COVERAGE" == *"html"* ]] && [ -d "htmlcov" ]; then
    echo ""
    echo -e "${YELLOW}Opening HTML coverage report...${NC}"
    if command -v xdg-open &> /dev/null; then
        xdg-open htmlcov/index.html
    elif command -v open &> /dev/null; then
        open htmlcov/index.html
    else
        echo "Coverage report available at: htmlcov/index.html"
    fi
fi
