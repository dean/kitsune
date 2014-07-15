#!/bin/bash
cd /home/vagrant/kitsune/vendor/packages
for f in *; do
    tar -zcvf "$f.tar.gz" "${f}"
done
for f in *.tar.gz; do
    pip install "${f}" || true
done
rm *.tar.gz
