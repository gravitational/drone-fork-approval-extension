#!/bin/sh
#
# Copyright 2021 Gravitational, Inc.
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
#
# git describe doesn't follow semver by default -- this script adjusts

increment_patch() {
    # increment_patch returns x.y.(z+1) given valid x.y.z semver.
    major=$(echo $1 | cut -d'.' -f1)
    minor=$(echo $1 | cut -d'.' -f2)
    patch=$(echo $1 | cut -d'.' -f3)
    patch=$((patch + 1))
    echo "${major}.${minor}.${patch}"
}


SHORT_TAG=`git describe --abbrev=0`
LONG_TAG=`git describe`
COMMIT_WITH_LAST_TAG=`git show-ref --dereference ${SHORT_TAG}`
COMMITS_SINCE_LAST_TAG=`git rev-list  ${COMMIT_WITH_LAST_TAG}..HEAD --count`
BUILD_METADATA=`git rev-parse --short=8 HEAD`
DIRTY_AFFIX=$(git diff --quiet || echo '-dirty')

# strip leading v from git tag, see:
#   https://github.com/golang/go/issues/32945
#   https://semver.org/#is-v123-a-semantic-version
if echo "$SHORT_TAG" | grep -Eq '^v'; then
    SEMVER_TAG=$(echo "$SHORT_TAG" | cut -c2-)
else
    SEMVER_TAG="${SHORT_TAG}"
fi

if [ -z "$SEMVER_TAG" ]; then # no git tags found, cannot determine version
    exit 1
fi

if [ "$LONG_TAG" = "$SHORT_TAG" ] ; then  # the current commit is tagged as a release
    echo "${SEMVER_TAG}${DIRTY_AFFIX}"
else
    SEMVER_TAG=$(increment_patch ${SEMVER_TAG})
    echo "$SEMVER_TAG-dev.${COMMITS_SINCE_LAST_TAG}+${BUILD_METADATA}${DIRTY_AFFIX}"
fi
