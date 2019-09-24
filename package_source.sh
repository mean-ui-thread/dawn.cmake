#!/bin/bash

current_dir=$(pwd)
script_dir=$(dirname "$0")

pushd ${script_dir}
tar czvf ${current_dir}/source.tar.gz --exclude="**/.git*" --exclude="**/CMakeLists.txt.user" --exclude=**/*.pyc --exclude="**/source.tar.gz" --exclude="**/package_source.sh" *
popd
