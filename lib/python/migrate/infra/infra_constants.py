"""
Copyright (c) 2017, 2025 Oracle and/or its affiliates.
Licensed under the Universal Permissive License v1.0 as shown at https://oss.oracle.com/licenses/upl.

"""
import os


EMPTY = ""
EMPTY_ARRAY= []
FAIL = 1
WARNING = -1
SUCCESS    = 0

TRUE = "TRUE"
YES  = "YES"
NO   = "NO"

EXIT_ZERO = 0
EXIT_ONE  = 1
DETAILS_KEY = "DETAILS"
HOSTING_SERVER_KEY = "Hostname"
HOSTING_SERVER_KERNEL = "Kernel"
HOSTING_SERVER_ARCH = "Arch"
HOSTING_SERVER_OS = "OS"
HOSTING_SERVER_OS_VERSION = "OS_VERSION"
HOSTING_SERVER_OS_RELEASE = "OS_RELEASE"
#
OWNER ="Owner"
USER = "User"
GROUP = "Group"
USER_ID = "uid"
USERNAME = "uname"
GROUP_NAME= "gname"
GROUP_ID= "gid"
COMMA_SEPARATOR =","
COLON_SEPARATOR = ":"
DOMAIN_HOME_DIR = "DomainPath"
ADMIN_CONSOLE_PORT = "AdminConsolePort"
WL_HOME_DIR = "WLPath"
JAVA_DIR = "JavaPath"
CANONICAL_JAVA_DIR = "CanonicalJavaPath"
JAVA_PROC = "JavaProcs"
NM_VM="NodeManager"
WLS_SERVER_VM="WeblogicServer"
NM_HOME_DIR = "NmPath"
EXTRA_HOME_DIR = "ExtraPath"
ORACLE_HOME_DIR = "OraclePath"
WLS_MANAGED_SERVER_PROCESS_KEY = "weblogic.Server"
NM_JAVA_PROCESS_KEY = "weblogic.NodeManager"
JAVA_PROCESS_KEY = "/bin/java"
NM_TYPE_JAVA="nm_java"
CMD_TIME_OUT=60000
DASH_STRING_SEPARATOR="-"
DOT_STRING_SEPARATOR="."
JAVA_FLAG_D_SEPARATOR="-D"

FILESYSTEM="ExtraOSPaths"
FILESYSTEM_TYPE="type"

class FS_TYPE:
    SHARED = "shared"
    VOLUME = "volume"


class Owner:
    def __init__(self, user_id, username, group_id, group_name, home):
        self.user_id = user_id
        self.username = username
        self.group_id = group_id
        self.group_name = group_name
        self.home = home
