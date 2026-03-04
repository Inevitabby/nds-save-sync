#!/usr/bin/env bash

# Creates a mock FTP server (to play the role of the DS during testing)
#
# USAGE:
# ./mock_server.sh

cd "$(dirname "$0")" || exit
uvx --from pyftpdlib python -m pyftpdlib -p 5000 -d ./mock_server
