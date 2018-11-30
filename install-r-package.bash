#!/bin/bash

# Copyright 2018, Laurence Alexander Hurst

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# See the file LICENCE in the original source code repository for the
# full licence.

# Exit on error
set -e

# Should probably use getopts to test for -h and --help
if [ -z "$1" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]
then
	cat - <<EOF
Usage:
	$0 [-h | --help] package [package...]

	-h, --help: display this message and exit immediately.
	package: package to install (as many as you can fit on a command line can be given at once)

EOF
	exit 0
fi

if ! which R &>/dev/null
then
	echo "No 'R' found in the path.  Aborting." >&2
	exit 1
fi

echo "Detecting R platform and version..."

r_platform=$( R --slave -e 'cat(R.version$platform)' )
r_short_version=$( R --slave -e 'minor_sep_loc <- regexpr(".", R.version$minor, fixed=TRUE); cat(R.version$major, ".", substr(R.version$minor, 1, minor_sep_loc-1), sep="")' )

# Sanity check
if [ -z "$r_platform" ] || [ -z "$r_short_version" ] || echo "$r_platform" | grep -q ' ' || echo "$r_short_version" | grep -q ' '
then
	echo "Something went wrong - failed to detect sane (non-empty and non-space-containing) platform and version" >&2
	echo "platform: $r_platform" >&2
	echo "version: $r_short_version" >&2
	exit 1
fi

echo "Detected R platform $r_platform and version $r_short_version"

r_lib_loc="$HOME/R/$r_platform-library/$r_short_version"
echo -n "Checking library location exists..."
if [ -d $r_lib_loc ]
then
	echo "OK"
else
	echo "not found - creating $r_lib_loc"
	mkdir -p $r_lib_loc
fi

echo -n "Sanity checking libraries to install..."
# Ensure library names are valid and build a list to install -- since spaces are invalid in libaray names we can shove the valid ones into a single space-sperated manvariable
libs=""
errors=""
while [ "$1" != "" ]
do
	lib=$1
	# From: https://www.rdocumentation.org/packages/base/versions/3.5.1/topics/make.names :
	# "A syntactically valid name consists of letters, numbers and the dot or underline characters and starts with a letter or the dot not followed by a number. Names such as ".2way" are not valid, and neither are the reserved words."
	if echo $lib | grep -q -i '^[a-z\.][a-z\._][a-z\._0-9]*$'
	then
		if [ -z "$libs" ]
		then
			libs=$lib
		else
			libs="$libs $lib"
		fi
	else
		errors="$errors!!! Invalid library name: $lib\n"
	fi
	shift
done

if [ -z "$errors" ]
then
	echo "OK"
else
	echo "$( echo -e -n "$errors" | wc -l ) invalid package names detected. Aborting."
	echo -e -n "$errors" >&2
	exit 1
fi

echo "Installing: $libs"
echo -n $libs | xargs -d ' ' R --slave -e "install.packages(commandArgs(trailingOnly=TRUE), lib=\"$r_lib_loc\", repos=\"https://cran.uk.r-project.org\")" --args
