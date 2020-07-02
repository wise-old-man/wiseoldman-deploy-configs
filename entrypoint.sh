#!/bin/sh -l

echo "Hello $1"

echo "Test username $2"

#docker login -u ${{ secrets.DOCKER_USERNAME }} -p ${{ secrets.DOCKER_PASSWORD }}
    
#docker build . --file Dockerfile --tag wiseoldman/nginx-deploy-config:latest
#docker push wiseoldman/nginx-deploy-config:latest