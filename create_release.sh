#!/bin/bash -e

if [ "$GITHUB_ACCESS_TOKEN" == "" ]; then
    echo "Missing GITHUB_ACCESS_TOKEN environment variable."
    exit -1
fi

if [ "$1" == "" ]; then
    echo "missing release name (e.g. v1.0.0-p0)"
    exit -1
fi

current_dir=$(pwd)
script_dir=$(dirname "$0")
repo=dawn.cmake
release=$1
release_url="https://api.github.com/repos/${repo}/releases"

pushd ${script_dir}
tar czf ${current_dir}/source.tar.gz --exclude="**/.git*" --exclude="**/CMakeLists.txt.user" --exclude="**/*.pyc" --exclude="source.tar.gz" *
sha1=$(sha1sum ${current_dir}/source.tar.gz)
sha1="${sha1%\ *}"
popd

body="{\"tag_name\": \"${release}\", \"name\": \"${release}\", \"body\":\"If you are using Hunter, add the following to your \`cmake/Hunter/config.cmake\` file:\r\n\r\n\`\`\`\r\nhunter_config(dawn\r\n\tVERSION ${release}\r\n\tURL https://github.com/mchiasson/dawn.cmake/releases/download/${release}/source.tar.gz\r\n\tSHA1 ${sha1}\r\n\tCMAKE_ARGS\r\n\t\tDAWN_BUILD_SAMPLES=OFF\r\n)\r\n\`\`\`\"}"
upload_url=$(curl -s -X POST -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -d "${body}" "https://api.github.com/repos/${USER}/${repo}/releases" | jq -r '.upload_url')
upload_url="${upload_url%\{*}"

echo "uploading asset to release to url : ${upload_url}"

curl -s -X POST -H "Authorization: token ${GITHUB_ACCESS_TOKEN}" -H "Content-Type: application/gzip" --data-binary @${current_dir}/source.tar.gz "${upload_url}?name=source.tar.gz"
