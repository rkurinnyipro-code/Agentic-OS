#!/usr/bin/env bash
echo -e "$(date +%Y-%m-%dT%H:%M:%S%z)\t$1\t$2" >> "$(dirname "$0")/../memory/usage.log"
