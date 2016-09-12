#!/bin/sh

# turn on verbose
# set -x

# This script builds an environment properties file that will be used
# by jenkins for build and deploys.

# This script creates an environment vars file that will be sourced 
# at very beginning of the "build" steps in jenkins.  

# file to store vars in
# Do not change this name unless you update the jenkins job
ENVVARS="env-vars.txt"

# initialize file just in case
cp /dev/null ${ENVVARS}

# Initialize flags to zero (do nothing) if not already set
FORCE_BUILD=${FORCE_BUILD:-0}

# get last part of branch name
BRANCH_TAG=`echo ${GIT_BRANCH} | awk -F '/' '{ print $NF}'`

changed_list=`git show --name-only`

# check if cromwell submodule was updated
if  echo "$changed_list" | egrep -q "^build-list.cfg$"
then
    # Set force build flag since build list was updated
    FORCE_BUILD="1"
fi

echo "FORCE_BUILD=${FORCE_BUILD}" >> ${ENVVARS}

# cat var file to standard out so settings show up in jenkins log

echo
echo "Environment variable file contains:"
cat ${ENVVARS}
echo
