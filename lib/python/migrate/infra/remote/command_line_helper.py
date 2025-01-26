"""
Copyright (c) 2017, 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

Builds command based on host OS
"""


import os
import sys
# import shutil
# import io
import re
# import platform

import infra_constants


sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))
from wlsdeploy.util.ssh_command_line_helper import SSHCommandLineHelper
from wlsdeploy.util.ssh_command_line_helper import SSHUnixCommandLineHelper
from wlsdeploy.util import string_utils
from wlsdeploy.logging.platform_logger import PlatformLogger


_class_name = 'RemoteUnixCommandLineHelper'
_logger = PlatformLogger('wlsdeploy.util')

class RemoteUnixCommandLineHelper(SSHUnixCommandLineHelper):



    def __init__(self):
        """
        Constructor for non-Windows command-line helper
        """
        SSHUnixCommandLineHelper.__init__(self)

    def get_user_details(self, directory_path):
        path = self._get_directory_path(directory_path)
        command = '/usr/bin/stat'
        args= '-c "%%u:%%U,%%g:%%G" %s' % path
        # command = 'stat -c "%%u,username:%%U,group_id:%%g,group:%%G" %s' %path
        return command, args


    def is_fs_shared(self, directory_path):
        path = self._get_directory_path(directory_path)
        command = '/usr/bin/df'
        args='%s -t nfs' % path
        return command,args

    # return 0 if it is nfs / 1 no nfs or does not exist
    def get_fs_nfs_cmd(self, directory_path):
        path = self._get_directory_path(directory_path)
        command = '/usr/bin/df'
        args='%s -t nfs' % path
        return command,args

    def construct_command_with_log(self, _cmd, _log):
        cmd = _cmd
        logFileName = _log
        if logFileName is not None and logFileName != "":
            logFileName = " >>" + logFileName + " 2>&1"
            cmd = cmd + "  " + logFileName
        return cmd

    def list_process(self, process_key):
        # command = 'ps aux | grep %s | grep -v grep' % process_key
        command = '/usr/bin/ps'
        args = 'x -o command |grep %s |grep -v grep' % process_key
        # args = 'x -o command |grep -E "(%s.*%s)" |grep -v grep' % process_key
        # args = 'x -o command |grep -E "({0}.*{1})" |grep -v grep' % process_key
        parser = self.list_processes_parser
        return command,args,parser

    def list_processes_parser(self,ps_output):
        ps_info = list()
        # lines = ps_output.splitlines()
        # lines =
        # lines = self.get_single_result(ps_output).split(infra_constants.DASH_STRING_SEPARATOR)
        if ps_output is not None and len(ps_output) == 1:
                return ps_output[0]
        else:
            # Commented to do split in command_helper
            for line in ps_output:
                if not string_utils.is_empty(line):
                    ps_info.append(line)
            return ps_info


    def get_ipv4(self):
        command = "/usr/sbin/ip"
        args = "-4 addr | grep -oP "+"'(?<=inet\s)\d+(\.\d+){3}'"
        return command,args

    def get_ifconfigv4(self):
        command = "/usr/sbin/ifconfig"
        args= "| grep -oP "+"'(?<=inet\s)\d+(\.\d+){3}'"
        return command,args

    def get_hostname(self):
        # remote_host = self.getRemoteHostname()
        command = "/usr/bin/hostname"
        args = "-f | cat"
        return command, args

    def stat_to_dict(self, filestat):
        # if type(filestat) == os.stat_result:
        returnval = {}
        for stat in dir(filestat):
            if stat[:3] == 'st_':
                returnval[stat] = getattr(filestat, stat)
        return returnval
        # else:
        #     raise ValueError(f'argument must be os.stat_result not {type(filestat)}')
    def statdict(self, filepath):
        return self.stat_to_dict(os.stat(filepath))

    def get_single_result(self,result):
        # if len(result) > 0 :
        return result[0]
        # return

    def is_unicode(self,object):
        return isinstance(object,unicode)

    def unicode_to_string(self,object):
        if isinstance(object,unicode) and not object:
             return str(object)
        return object

    def get_validate_command_exist(self, cmd):
        command = '/usr/bin/which'
        args='%s' % cmd
        return command,args

    def get_host_architecture(self):
        command = '/usr/bin/arch'
        args =''
        return command,args

    def get_os_version(self):
        command = '/usr/bin/arch'
        args = ''
        return command,args

    def get_system_information(self):
        # command = 'uname -sr'
        # command = "python -c \'import platform; uname_info={\"sysname\": platform.system(),\"nodename\": platform.node(),\"release\": platform.release(),\"version\": platform.version(),\"machine\": platform.machine()};print(uname_info)\' "
        command = "/usr/bin/python"
        args = "-c \'import platform; print(platform.platform())\' "
        parser = self.system_information_parser
        return command, args, parser

    def system_information_parser(self,uname_output):
        # Parse the output into a dictionary
        _method_name="system_information_parser"
        _logger.entering(uname_output,class_name=_class_name, method_name=_method_name)
        uname_info = {}
        # lines = uname_output.splitlines()
        lines = self.get_single_result(uname_output).split(infra_constants.DASH_STRING_SEPARATOR)
        if lines:
            # Assuming it is an Oracle Release/ Redhat release
            if len(lines) == 7:
                uname_info[infra_constants.HOSTING_SERVER_KERNEL] = lines[2].strip()  # Example: 100.96.32.el8uek.x86_64
                uname_info[infra_constants.HOSTING_SERVER_ARCH] = lines[3]  # Example: x86_64
                uname_info[infra_constants.HOSTING_SERVER_OS] = lines[5] # Example: Oracle
                os_spec=lines[6].split(infra_constants.DOT_STRING_SEPARATOR)
                uname_info[infra_constants.HOSTING_SERVER_OS_VERSION] = os_spec[0]  # Example: 8
                uname_info[infra_constants.HOSTING_SERVER_OS_RELEASE] = os_spec[1]  # Example: 7
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=uname_info)
        return uname_info


    def get_directory_regexp(self):
        # pattern = r"^(\/|[a-zA-Z0-9_-]+(\/[a-zA-Z0-9_-]+)*)$"
        pattern = r"[/\\](?:(?!\.\s+)\S)+(\.)?"
        return pattern

    def get_java_exec(self):
        command="bin/java"
        args=""
        return command,args

    def get_compress_commands(self, file_name,folder):
        _method_name="get_compress_commands"
        _logger.entering(file_name,folder,class_name=_class_name, method_name=_method_name)
        filters_os="--exclude='.pid' --exclude='.state' --exclude='.core' --exclude='diag/ofm/*/*/lck/*.lck'"
        filters_logs="--exclude='servers/*/logs/*.*' --exclude='*.log*[0-9]' --exclude='*.log' --exclude='*.out' --exclude='*.out*[0-9]'"
        filters_diagnostics="--exclude='servers/*/data/store/diagnostics/*' --exclude='oracle-dfw-*/sampling/jvm_threads*'"
        command="/usr/bin/tar"
        # args='czf {0} {1} {2} {3} {4}'.format(file_name,filters_os,filters_logs,filters_diagnostics,folder)
        if isinstance(folder, list):
            args='czf %s %s %s %s %s' % (file_name,filters_os, filters_logs, filters_diagnostics, " ".join(folder))
        else:
            args='czf %s %s %s %s %s' % (file_name,filters_os, filters_logs, filters_diagnostics, folder)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=args)
        return command,args


    def get_fs_root(self):
        return "/"