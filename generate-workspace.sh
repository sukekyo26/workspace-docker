#!/bin/bash

# Script to automatically generate .code-workspace file for multi-root workspace
# Usage: ./generate-workspace.sh [output_path]
# If output path is not specified, generates multi-project.code-workspace in workspace-docker directory

set -euo pipefail

# Determine output file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="${1:-$SCRIPT_DIR/multi-project.code-workspace}"

echo "Scanning parent directory: $PARENT_DIR"
echo "Output file: $OUTPUT_FILE"

# Start JSON file
cat > "$OUTPUT_FILE" << 'EOF'
{
	"folders": [
EOF

# Enumerate directories in parent directory (excluding hidden directories)
first=true
while IFS= read -r dir; do
	# Get directory name only
	dirname=$(basename "$dir")

	# Handle comma
	if [ "$first" = true ]; then
		first=false
	else
		echo "," >> "$OUTPUT_FILE"
	fi

	# Add folder entry
	cat >> "$OUTPUT_FILE" << EOF
		{
			"name": "$dirname",
			"path": "../$dirname"
		}
EOF
done < <(find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d ! -name ".*" | sort)

# End JSON file
cat >> "$OUTPUT_FILE" << 'EOF'

	],
	"settings": {
		// Add global settings here
		"files.autoSave": "afterDelay",
		"editor.formatOnSave": true
	}
}
EOF

echo "✅ Workspace file generated: $OUTPUT_FILE"
echo ""
echo "Included projects:"
grep '"name":' "$OUTPUT_FILE" | sed 's/.*"name": "\(.*\)".*/  - \1/'
echo ""
echo "To open, run:"
echo "  code \"$OUTPUT_FILE\""
