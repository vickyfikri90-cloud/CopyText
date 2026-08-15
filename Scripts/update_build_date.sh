#!/bin/sh
set -e

OUTPUT="${SRCROOT}/CopyText/BuildInfo.generated.swift"
BUILD_DATE=$(date "+%Y-%m-%d %H:%M")

cat > "${OUTPUT}" <<EOF
// Auto-generated at compile time — do not edit
enum BuildInfo {
    static let compiledAt = "${BUILD_DATE}"
}
EOF

echo "CopyText build date set to ${BUILD_DATE}"
