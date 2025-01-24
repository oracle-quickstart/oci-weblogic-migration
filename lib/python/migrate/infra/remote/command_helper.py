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
        if self.is_remote:
            # full_command=cmd+" "+args
            response = self.cmd_builder.get_single_result(self._run_command(cmd,args))
            response = self.cmd_builder.unicode_to_string(response)
            user_pair = response.split(infra_constants.COMMA_SEPARATOR)[0]
            group_pair = response.split(infra_constants.COMMA_SEPARATOR)[1]
            result[infra_constants.USER_ID] = user_pair.split(infra_constants.COLON_SEPARATOR)[0]
            result[infra_constants.USERNAME] = user_pair.split(infra_constants.COLON_SEPARATOR)[1]
            result[infra_constants.GROUP_ID] = group_pair.split(infra_constants.COLON_SEPARATOR)[0]
            result[infra_constants.GROUP_NAME] = group_pair.split(infra_constants.COLON_SEPARATOR)[1]
        else:
            response = self.cmd_builder.statdict(path)
            #     todo if reponse is == fail.  then raise exception
            # response="running local"
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
                    _logger.finest("found a Weblogic JVM",class_name=_class_name, method_name=_method_name)
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
            # script = self._domain_typedef.get_post_create_rcu_schemas_script()
            if script is None:
                _logger.exiting(class_name=_class_name, method_name=_method_name)
                return
            # runner = ScriptRunner()
            # runner = CreateDomainLifecycleHookScriptRunner(
            #     POST_CREATE_RCU_SCHEMAS_LIFECYCLE_HOOK, POST_CREATE_RCU_SCHEMA_LOG_BASENAME, , java_home,
            #     oracle_home, self._model_context.get_domain_home(), self._model_context.get_domain_name())
            timer = time.time()
            runner =InfraCommandRunner("python","localRunLog",cmd,args)
            exit_code=runner.runScript()
            output=runner.getOutput()
            if len(output) == 0:
                exit_code=1
            _logger.exiting(class_name=_class_name, method_name=_method_name)
            return exit_code,output
            # for line in array:
            #     print(line)
            #
            # print("done printing")
            # print(timer)
            # # Construct the command and its arguments
            # process = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            #                            close_fds=True)

            # Timeout handling

            # while time.time() - timer <= timeout:
            #     for input_ in inputs:
            #         process.stdin.write(input_ + '\n')
            #     process.stdin.flush()
            #     if process.stdout.readline() != '' and print_console_message:
            #         sys.stdout.write(process.stdout.readline())
            #     if process.stderr.readline() != '' and print_console_message:
            #         sys.stderr.write(process.stderr.readline())
            #     time.sleep(0.1)  # Adjust this value if you need a more precise timeout
            #
            # process.stdin.close()

            # # Wait for process termination or timeout
            # if process.wait(timeout=timeout) is None:
            #     process.terminate()  # Terminate the process if it's still running after the timeout

            # Get the return code and combined output/error streams
            # return (process.returncode, process.stdout.read().decode().strip(), process.stderr.read().decode().strip())
        except CreateException, ce:
            ex = exception_helper.create_discover_exception(ExitCode.ERROR,
                                                       'WLSDPLY-20028', ce.getLocalizedMessage(), error=ce)
            __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

    #TODO host command run at OS level has to be found with full path. Either use which command in linux or read it from en user provided properties.
    # def check_cmd_exists(cmd):
    #     try:
    #         subprocess.check_output(["which", cmd], stderr=subprocess.STDOUT)
    #         return True
    #     except subprocess.CalledProcessError:
    #         return False


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
        paths=self._get_paths_in_jvms(jvms, exclude_patterns)
        unique_paths = [path for path in paths.iterkeys()]
        return self.cmd_builder.get_unique_paths(unique_paths)


    def list_paths_in_jvms(self,jvms):
        """list all OS directory paths in a provided list of jvms"""
        return self._get_paths_in_jvms(self, jvms, None)

    # @params jvms:  List of JVMArguments objects
    # @exclude_patterns :  List of string patterns to exclude if there is a match in a JVM.
    def _get_paths_in_jvms(self, jvms, exclude_patterns):
        """From a list of JVMArgument objects iterates to find OS file paths (i.e /opt/weblogic) and add them to a unique list of paths"""

        _method_name = "_get_paths_in_jvms"
        _logger.entering(class_name=_class_name, method_name=_method_name)
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
        dir_pattern = self.cmd_builder.get_directory_regexp()
        if path is not None:
            if re.match(dir_pattern, path):
                # Python syntax does not work in jython
                # if all([not path.startswith(item) for item in exclude_patterns]):
                for item in exclude_patterns:
                    if path.startswith(item):
                        return;
                    if item.startswith(path):
                        return;
                    if self._path_helper.is_relative_path(path):
                        return;
                # parent=self._path_helper.get_parent_directory(path)
                # discoverer.add_to_model(dictionary, parent, key)
                discoverer.add_to_model(dictionary, path, key)

    def _find_unique_dirs_except_pattern(self,unique_paths,value,key,exclude_patterns):
        if isinstance(value, (str,unicode)):
            self.__add_path_except_pattern(unique_paths,value,key,exclude_patterns)
        elif isinstance(value, OrderedDict):
            for next_key, next_value in value.iteritems():
                self._find_unique_dirs_except_pattern(unique_paths,next_value,next_key,exclude_patterns)

    def filter_top_dir(self, f_list):
        _method_name="filter_top_dir"
        file_list = list()
        for item in f_list:
            if not string_utils.is_empty(item) and len(string_utils.rsplit(item,":")) == 1 :
                file_list.append(item)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=file_list)
        return file_list

    def get_server_hostname(self):
        hostname=""
        if self.is_remote:
            hostname=self.ssh_context._ssh_client.getRemoteHostname()
        else:
            hostname=self.cmd_builder.get_hostname()
        return hostname