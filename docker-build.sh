#!/bin/bash

# build script to build elasticsearch docker images

# TODO
#  - improve error detection

# Initialize vars
JVM_VERS=""
ES_VERS=""
# flag to determine if new docker image should be built
build_docker=0

# set flags
FORCE_BUILD=${FORCE_BUILD:-0}

# replace with Jenkins var
buildnum="1"

# NOTE: elasticsearch only keeps the newest minor version tag.  Older
# minor version tags are deleted when a newer minor version is released

# TODO read ES versions to build from config file

# can be specific or just a major version number.  As long as there 
# exists a docker tag for the string you enter
ES_VERSIONS="2.4"

# TODO read plugins to add from config file

# List of plugins to install can be a specific version or just the
# name and script will just grab newest version.

ES_PLUGINS="royrusso/elasticsearch-HQ/v2.0.3 cloud-gce mobz/elasticsearch-head "
ES_PLUGINS="cloud-gce"

if [ "${FORCE_BUILD}" -ne 0 ]
then
   echo "FORCING BUILD of all versions"
fi

for version in "${ES_VERSIONS}"
do

  # ensure Dockerfile does not exist
  rm -f Dockerfile

  # initialize flag for this version based on FORCE_BUILD value
  build_docker=${FORCE_BUILD}

  # Pull version from upstream repo
  docker pull elasticsearch:${version}
  retcode=$?

  # TODO should check exit code and output error messages and exit if failed
  #  should error just fail this loop iteration and continue to next version

  # inspect docker image
  inspect=`docker inspect elasticsearch:${version}`

  # set VERSION vars from image
  eval `echo "$inspect" | egrep VERSION= | sed -e 's/"//g' -e 's/,//g' | awk ' { print $1 } '`

  # TODO if can not extract upstream vars should error out
  #  OR should run the container and "ask" elasticsearch for version 

  # save import vars
  UPSTREAM_JVM="${JAVA_VERSION}"
  UPSTREAM_ES="${ELASTICSEARCH_VERSION}"

  # Pull latest version built for this specific version of ES in broad repo

  # if tag does not exist set build to true

  # inspect image

  # set version vars

  # compare latest JVM and ES versions to upstream
  # if different set build_docker to 1

  if [ "${build_docker}" -eq 0 ]
  then
      echo "Skipping build of ${UPSTREAM_ES} - not necessary"
      next
  fi

  echo "Building elasticsearch version: ${UPSTREAM_ES}"

  # Construct Dockerfile for build

  # start with upstream image
  echo "FROM elasticsearch:${version}" > Dockerfile

  # add all plugins
  for plugin in "${ES_PLUGINS}"
  do
     echo "RUN /usr/share/elasticsearch/bin/plugin install --batch ${plugin}" >> Dockerfile
  done

  # Add labels for certain information
  echo "LABEL JAVA_VERSION=${JAVA_VERSION}" >> Dockerfile
  echo "LABEL ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION}" >> Dockerfile
  echo "LABEL GIT_BRANCH=${GIT_BRANCH}" >> Dockerfile
  echo "LABEL GIT_COMMIT=${GIT_COMMIT}" >> Dockerfile
  echo "LABEL BUILD_URL=${BUILD_URL}" >> Dockerfile

  # go ahead and put Dockerfile into image so you can see what it contained
  echo "ADD Dockerfile" >> Dockerfile

  # run docker build
  docker build -t broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${buildnum} .

   # TODO track error code to determine if successful build

  # if successful tag build as latest

  echo "tagging build as latest"
  # docker tag broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${BUILD_NUMBER} broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_latest 

  echo "Pushing images to dockerhub"
  # docker push -f broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${BUILD_NUMBER} 
  # docker push -f broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_latest

  # clean up all built and pulled images

  echo "Cleaning up pulled and built images"
  # docker rmi broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${BUILD_NUMBER}
  # docker rmi broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_latest
  # docker rmi elasticsearch:${version}

done


