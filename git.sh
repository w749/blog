#!/bin/bash
var=${1:-`date "+%Y-%m-%d"`}

git add .
git commit -m $var
git push -u origin master
