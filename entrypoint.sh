#!/bin/sh

sh "docker login -u $1 -p $2"
# docker build . --file nginx/Dockerfile --tag wiseoldman/nginx-deploy-config:latest
# docker push wiseoldman/nginx-deploy-config:latest