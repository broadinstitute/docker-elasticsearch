#!/bin/bash
# set -ex
set -x

# build script to build elasticsearch docker images

# TODO
#  - improve error detection

# Initialize vars
JVM_VERS=""
ES_VERS=""
config_file="build-list.cfg"
config_ok=0

# flag to determine if new docker image should be built
build_docker=0

# set flags
FORCE_BUILD=${FORCE_BUILD:-0}

# DOCKER REPO
ES_DOCKER_REPO="docker.elastic.co/elasticsearch/"

# Generic error outputting function
errorout() {
   if [ $1 -ne 0 ];
        then
        echo "${2}"
        exit $1
    fi
}

# simple functions to parse space separated strings
first() { echo $1; }
rest() { shift; echo $*; }

# check if config exists and has entries

if [ -f "${config_file}" ]
then
  # check if any valid entries in config file
  # valid entries have a valid alphanumeric valut in first column
  if  egrep -q "^[a-zA-Z0-9]+" ${config_file}
  then
     config_ok=1
  else
     errorout 1 "No valid entries in config file: ${config_file}"
  fi 
else
   errorout 1 "Missing build list config file: ${config_file}"
fi

# if config does not exist or has no entries to build see if
#  environment ES_VERSION ES_PLUGINS have values

# NOTE: elasticsearch only keeps the newest minor version tag.  Older
# minor version tags are deleted when a newer minor version is released

# can be specific or just a major version number.  As long as there 
# exists a docker tag for the string you enter
# ES_VERSIONS="2.4"

if [ "${FORCE_BUILD}" -ne 0 ]
then
   echo "FORCING BUILD of all versions"
fi

egrep "^[a-zA-Z0-9]+" ${config_file} | while read line
do
  # decode config line
  # first word is version string
  version=`first $line`
  # the rest (if there is anymore are space separated plugins)
  plugins=`rest $line`
  # default version option
  vers_opt="-version"

  # TODO maybe make config file more forgiving
  #  - support colon separated plugins,
  #  - supprot common separated plugins
  #  - support multiple separators common, colon, space

  # get major version number since each major has significant chnages
  # that impact build.
  ver_maj=$(echo $version | cut -d '.' -f1)

  # elasticsearch changed their docker repo from docker hub to their own
  #  for versions 5.x and newer.  version less than 5 use docker hub
  case ${ver_maj} in
    "1") # docker hub and -v
          DOCKER_REPO=""
          vers_opt="-v"
        ;;
    "2") # use docker hub
          DOCKER_REPO=""
        ;;
     *) DOCKER_REPO=${ES_DOCKER_REPO}
        ;;
  esac

  # ensure Dockerfile does not exist
  rm -f Dockerfile

  # initialize flag for this version based on FORCE_BUILD value
  build_docker=${FORCE_BUILD}

  # Pull version from upstream repo
  docker pull ${DOCKER_REPO}elasticsearch:${version}
  retcode=$?

  # TODO should check exit code and output error messages and exit if failed
  #  should error just fail this loop iteration and continue to next version

  # inspect docker image
  # inspect=`docker inspect ${DOCKER_REPO}elasticsearch:${version}`

  # set VERSION vars from image
  #  eval `echo "$inspect" | egrep VERSION= | sed -e 's/"//g' -e 's/,//g' | awk ' { print $1 } '`
  # turn output of version into variables that could be eval'ed
eval `docker run --rm ${DOCKER_REPO}elasticsearch:$version elasticsearch ${vers_opt} | tr ',' '\n' | tr -d ' ' | sed -e 's;:;=;'`
# eval `docker run --rm docker.elastic.co/elasticsearch/elasticsearch:5.2.2 elasticsearch -version | tr ',' '\n' | tr -d ' ' | sed -e 's;:;=;'`

  # TODO if can not extract upstream vars should error out
  #  OR should run the container and "ask" elasticsearch for version 

  # save import vars
  UPSTREAM_JVM="${JVM}"
  UPSTREAM_ES="${Version}"

  # Pull latest version built for this specific version of ES in broad repo
  docker pull broadinstitute/elasticsearch:${version}_latest
  retcode=$?

  # TODO can use Rest API for docker to check to see if latest tag exists

  # if tag does not exist set build to true
  if [ "${retcode}" -ne 0 ]
  then
     build_docker=1
  else
   
     # inspect image
     # inspect=`docker inspect broadinstitute/elasticsearch:${version}_latest`

     # set VERSION vars from image
     # eval `echo "$inspect" | egrep VERSION= | sed -e 's/"//g' -e 's/,//g' | awk ' { print $1 } '`
     eval `docker run --rm broadinstitute/elasticsearch:${version}_latest elasticsearch ${vers_opt} | tr ',' '\n' | tr -d ' ' | sed -e 's;:;=;'`

     # compare latest JVM and ES versions to upstream
     if [ "${UPSTREAM_JVM}" != "${JVM}" -o "${UPSTREAM_ES}" != "${Version}" ]
     then
          # if different set build_docker to 1
          build_docker=1
     fi
  fi

  if [ "${build_docker}" -eq 0 ]
  then
      echo "Skipping build of ${UPSTREAM_ES} - not necessary"
      continue
  fi

  echo "Building elasticsearch version: ${UPSTREAM_ES}"

  # Construct Dockerfile for build

  # start with upstream image
  echo "FROM ${DOCKER_REPO}elasticsearch:${UPSTREAM_ES}" > Dockerfile

  # add all plugins
  if [ "${ver_maj}" -eq "1" ]
  then
     # hack to install migration plugin
      echo "RUN /usr/share/elasticsearch/bin/plugin -i migration -u https://github.com/elastic/elasticsearch-migration/releases/download/v1.19/elasticsearch-migration-1.19.zip" >> Dockerfile
  else   
      for plugin in ${plugins}
      do
         case ${ver_maj} in
         "2") # 2.x plugin insall
             echo "RUN /usr/share/elasticsearch/bin/plugin install --batch ${plugin}" >> Dockerfile
            ;;
         *) # assume all newer uses the following command
             echo "RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch ${plugin}" >> Dockerfile
            ;;
          esac
      done
  fi

  # Add labels for certain information
  echo "LABEL JAVA_VERSION=${UPSTREAM_JVM}" >> Dockerfile
  echo "LABEL ELASTICSEARCH_VERSION=${UPSTREAM_ES}" >> Dockerfile
  echo "LABEL GIT_BRANCH=${GIT_BRANCH}" >> Dockerfile
  echo "LABEL GIT_COMMIT=${GIT_COMMIT}" >> Dockerfile
  echo "LABEL BUILD_URL=${BUILD_URL}" >> Dockerfile

  # go ahead and put Dockerfile into image so you can see what it contained
  echo "ADD Dockerfile /" >> Dockerfile

  # run docker build
  docker build -t broadinstitute/elasticsearch:${UPSTREAM_ES}_${BUILD_NUMBER} .
  retcode=$?
  errorout $retcode "ERROR: Build failed!"

  # if successful tag build as latest

  echo "tagging build as latest"
  docker tag broadinstitute/elasticsearch:${UPSTREAM_ES}_${BUILD_NUMBER} broadinstitute/elasticsearch:${UPSTREAM_ES}_latest 
  retcode=$?
  errorout $retcode "Build successful but could not tag it as latest"

  echo "Pushing images to dockerhub"
  docker push broadinstitute/elasticsearch:${UPSTREAM_ES}_${BUILD_NUMBER} 
  retcode=$?
  errorout $retcode "Pushing new image to docker hub"

  docker push broadinstitute/elasticsearch:${UPSTREAM_ES}_latest
  retcode=$?
  errorout $retcode "Pushing latest tag image to docker hub"

  # clean up all built and pulled images

  cleancode=0
  echo "Cleaning up pulled and built images"
  docker rmi broadinstitute/elasticsearch:${UPSTREAM_ES}_${BUILD_NUMBER}
  retcode=$?
  cleancode=$(($cleancode + $retcode))
  docker rmi broadinstitute/elasticsearch:${UPSTREAM_ES}_latest
  retcode=$?
  cleancode=$(($cleancode + $retcode))
  docker rmi ${DOCKER_REPO}elasticsearch:${version}
  retcode=$?
  cleancode=$(($cleancode + $retcode))
  errorout $cleancode "Some images were not able to be cleaned up"

done


