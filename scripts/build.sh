#!/usr/bin/env bash
# File managed by pluginsync

# http://www.apache.org/licenses/LICENSE-2.0.txt
#
#
# Copyright 2016 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -u
set -o pipefail

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__proj_dir="$(dirname "$__dir")"

# shellcheck source=scripts/common.sh
. "${__dir}/common.sh"

plugin_name=${__proj_dir##*/}
build_dir="${__proj_dir}/build"
pkg_dir="${__proj_dir}/pkg"
go_build=(go build -ldflags "-w")

build_type="code"
if [ $# -gt 0 ]; then
  build_type="$1"
fi

if [ "$build_type" = "code" ]; then
  _info "project path: ${__proj_dir}"
  _info "plugin name: ${plugin_name}"

  export CGO_ENABLED=0

  # rebuild binaries:
  _debug "removing: ${build_dir:?}/*"
  rm -rf "${build_dir:?}/"*

  _info "building plugin: ${plugin_name}"
  export GOOS=linux
  export GOARCH=amd64
  mkdir -p "${build_dir}/${GOOS}/x86_64"
  "${go_build[@]}" -o "${build_dir}/${GOOS}/x86_64/${plugin_name}" . || exit 1
elif [ "$build_type" = "pkg" ]; then
  # builds a standalone package
  gem list | grep fpm >/dev/null 2>&1 || { \
	  echo "\033[1;33mfpm is not installed. See https://github.com/jordansissel/fpm\033[m"; \
	  echo "$$ gem install fpm"; \
	  exit 1; \
	}

  type rpmbuild >/dev/null 2>&1 || { \
	  echo "\033[1;33mrpmbuild is not installed. See the package for your distribution\033[m"; \
	  exit 1; \
	}

  _debug "removing: ${pkg_dir:?}/*"
  rm -rf "${pkg_dir:?}/"*

  version_num=$(tr -s [" "\\t] [" "" "]  < "${__proj_dir}/disk/disk.go" | grep "PluginVersion = " | cut -d" " -f4)
  mkdir -p pkg/tmp/opt/snap_plugins/bin
  cp -f "${build_dir}/linux/x86_64/${plugin_name}" pkg/tmp/opt/snap_plugins/bin
  (cd ${pkg_dir} && \
  fpm -s dir -C tmp -t deb \
    -n ${plugin_name} \
    -m "Papertrail <support@papertrailapp.com>" \
    -v ${version_num} \
    -d "snap-telemetry|appoptics-snaptel" \
    --license "Apache" \
    --url "https://www.papertrail.com" \
    --description "Disk plugin for the Intel snap agent" \
    --vendor "Papertrail" \
    opt/snap_plugins/bin/${plugin_name} && \
  fpm -s dir -C tmp -t rpm \
    -n ${plugin_name} \
    -m "Papertrail <support@papertrailapp.com>" \
    -v ${version_num} \
    -d "snap-telemetry|appoptics-snaptel" \
    --license "Apache" \
    --url "https://www.papertrail.com" \
    --description "Disk plugin for the Intel snap agent" \
    --vendor "Papertrail" \
    opt/snap_plugins/bin/${plugin_name})
  rm -R -f pkg/tmp

else
  echo "Must pass in a build type of either code or pkg"
  exit 1
fi
