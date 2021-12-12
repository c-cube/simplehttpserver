#!/usr/bin/env bash
echo sse_server 1>&2
PORT=8082

./sse_server.exe -p $PORT &
PID=$!

sleep 0.1
./sse_client.exe -p $PORT --alarm=1 /count | tr -d '\r' || true

kill $PID
echo "success"
