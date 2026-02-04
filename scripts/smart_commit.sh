#!/bin/bash

# Smart Commit Script
# 1. Runs automatic tests
# 2. If tests pass -> Commits and Pushes
# 3. If tests fail -> Stops and alerts you

echo "🔍 STATUS: Starting Smart Verification..."

# 1. Run Logic Tests (Fast)
echo "🧪 RUNNING: Unit & Logic Tests..."
flutter test
if [ $? -ne 0 ]; then
    echo "❌ FAILURE: Unit tests failed. Fix errors before committing."
    exit 1
fi

# 2. Run Sync Verification (Critical)
echo "🔄 RUNNING: Sync Logic Verification..."
flutter test test/sync_logic_test.dart
if [ $? -ne 0 ]; then
    echo "❌ FAILURE: Sync logic broken. This is critical for data safety."
    exit 1
fi

echo "✅ SUCCESS: All verification checks passed!"

# 3. Commit and Push
echo "📦 STATUS: Committing changes..."
git add .

# Get commit message from argument or prompt
if [ -z "$1" ]; then
    read -p "📝 Enter commit message: " msg
else
    msg="$1"
fi

git commit -m "$msg"

echo "🚀 STATUS: Pushing to GitHub..."
git push

if [ $? -eq 0 ]; then
    echo "🎉 DONE: Code is tested, committed, and live!"
else
    echo "⚠️ WARNING: Push failed (check internet or git status)."
fi
