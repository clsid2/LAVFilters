#!/bin/bash
# (C) 2013 see Authors.txt
#
# This file is part of MPC-HC.
#
# MPC-HC is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# MPC-HC is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

versionfile_fixed="./includes/version.h"
versionfile="./includes/version_rev.h"

# Read major, minor and patch version numbers from static version.h file
while read -r _ var value; do
  if [[ $var == LAV_VERSION_MAJOR ]]; then
    ver_fixed_major=$value
  elif [[ $var == LAV_VERSION_MINOR ]]; then
    ver_fixed_minor=$value
  elif [[ $var == LAV_VERSION_REVISION ]]; then
    ver_fixed_patch=$value
  fi
done < "$versionfile_fixed"
ver_fixed="${ver_fixed_major}.${ver_fixed_minor}.${ver_fixed_patch}"
echo "Version:   $ver_fixed"

# If we are not inside a git repo use hardcoded values
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  hash=0000000
  ver=0
  ver_additional=
  echo "Warning: Git not available or not a git repo. Using dummy values for hash and version number."
else
  # Get information about the current version
  describe=$(git describe --long `git log --grep="\[MPC-HC\] Use our own ffmpeg clone repository\." --pretty=%H`~1)
  echo "Describe:  $describe"

  # Get the abbreviated hash of the current changeset
  hash=${describe##*-g}

  # Get the number changesets since the last tag
  ver=${describe#*-}
  ver=${ver%-*}

  echo "Hash:      $hash"
  if ! git diff-index --quiet HEAD; then
    echo "Revision:  $ver (Local modifications found)"
  else
    echo "Revision:  $ver"
  fi
fi

version_info="#define LAV_VERSION_BUILD $ver"

# Update version_rev.h if it does not exist, or if version information was changed.
if [[ ! -f "$versionfile" ]] || [[ "$version_info" != "$(<"$versionfile")" ]]; then
  # Write the version information to version_rev.h
  echo "$version_info" > "$versionfile"
fi
