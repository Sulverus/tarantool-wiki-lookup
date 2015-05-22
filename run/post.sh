#!/bin/bash
wget -nc -S --tries 1 --post-data "$1" 127.0.0.1:8081/load
