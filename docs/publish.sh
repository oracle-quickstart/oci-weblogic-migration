#!/bin/bash
# Copyright (c) 2024 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
# This script uses Hugo to generate the site for the project documentation for archived versions.
set -o errexit
set -o pipefail

script="${BASH_SOURCE[0]}"

function usage {
  echo "usage: ${script} [-o <directory>] [-h]"
  echo "  -o Output directory (optional) "
  echo "      (default: \${WORKSPACE}/docs, if \${WORKSPACE} defined, else /tmp/oci-weblogic-migration) "
  echo "  -h Help"
  exit $1
}

if [[ -z "${WORKSPACE}" ]]; then
  outdir="/tmp/oci-weblogic-migration"
else
  outdir="${WORKSPACE}/docs"
fi

while getopts "o:h" opt; do
  case $opt in
    o) outdir="${OPTARG}"
    ;;
    h) usage 0
    ;;
    *) usage 1
    ;;
  esac
done

if [ -d "${outdir}" ]; then
  rm -Rf "${outdir:?}/*"
else
  mkdir -m777 -p "${outdir}"
fi

echo "Building documentation for current version and for selected archived versions..."
hugo -s 1.0 -d "${outdir}" -b https://github.com/oracle-quickstart/oci-weblogic-migration

echo "Successfully generated documentation in ${outdir}..."




