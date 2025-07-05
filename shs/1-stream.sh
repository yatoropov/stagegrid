#!/bin/bash
ffmpeg -re -i "rtmp://127.0.0.1:1935/onlinestage/test" -c copy -f flv "rtmps://live-api-s.facebook.com:443/rtmp/FB-10223262012577642-0-Ab0ZI15rPLwPL8MTqgErJ3ix" -ignore_unknown -shortest
