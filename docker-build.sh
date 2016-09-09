#!/bin/bash
JVM_VERS=""
ES_VERS=""
buildnum="1"

proc_inspect() {

  echo ""

}

# NOTE: elasticsearch only keeps the newest minor version tag.  Older
# minor version tags are deleted when a newer minor version is released

# can be specific or just a major version number.  As long as there 
# exists a docker tag for the string you enter
ES_VERSIONS="2.4"

# List of plugins to install can be a specific version or just the
# name and script will just grab newest version.

ES_PLUGINS="royrusso/elasticsearch-HQ/v2.0.3 cloud-gce mobz/elasticsearch-head "
ES_PLUGINS="cloud-gce"

for version in "${ES_VERSIONS}"
do

  docker pull elasticsearch:${version}
  retcode=$?

  inspect=`docker inspect elasticsearch:${version}`

  eval `echo "$inspect" | egrep VERSION= | sed -e 's/"//g' -e 's/,//g' | awk ' { print $1 } '`

  echo "FROM elasticsearch:${version}" > Dockerfile
  for plugin in "${ES_PLUGINS}"
  do
     echo "RUN /usr/share/elasticsearch/bin/plugin install --batch ${plugin}" >> Dockerfile
  done

  echo "LABEL JAVA_VERSION=${JAVA_VERSION}" >> Dockerfile
  echo "LABEL ELASTICSEARCH_VERSION=${ELASTICSEARCH_VERSION}" >> Dockerfile

  # add Jenkins and GIT vars as LABELS

  # run docker build
  docker build -t broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${buildnum} .

  # docker push -f broadinstitute/elasticsearch:${ELASTICSEARCH_VERSION}_${buildnum} 

done


