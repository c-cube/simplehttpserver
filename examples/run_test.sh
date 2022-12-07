#!/usr/bin/env bash

PORT=$1

./sse_server.exe -p $PORT &
PID=$!

sleep 0.1
./sse_client.exe -p $PORT --alarm=1 /count | tr -d '\r' || true

kill $PID
echo "success"
