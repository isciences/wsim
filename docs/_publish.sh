#!/usr/bin/env bash
set -e

# Publish latest documentation to wsim.isciences.com

HTMLDIR=$(mktemp -d)
docker pull isciences/wsim:latest
id=$(docker create isciences/wsim:latest)
docker cp $id:/wsim/docs/_build/html $HTMLDIR

for pkg in wsim.distributions wsim.io wsim.lsm
do
        docker cp $id:/wsim/$pkg/docs $HTMLDIR/html/working/r_packages/$pkg
done

docker rm -v $id

rsync -rloDzvv $HTMLDIR/html/ wsim.isciences.com:/var/www/html
rm -rf $HTMLDIR
echo "Done"
