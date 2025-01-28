"""
Copyright (c) 2017, 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

Module that handles SSH communication with remote machines.
"""
import os
import sys
import time
import re
from datetime import datetime
import exceptions

from java.io import File
from java.lang import Class as JClass
from java.lang import Exception as JException
from java.lang import IllegalArgumentException
from java.lang import System


from java.io import BufferedReader
from java.io import InputStreamReader
import java.io.IOException as IOException
import java.lang.Exception as JException
import java.lang.String as JString
import java.lang.System as JSystem

from oracle.weblogic.deploy.exception import BundleAwareException
from oracle.weblogic.deploy.create import CreateException
from oracle.weblogic.deploy.util import SSHException
from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict
from oracle.weblogic.deploy.util import StringUtils
from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import ScriptRunner
from oracle.weblogic.migration.discover import InfraCommandRunner

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),
                                'lib', 'python', 'migrate', 'infra'))

import infra_constants
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),
                                'deps', 'wdt', 'lib', 'python'))


from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.util import getcreds
from wlsdeploy.util.cla_utils import CommandLineArgUtil
from wlsdeploy.util.exit_code import ExitCode
from wlsdeploy.util import path_helper
from wlsdeploy.util import string_utils
from wlsdeploy.util.ssh_command_line_helper import SSHUnixCommandLineHelper
from wlsdeploy.util.ssh_command_line_helper import SSHWindowsCommandLineHelper
from wlsdeploy.aliases.alias_jvmargs import JVMArguments
from wlsdeploy.tool.discover import discoverer


_class_name = 'command_helper'
_logger = PlatformLogger('wlsdeploy.util')

class CommandHelper(object):
    def __init__(self, remote,os_cmd_line_helper,ssh_context=None):
        self.is_remote=remote
        self.ssh_context=ssh_context
        self.cmd_builder=os_cmd_line_helper
        self._path_helper = path_helper.get_path_helper()

    def compress_archive(self, file_name, archive_path, dry_run):
        _method_name= "compress_archive"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        cmd,args = self.cmd_builder.get_compress_commands(file_name,archive_path)
        if dry_run:
            response='%s %s ' % (cmd,args)
        else:
            response= self._run_command(cmd,args)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=cmd)
        return response


    def get_server_details(self, server=None):
        _method_name = "get_server_details"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        # cmd = self._os_helper.get_hostname()
        cmd,args,parser = self.cmd_builder.get_system_information()
        # cmd = self.cmd_builder.get_server_details(server)
        # if self._model_context.is_ssh():
        #     result = self._os_helper.get_single_result(self._run_command(cmd))
        #     response = self._os_helper.unicode_to_string(result)
        #     # _logger.info('WLSMIG-06311',error=type(response),class_name=_class_name, method_name=_method_name)
        # #     todo if reponse is == fail.  then raise exception
        # else:
        #     import socket
        #     response = socket.gethostname()
        response=self._run_command(cmd,args,parser)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=cmd)
        return response

    def is_fs_shared(self, path):
        _method_name = "is_fs_shared"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        cmd,args = self.cmd_builder.get_fs_nfs_cmd(path)
        result = OrderedDict()
        result[infra_constants.FILESYSTEM] = path
        if self.is_remote:
            full_command=cmd+" "+args
            response = self._run_command(full_command)
            if len(response) > 0:
                result[infra_constants.FILESYSTEM_TYPE] = infra_constants.FS_TYPE.SHARED
            else:
                result[infra_constants.FILESYSTEM_TYPE] = infra_constants.FS_TYPE.VOLUME
        else:
            # todo this needs to be changed when running local.
            result = self.cmd_builder.statdict(path)
        #     todo if reponse is == FAIL.  then raise exception ?
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=result)
        return result

    def get_owner(self, path):
        _method_name = "get_owner"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        cmd,args = self.cmd_builder.get_user_details(path)
        result = OrderedDict()
        response = self.cmd_builder.get_single_result(self._run_command(cmd,args))
        response = self.cmd_builder.unicode_to_string(response)
        user_pair = response.split(infra_constants.COMMA_SEPARATOR)[0]
        group_pair = response.split(infra_constants.COMMA_SEPARATOR)[1]
        result[infra_constants.USER_ID] = user_pair.split(infra_constants.COLON_SEPARATOR)[0]
        result[infra_constants.USERNAME] = user_pair.split(infra_constants.COLON_SEPARATOR)[1]
        result[infra_constants.GROUP_ID] = group_pair.split(infra_constants.COLON_SEPARATOR)[0]
        result[infra_constants.GROUP_NAME] = group_pair.split(infra_constants.COLON_SEPARATOR)[1]
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=result)
        return result


    def download_file_from_remote_server(self, model_context, remote_source_path, local_download_root_directory, file_type):
        _method_name = 'download_file_from_remote_server'
        _logger.entering(remote_source_path, local_download_root_directory, file_type,
                              class_name=_class_name, method_name=_method_name)

        return_path=self._path_helper.download_file_from_remote_server(model_context,remote_source_path,local_download_root_directory,file_type)



        _logger.exiting(class_name=_class_name, method_name=_method_name, result=return_path)
        return return_path

    def get_weblogic_server_processes(self,jvm_list):
        _method_name = "get_weblogic_server_processes"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        jvm_processes=[]
        for jvm in jvm_list:
            jvm_args = jvm.get_unsorted_args_list()
            for args in jvm_args:
                if infra_constants.WLS_MANAGED_SERVER_PROCESS_KEY in args:
                    _logger.fine("found a Weblogic JVM",class_name=_class_name, method_name=_method_name)
                    jvm_processes.append(jvm)
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return jvm_processes

    # def get_node_manager_processes(self,type=infra_constants.NM_TYPE_JAVA):
    #     _method_name = "get_node_manager_processes"
    #     _logger.entering(class_name=_class_name, method_name=_method_name)
    #     if type == infra_constants.NM_TYPE_JAVA:
    #         nm_proc=self.get_processes(infra_constants.NM_JAVA_PROCESS_KEY)
    #         # should only be one node manager per host.
    #         jvm_details = JVMArguments(_logger, nm_proc)
    #         _logger.exiting(class_name=_class_name, method_name=_method_name)
    #         return jvm_details
    #     else:
    # #       TODO(joi) list processes that are not java based nodemanager
    #         pass

    def get_node_manager_vm(self, jvms_list, type=infra_constants.NM_TYPE_JAVA):
        _method_name = "get_node_manager_processes"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        node_manager_jvm=[]
        if type == infra_constants.NM_TYPE_JAVA:
            # nm_proc = self.get_processes(infra_constants.NM_JAVA_PROCESS_KEY)
            # should only be one node manager per host.
            # jvm_details = JVMArguments(_logger, nm_proc)

            for jvm in jvms_list:
                jvm_args = jvm.get_unsorted_args_list()
                # next((s for s in mylist if sub in s), None)
                for args in jvm_args:
                    if infra_constants.NM_JAVA_PROCESS_KEY in args:
                        _logger.exiting(class_name=_class_name, method_name=_method_name, result=jvm_args)
                        node_manager_jvm.append(jvm)
            # should raise an exception ?
            return node_manager_jvm
        else:
            #       TODO(joi) list processes that are not java based nodemanager
            return node_manager_jvm

    #@return string[] jvm_processes:  List of JVMArguments.
    def get_java_processes(self):
        """Scan through list of processes looking for JVMS, returning
    a list of JVMArgument Objects, or Emtpy if no match was found."""
        _method_name = "get_jdk_processes"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        java_proc=self._get_processes(infra_constants.JAVA_PROCESS_KEY)
        jvm_processes = []
        if isinstance(java_proc,str):
            jvm_processes.append(JVMArguments(_logger, java_proc))
        else:
            for proc in java_proc:
                jvm_processes.append(JVMArguments(_logger, proc))
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return jvm_processes



    def find_partial_matches(self,string_list, pattern):
        _method_name = "find_partial_matches"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        import re
        partial_matches = []
        for s in string_list:
            if re.search(pattern, s, flags=re.IGNORECASE):
                partial_matches.append(s)
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return partial_matches

    def filter_jvms_by_key(self,jvms, expr):
        pattern = re.compile(expr, re.DOTALL)
        domain_jvms=[]
        for jvm in jvms:
            jvm_str = jvm
            if isinstance(jvm,JVMArguments):
                jvm_str=jvm.get_arguments_string()
            if re.search(pattern, jvm_str):
                domain_jvms.append(jvm)
        return domain_jvms

    #Find all running OS processes filtered by KEY
    #@param key :  String to filter list of processes found.
    #@returns : List of strings with processes found
    def _get_processes(self, key):
        _method_name = "get_processes"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        cmd,args,parser=self.cmd_builder.list_process(key)
        result=self._run_command(cmd,args,parser)
        _logger.exiting(class_name=_class_name, method_name=_method_name,result=result)
        return result



    def _run_command(self, cmd, args, parser=None):
        _method_name = "_run_command"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        if self.is_remote:
            full_command=cmd+" "+args
            exit_code, response = self.ssh_context._run_exec_command(full_command)
        else:
            exit_code, response = self._local_exec_command(cmd,args)
        if exit_code == infra_constants.FAIL:
            response = list()
        if parser is not None:
            response = parser(response)
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return response



    def sanitize_command(self, cmd):
        return

    def _local_exec_command(self, cmd, args, timeout=infra_constants.CMD_TIME_OUT):
        _method_name = '_local_exec_command'
        try:
            _logger.entering(_class_name, _method_name)
            script =""
            if script is None:
                _logger.exiting(class_name=_class_name, method_name=_method_name, result="script is None")
                return
            timer = time.time()
            runner =InfraCommandRunner("python","localRunLog",cmd,args)
            exit_code=runner.runScript()
            output=runner.getOutput()
            if len(output) == 0:
                exit_code=1
            _logger.exiting(class_name=_class_name, method_name=_method_name, result=timer)
            return exit_code,output
        except CreateException, ce:
            ex = exception_helper.create_discover_exception(ExitCode.ERROR,
                                                       'WLSDPLY-20028', ce.getLocalizedMessage(), error=ce)
            __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex


    def get_unique_java_homes(self, jvm_list):
        """Return a list of unique JAVA_HOMES found in a list of JVM OS processes."""
        _method_name = "get_unique_java_homes"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        # _path_helper = path_helper.get_path_helper()
        # unique_java_homes=OrderedDict()
        for jvm in jvm_list:
            #Attempting to find java homes by filtering out jvms unsorted arguments by bin/java (linux) or java.exe (windows)
            java_cmd,_=self.cmd_builder.get_java_exec()
            matches=self.find_partial_matches(jvm.get_unsorted_args_list(),java_cmd)
            for java_cmd in matches:
                bin_dir = self._path_helper.get_parent_directory(java_cmd)
                jdk_home = self._path_helper.get_parent_directory(bin_dir)
                # discoverer.add_to_model(unique_java_homes,jdk_home,infra_constants.EMPTY)
                # Should find only one java_home.  Others maybe captured incorrectly.
                _logger.exiting(class_name=_class_name, method_name=_method_name, result=jdk_home)
                return jdk_home
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return infra_constants.EMPTY


    def get_unique_paths_in_jvms(self, jvms, exclude_patterns):
        """list unique OS directory paths in a provided list of jvms"""
        _method_name="get_unique_paths_in_jvms"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        paths=self._get_paths_in_jvms(jvms, exclude_patterns)
        unique_paths = [path for path in paths.iterkeys()]
        unique_fs_paths=self.get_unique_paths(unique_paths)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=unique_fs_paths)
        return unique_fs_paths


    def list_paths_in_jvms(self,jvms):
        """list all OS directory paths in a provided list of jvms"""
        return self._get_paths_in_jvms(self, jvms, None)

    # @params jvms:  List of JVMArguments objects
    # @exclude_patterns :  List of string patterns to exclude if there is a match in a JVM.
    def _get_paths_in_jvms(self, jvms, exclude_patterns):
        """From a list of JVMArgument objects iterates to find OS file paths (i.e /opt/weblogic) and add them to a unique list of paths"""

        _method_name = "_get_paths_in_jvms"
        _logger.entering(jvms, exclude_patterns,class_name=_class_name, method_name=_method_name)
        unique_paths=OrderedDict()
        #
        # jvm.get_xx_args_dict()
        # jvm.get_x_args_dict()
        # jvm.get_sys_props_dict()
        # jvm.get_unsorted_args_list()
        for jvm in jvms:
            for key,value in jvm.get_x_args_dict().iteritems():
                self._find_unique_dirs_except_pattern(unique_paths, value, key, exclude_patterns)
            for key,value in jvm.get_xx_args_dict().iteritems():
                self._find_unique_dirs_except_pattern(unique_paths, value, key, exclude_patterns)
            for key,value in jvm.get_sys_props_dict().iteritems():
                self._find_unique_dirs_except_pattern(unique_paths,value,key,exclude_patterns)
            for value in jvm.get_unsorted_args_list():
                self._find_unique_dirs_except_pattern(unique_paths, value, value, exclude_patterns)
            _logger.exiting(class_name=_class_name, method_name=_method_name, result=unique_paths)
        return unique_paths

    def __add_path_except_pattern(self,dictionary,path,key,exclude_patterns):
        import re
        _method_name="__add_path_except_pattern"
        _logger.entering(path,class_name=_class_name, method_name=_method_name)
        dir_pattern = self.cmd_builder.get_directory_regexp()
        if path is not None:
            if re.match(dir_pattern, path):
                # Python syntax does not work in jython
                if not self.is_remote and not os.path.exists(path):
                    _logger.fine('path {0} does not exist in fs. ',
                                 path,class_name=_class_name,method_name=_method_name)
                    return;

                if not self.is_remote and os.path.isfile(path):
                    file = path
                    path = self._path_helper.get_parent_directory(path)
                    _logger.fine('path is a file. with parent dir {0}',
                                 path,class_name=_class_name,method_name=_method_name)
                if self.is_remote and not len(path) > 2:
                    _logger.fine('it is assume it is a bogus file {0}. not including',
                                 path,class_name=_class_name,method_name=_method_name)
                    return;

                # if all([not path.startswith(item) for item in exclude_patterns]):
                for item in exclude_patterns:
                    if path.startswith(item):
                        _logger.fine('path {0} starts with item {1}',
                                            path,item,class_name=_class_name,method_name=_method_name)
                        return;
                    if item.startswith(path):
                        _logger.fine('item {0} starts with path {1}',
                                            item,path,class_name=_class_name,method_name=_method_name)

                        return;
                    if self._path_helper.is_relative_path(path):
                        _logger.fine('path {0} is relative',
                                            path,class_name=_class_name,method_name=_method_name)
                        return;
                # parent=self._path_helper.get_parent_directory(path)
                # discoverer.add_to_model(dictionary, parent, key)
                # Last check if it is something to add
                # if file:
                #     path=file

                _logger.fine('adding paht to the dictionary {0} with key {1}',
                                    path,key, class_name=_class_name,method_name=_method_name)
                discoverer.add_to_model(dictionary, path, key)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=path)

    def _find_unique_dirs_except_pattern(self,unique_paths,value,key,exclude_patterns):
        if isinstance(value, (str,unicode)):
            self.__add_path_except_pattern(unique_paths,value,key,exclude_patterns)
        elif isinstance(value, OrderedDict):
            for next_key, next_value in value.iteritems():
                self._find_unique_dirs_except_pattern(unique_paths,next_value,next_key,exclude_patterns)

    def filter_top_dir(self, f_list):
        _method_name="filter_top_dir"
        _logger.entering(f_list,class_name=_class_name, method_name=_method_name)
        file_list = list()
        for item in f_list:
            if not string_utils.is_empty(item) and len(string_utils.rsplit(item,":")) == 1 :
                file_list.append(item)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=file_list)
        return file_list

    def get_server_hostname(self):
        _method_name="get_server_hostname"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        hostname=""
        if self.is_remote:
            hostname=self.ssh_context._ssh_client.getRemoteHostname()
        else:
            cmd,args=self.cmd_builder.get_hostname()
            hostname=self._run_command(cmd,args)
            if len(hostname) > 0:
                hostname = hostname[0]
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=hostname)
        return hostname

    def get_unique_paths(self,input_list):
        """
        This function takes a list of Linux-style paths and returns a list of unique paths,
        excluding paths that are subfolders of other paths.

        Args:
            input_list: A list of strings representing Linux-style paths.

        Returns:
            A list of strings representing unique paths, excluding subfolders.
        """
        _method_name="get_unique_paths"
        _logger.entering(input_list,class_name=_class_name, method_name=_method_name)
        unique_paths = []
        if input_list is None:
            return unique_paths
        input_list = list(set(input_list))
        for path in input_list:
            # Check if the path is a subfolder of any existing path
            is_subfolder = False
            for existing_path in unique_paths:
                if path.startswith(existing_path + os.sep):
                    is_subfolder = True
                    break
            # Add the path only if it's not a subfolder
            if not is_subfolder:
                unique_paths.append(path)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=unique_paths)
        return unique_paths