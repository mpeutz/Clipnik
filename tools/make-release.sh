#!/bin/bash
# Builds dist/Clipnik-<version>.zip from the committed HEAD: the app and its runtime in a Clipnik folder, without
# the development files (.gitattributes export-ignore). Refuses while the working tree has changes, so the zip is
# exactly one commit. The version is Clipnik.ahk's VERSION.
set -eu
cd "$(dirname "$0")/.."
if [ -n "$(git status --porcelain)" ]; then
  echo "The working tree has changes: commit or stash them first, the zip is built from HEAD."
  exit 1
fi
version=$(sed -n 's/^global VERSION := "\([^"]*\)".*/\1/p' Clipnik.ahk | tr -d '\r')
[ -n "$version" ] || { echo "No VERSION found in Clipnik.ahk"; exit 1; }
mkdir -p dist
zip="dist/Clipnik-$version.zip"
rm -f "$zip"
git archive --format=zip --prefix=Clipnik/ -o "$zip" HEAD
echo "Built $zip ($(du -h "$zip" | cut -f1)) from $(git rev-parse --short HEAD)"
