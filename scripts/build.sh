#!/bin/bash

npm run build_dev

# Stage Package for Deployment
rm -rf deploy/*
mkdir -p deploy/assets/
cp -rf assets/icons deploy/assets/
cp -rf build deploy/
cp -rf libs deploy/
mkdir -p deploy/website/assets/envmaps
cp -rf website/assets/envmaps/default deploy/website/assets/envmaps/
cp website/assets/envmaps/default.jpg deploy/website/assets/envmaps/
cp website/assets/envmaps/noimage.jpg deploy/website/assets/envmaps/
cp -rf website/assets/images deploy/website/assets/
cp -rf source/website/css deploy/website/
cp website/embed.html deploy/website/
cp website/index_min.html deploy/website/
cp website/viewer.html deploy/website/

# Include Sample Models
mkdir deploy/website/assets/models
# cp website/assets/models/car.glb deploy/website/assets/models/
