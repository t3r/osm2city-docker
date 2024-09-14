# Dockerize the osm2city toolchain
This container is used by https://github.com/t3r/cloudcity
It might also be used standalone.

## Usage
Create a workspace directory with this structure
./scenery      (this should contain your terrasync scenery, Terrain, Models and Objects)
./o2c-scenery  (empty directory, will be filled by osm2city with Buildings, Trees et.al.)
./o2c-packed   (empty directory, will be filled by the packer with *.txz per 10x10 folder)
set FG_ROOT environment variable to point to your local copy of FGDATA 

    docker build -t osm2city-builder .
    docker run --rm osm2city-builder scripts/build.sh --tile 12345678
    docker run --rm osm2city-builder scripts/pack.sh 

