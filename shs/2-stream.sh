#!/bin/bash
ffmpeg -re -i "rtmp://127.0.0.1:1935/onlinestage/test" -c copy -f flv "rtmp://a.rtmp.youtube.com/live2/abhk-7rfx-2v7y-hrh2-3jcw" -ignore_unknown -shortest
