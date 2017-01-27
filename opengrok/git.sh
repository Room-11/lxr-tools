#!/bin/bash

# Config
ROOM11_SOURCES_BASE_DIR=/srv/OpenGrokSources/
ROOM11_REAL_GIT_LOCATION=/usr/bin/git.real

# Allow overriding with this env var
if [ "$ROOM11_REAL_GIT" == "1" ]; then
    $ROOM11_REAL_GIT_LOCATION $*
    exit $?
fi

# If we are not under the sources root, go straight to real git
workingDir=$(pwd)
if [ ${workingDir:0:${#ROOM11_SOURCES_BASE_DIR}} != $ROOM11_SOURCES_BASE_DIR ]; then
    $ROOM11_REAL_GIT_LOCATION $*
    exit $?
fi

# If we are not exactly 1 level under sources root, go straight to real git
vendor=${workingDir:${#ROOM11_SOURCES_BASE_DIR}}
if [[ "$vendor" == *\/* ]]; then
    $ROOM11_REAL_GIT_LOCATION $*
    exit $?
fi

# Assume the last argument is a path spec
for last; do true; done

project="$( cut -d '/' -f 1 <<< "$last" )"
target="$( cut -d '/' -f 2- <<< "$last" )"

if [ $project == $target ]; then
    target=""
fi

# Check the project that we have detected is a directory that exists
if [ ! -d "$project" ]; then
    $ROOM11_REAL_GIT_LOCATION $*
    exit $?
fi

# Perform actual black magic to remove the last argument
# http://stackoverflow.com/a/26163980/889949
set -- "${@:1:$(($#-1))}"

cd $project
$ROOM11_REAL_GIT_LOCATION $* $target
