#!/bin/bash

# Basic CHANGELOG.md generator from git log
# Usage: ./generate-changelog-basic.sh [output-file]

OUTPUT_FILE="${1:-CHANGELOG.md}"
REPO_NAME=$(basename "$(git rev-parse --show-toplevel)")

echo "# Changelog" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "All notable changes to $REPO_NAME will be documented in this file." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Generated on $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Get all commits with one-line format
echo "## All Commits" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

git log --oneline --reverse | while read -r line; do
    hash=$(echo "$line" | cut -d' ' -f1)
    message=$(echo "$line" | cut -d' ' -f2-)
    date=$(git show -s --format=%cd --date=short "$hash")
    
    echo "- **$date** [$hash] $message" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "*Generated from git log on $(date)*" >> "$OUTPUT_FILE"

echo "✅ CHANGELOG.md generated successfully!"
echo "📄 File: $OUTPUT_FILE"
