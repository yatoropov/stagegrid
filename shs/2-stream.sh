#!/bin/bash
ffmpeg -re -i "rtmp://127.0.0.1:1935/onlinestage/test" -c copy -f flv "rtmp://a.rtmp.youtube.com/live2/ws0m-pv4a-b9hx-6hc6-3tmf" -ignore_unknown -shortest
