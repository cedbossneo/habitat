#!/bin/bash
#
# # License and Copyright
#
# Copyright: Copyright (c) 2016 Chef Software, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# sadly, this is NOT a banner of a cat
cat banner

# load in common test env vars
HAB=/bin/hab

# TODO
# TODO
# TODO
# TODO
# TODO
# TODO
# CHANGE PACKAGES FROM METADAVE TO CORE
#   last minute tweaks to net-tools
# TODO
# TODO
# TODO
# TODO
# TODO
# TODO


export INSPEC_PACKAGE=metadave/inspec
export RUBY_PACKAGE=core/ruby
export RUBY_VERSION="2.3.0"
export BUNDLER_PACKAGE=core/bundler

install_package() {
    pkg_to_install=$1
    description=$2

    echo "» Installing ${description}"
    ${HAB} pkg install ${pkg_to_install} >> ./logs/pkg_install.log 2>&1
    echo "★ Installed ${description}"
}

mkdir -p ./logs
echo "Installing Habitat testing packages..."

install_package ${INSPEC_PACKAGE} "Chef Inspec"
install_package ${BUNDLER_PACKAGE} "Bundler"


export INSPEC_BUNDLE="$(hab pkg path $INSPEC_PACKAGE)/bundle"
export GEM_HOME="${INSPEC_BUNDLE}/ruby/${RUBY_VERSION}"
export GEM_PATH="$(hab pkg path ${RUBY_PACKAGE})/lib/ruby/gems/${RUBY_VERSION}:$(hab pkg path ${BUNDLER_PACKAGE}):${GEM_HOME}"
export LD_LIBRARY_PATH="$(hab pkg path core/gcc-libs)/lib)"

INSPEC="${HAB} pkg exec ${INSPEC_PACKAGE} inspec"
RSPEC="${HAB} pkg exec ${INSPEC_PACKAGE} rspec"

INSPEC_BINS=(coderay htmldiff inspec pry rwinrm thor erubis httpclient ldiff rspec rwinrmcp)
RUBY_BINS=(erb irb rdoc ruby gem rake ri update_rubygems)
BUNDLER_BINS=(bundler)

# This is required for rspec to pickup extra options via Inspec
SPEC_OPTS="--color --require spec_helper --format documentation"
export SPEC_OPTS


running_sups=$(ps -ef | grep hab-sup | grep -v grep | wc -l)
if [ $running_sups -gt 0 ]; then
    echo "There are running Habitat supervisors, cannot continue testing"
    exit 1
fi

echo "» Running tests"
test_start=$(date)
echo "☛ ${test_start}"
# Check to see if we have a clean testing environment
${INSPEC} exec ./hab_inspec/controls/clean_env.rb

# Check to see if the basic build/install/run functionality works
${RSPEC} ./spec/basic.rb

# Test the rest of the specs
# TODO

test_finish=$(date)
echo "☛ ${test_finish}"
echo "★ Finished"
