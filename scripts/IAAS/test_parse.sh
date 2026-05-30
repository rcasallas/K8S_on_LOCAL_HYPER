#!/bin/bash
line='OVA_FILE := "fedora-coreos-43.20260316.3.1-virtualbox.x86_64.ova"'
if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:?=[[:space:]]*(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    val="${val%\"}"
    val="${val#\"}"
    export "$key=$val"
    echo "$key=$val"
fi
