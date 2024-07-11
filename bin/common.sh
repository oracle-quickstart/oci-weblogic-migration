#!/bin/sh
# *****************************************************************************
# shared.sh
#
# Copyright (c) 2020, 2023, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
#
#     NAME
#       shared.cmd - shared script for use with WebLogic Deploy Tooling.
#
#     DESCRIPTION
#       This script contains shared functions for use with WDT scripts.
#
scriptName=$(basename "$0")
scriptPath=$(dirname "$0")
toolHome=$(builtin cd "$scriptPath/.."; pwd)
echo $toolHome

. "$toolHome/deps/wdt/bin/shared.sh"

variableSetup() {

    # set up variables for WLST or Jython execution

    # set the WLSDEPLOY_HOME variable, ignoring any value that was already set

    SCRIPT_DIR="`dirname "$0"`"
    BASEDIR="`cd "${SCRIPT_DIR}" && pwd `"
    WLSDEPLOY_HOME="`cd "${BASEDIR}/../deps/wdt" ; pwd`"
    WLSMIGRATION_HOME="`cd "${BASEDIR}/../deps/wmt" ; pwd`"
    echo "JOI variable- this is the $WLSDEPLOY_HOME"
    export WLSDEPLOY_HOME


    # set up logger configuration, see WLSDeployLoggingConfig.java

    LOG_CONFIG_CLASS=oracle.weblogic.deploy.logging.WLSDeployLoggingConfig

    if [ -z "${WLSDEPLOY_LOG_PROPERTIES}" ]; then
        WLSDEPLOY_LOG_PROPERTIES="${WLSDEPLOY_HOME}/etc/logging.properties"; export WLSDEPLOY_LOG_PROPERTIES
    fi

    if [ -z "${WLSDEPLOY_LOG_DIRECTORY}" ]; then
        WLSDEPLOY_LOG_DIRECTORY="${WLSDEPLOY_HOME}/logs"; export WLSDEPLOY_LOG_DIRECTORY
    fi
}

runWlst() {
    # run a WLST script.
    wlstScript=$1
    # save first argument in wlstScript, and discard argument from $@
    shift

    variableSetup

    # set WLST variable to the WLST executable.
    # set CLASSPATH and WLST_CLASSPATH to include the WDT core JAR file.
    # if the WLST_PATH_DIR was set, verify and use that value.

    if [ -n "${WLST_PATH_DIR}" ]; then
        if [ ! -d "${WLST_PATH_DIR}" ]; then
            echo "Specified -wlst_path directory does not exist: ${WLST_PATH_DIR}" >&2
            exit 98
        fi
        WLST="${WLST_PATH_DIR}/common/bin/wlst.sh"
        if [ ! -x "${WLST}" ]; then
            echo "WLST executable ${WLST} not found under -wlst_path directory: ${WLST_PATH_DIR}" >&2
            exit 98
        fi
        CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export CLASSPATH
        if [ ! -z "${WLST_EXT_CLASSPATH}" ]; then
          WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLST_EXT_CLASSPATH}"; export WLST_EXT_CLASSPATH
        else
          WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export WLST_EXT_CLASSPATH
        fi
    else
        # if WLST_PATH_DIR was not set, find the WLST executable in one of the known ORACLE_HOME locations.

        WLST=""
        if [ -x "${ORACLE_HOME}/oracle_common/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/oracle_common/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export CLASSPATH
          if [ ! -z "${WLST_EXT_CLASSPATH}" ]; then
            WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar:${WLST_EXT_CLASSPATH}"
            export WLST_EXT_CLASSPATH
          else
            WLST_EXT_CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export WLST_EXT_CLASSPATH
          fi
        elif [ -x "${ORACLE_HOME}/wlserver_10.3/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/wlserver_10.3/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export CLASSPATH
        elif [ -x "${ORACLE_HOME}/wlserver_12.1/common/bin/wlst.sh" ]; then
            WLST="${ORACLE_HOME}/wlserver_12.1/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export CLASSPATH
        elif [ -x "${ORACLE_HOME}/wlserver/common/bin/wlst.sh" -a -f "${ORACLE_HOME}/wlserver/.product.properties" ]; then
            WLST="${ORACLE_HOME}/wlserver/common/bin/wlst.sh"
            CLASSPATH="${WLSDEPLOY_HOME}/lib/weblogic-deploy-core.jar:${WLSMIGRATION_HOME}/weblogic-migration-0.1.jar"; export CLASSPATH
        fi


        if [ -z "${WLST}" ]; then
            echo "Unable to determine WLS version in ${ORACLE_HOME} to determine WLST shell script to call" >&2
            exit 98
        fi
    fi

    WLST_PROPERTIES=-Dcom.oracle.cie.script.throwException=true
    WLST_PROPERTIES="${WLST_PROPERTIES} -Djava.util.logging.config.class=${LOG_CONFIG_CLASS}"
    WLST_PROPERTIES="${WLST_PROPERTIES} ${WLSDEPLOY_PROPERTIES}"
    export WLST_PROPERTIES

    # print the configuration, and run the script

    echo "JAVA_HOME = ${JAVA_HOME}"
    echo "WLST_EXT_CLASSPATH = ${WLST_EXT_CLASSPATH}"
    echo "CLASSPATH = ${CLASSPATH}"
    echo "WLST_PROPERTIES = ${WLST_PROPERTIES}"

#    PY_SCRIPTS_PATH="${WLSDEPLOY_HOME}/lib/python"
    PY_SCRIPTS_PATH="${toolHome}/lib/python"

    if [ -z "${OHARG_VALUE}" ] ; then
      echo "${WLST} ${PY_SCRIPTS_PATH}/$wlstScript" "$@"
      "${WLST}" "${PY_SCRIPTS_PATH}/$wlstScript" "$@"
    else
      echo "${WLST} ${PY_SCRIPTS_PATH}/$wlstScript $OHARG ${OHARG_VALUE}" "$@"
      "${WLST}" "${PY_SCRIPTS_PATH}/$wlstScript" $OHARG "${OHARG_VALUE}" "$@"
    fi

    RETURN_CODE=$?
    checkExitCode ${RETURN_CODE}
    exit ${RETURN_CODE}
}