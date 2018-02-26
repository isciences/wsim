#!/bin/sh

DOCKERFILE=Dockerfile.$$
echo "FROM debian:stretch
COPY . /build-context
WORKDIR /build-context
CMD find .
" > ${DOCKERFILE}
TAG=`docker build -f ${DOCKERFILE} -q .`
docker run --rm -it ${TAG}
docker rmi ${TAG}
rm ${DOCKERFILE}
