#!/usr/bin/env bash
F="$(dirname "$0")/../memory/usage.log"; mkdir -p "$(dirname "$F")"
printf '%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$1" "$2" >> "$F"
