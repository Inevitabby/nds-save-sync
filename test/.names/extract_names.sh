#!/usr/bin/env bash

# Extract names for testing from No-Intro database (https://datomatic.no-intro.org)
#
# USAGE: ./extract_names.sh file.xml > names.txt

grep -o '<game name="[^"]*"' "$1" \
| sed 's/^<game name="//; s/"$//' \
| sort -u
