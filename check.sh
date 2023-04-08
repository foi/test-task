#!/usr/bin/env bash

PAYLOAD_PATH=$1
SERVER=$2

function show_help {
    echo "Prerequisites:"
    echo "* Provide PAYLOAD_PATH as first argument"
    echo "* Provide SERVER as second argument"
    echo "Example: ./check.sh ./spec/data/1.json http://localhost:8080"
}

if [ "${PAYLOAD_PATH}" == "" ]; then
    echo "Provide script as first parameter to script!"
    show_help
    exit 3
fi

if [ "${SERVER}" == "" ]; then
    echo "Provide SERVER address as second parameter."
    show_help
    exit 3
fi

curl -X POST -H "Content-Type: application/json" -d @$PAYLOAD_PATH $SERVER
