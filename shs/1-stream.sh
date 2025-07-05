#!/bin/bash
ffmpeg -re -i "rtmp://127.0.0.1:1935/onlinestage/test" -c copy -f flv "rtmp://live.restream.io/live/re_5329820_663a8fad808d66954a60" -ignore_unknown -shortest
