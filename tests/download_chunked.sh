#!/usr/bin/env sh

SERVER=$1
PORT=$2

"$SERVER" . -p $PORT &
PID=$!

sleep 0.1

echo === download1 $SERVER $PORT 1>&2
curl -N "http://localhost:${PORT}/foo_50" -o data21 \
  -H 'Tranfer-encoding: chunked' --max-time 10

echo === download2 $SERVER $PORT 1>&2
curl -N "http://localhost:${PORT}/foo_50" -o data22 \
  -H 'Tranfer-encoding: chunked' --max-time 10

echo === download3 $SERVER $PORT 1>&2
curl -N "http://localhost:${PORT}/foo_50" -o data23 \
  -H 'Tranfer-encoding: chunked' --max-time 10

kill $PID
wc data21 data22 data23
