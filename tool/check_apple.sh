#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/tandem-apple.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
# The plugin and Pigeon's code need Flutter; the model code does not.
sources=()
for file in packages/tandem/darwin/tandem/Sources/tandem/*.swift; do
  case "$file" in
    */TandemPlugin.swift | *.g.swift) ;;
    *) sources+=("$file") ;;
  esac
done
xcrun swiftc -parse-as-library -swift-version 6 \
  -module-cache-path "$build_dir/cache" \
  "${sources[@]}" \
  packages/tandem/darwin/Tests/Contracts.swift \
  -o "$build_dir/contracts"
"$build_dir/contracts"
# tool/apple_smoke.swift needs the real model, so it is only compiled here.
xcrun swiftc -parse-as-library -swift-version 6 \
  -module-cache-path "$build_dir/cache" \
  "${sources[@]}" \
  tool/apple_smoke.swift \
  -o "$build_dir/smoke"
