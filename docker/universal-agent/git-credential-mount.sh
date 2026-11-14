#!/bin/bash
if [ "$1" = "get" ]; then
    TOKEN=$(cat /home/agent/.config/pat/current-token 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        echo "username=x-access-token"
        echo "password=$TOKEN"
    fi
fi
