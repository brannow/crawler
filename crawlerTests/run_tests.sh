#!/bin/bash

# Test runner script for crawler tests
# This script helps run the comprehensive test suite

echo "🧪 Starting Crawler Test Suite..."
echo "=================================="

# Build the project first
echo "📦 Building project..."
xcodebuild -project ../crawler.xcodeproj -scheme crawler -configuration Debug build

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Cannot run tests."
    exit 1
fi

echo "✅ Build successful!"

# Run the test suite
echo "🏃 Running tests..."
xcodebuild test -project ../crawler.xcodeproj -scheme crawler -destination 'platform=macOS'

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed. Check the output above for details."
    exit 1
fi

echo "🎉 Test suite completed successfully!"