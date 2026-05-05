#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

swift build
swift run ParserSmokeTest

if command -v swift-format >/dev/null 2>&1; then
    swift-format lint --recursive Sources SmokeTests Package.swift
else
    echo "swift-format nao encontrado; pulando lint opcional."
fi

echo "Verificacao concluida."
