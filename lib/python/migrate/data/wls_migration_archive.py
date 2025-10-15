# -*- coding: utf-8 -*-
"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

The main module for the WebLogic Deploy tool to verify the user's SSH configuration is compatible with WDT.
"""
import os
import re
import sys

from oracle.weblogic.deploy.util import SSHException
from oracle.weblogic.deploy.util import CLAException
from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import TranslateException
from oracle.weblogic.deploy.util import VariableException
from oracle.weblogic.deploy.validate import ValidateException
from oracle.weblogic.deploy.encrypt import EncryptionUtils
from oracle.weblogic.deploy.util import WLSDeployArchiveIOException

# from lib.python.migrate.infra.infra_discoverer import InfraDiscoverer

from java.io import File
from java.io import IOException
from java.lang import IllegalArgumentException
from java.lang import IllegalStateException
from java.lang import String
from java.lang import System

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))
import infra_constants
from remote.command_helper import CommandHelper
from remote.command_line_helper import RemoteUnixCommandLineHelper


sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))

from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.util.model import Model
from wlsdeploy.util import model_translator
from wlsdeploy.exception import exception_helper
from wlsdeploy.tool.util import model_context_helper
from wlsdeploy.tool.util import wlst_helper
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.util import path_helper
from wlsdeploy.util import tool_main
from wlsdeploy.util.cla_utils import CommandLineArgUtil
from wlsdeploy.util.cla_utils import TOOL_TYPE_DEFAULT
from wlsdeploy.util.exit_code import ExitCode
from wlsdeploy.util import env_helper
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.tool.discover.custom_folder_helper import CustomFolderHelper
from wlsdeploy.json import json_translator
from wlsdeploy.aliases.wlst_modes import WlstModes

from oracle.weblogic.deploy.util import WLSDeployArchive
from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict
from oracle.weblogic.deploy.discover import DiscoverException
from oracle.weblogic.deploy.util import TranslateException
from oracle.weblogic.deploy.util import WebLogicDeployToolingVersion
from wlsdeploy.aliases import model_constants
from wlsdeploy.aliases.model_constants import DOMAIN_INFO
from wlsdeploy.aliases.aliases import Aliases
from wlsdeploy.aliases.model_constants import DEFAULT_WLS_DOMAIN_NAME
from wlsdeploy.aliases.model_constants import DOMAIN_NAME
from wlsdeploy.aliases.model_constants import TOPOLOGY
from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.tool.create.domain_creator import DomainCreator
from wlsdeploy.tool.util import model_context_helper
from wlsdeploy.tool.util.archive_helper import ArchiveList
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.tool.util import wlst_helper
from wlsdeploy.util import cla_helper
from wlsdeploy.util import tool_main
from wlsdeploy.aliases.model_constants import UNIX_MACHINE
from wlsdeploy.aliases.model_constants import MACHINE
from wlsdeploy.aliases.model_constants import MACHINES
from wlsdeploy.aliases.model_constants import NAME
from wlsdeploy.util import dictionary_utils

from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.tool.util import filter_helper
from wlsdeploy.util import env_helper
from wlsdeploy.util import model_translator
from wlsdeploy.util import variables
from wlsdeploy.util.cla_utils import CommandLineArgUtil
from wlsdeploy.util.exit_code import ExitCode
from wlsdeploy.util import string_utils


_program_name = 'archiveInfra'
_class_name = 'archive_helper'
_logger = PlatformLogger('wlsdeploy.tool.util')

result_dict = OrderedDict()
remote_dict = OrderedDict()
model_context_dict = OrderedDict()
__wlst_mode = WlstModes.OFFLINE
REMOTE_TYPE = 'Type'
REMOTE_ARCHIVE_PATH = 'ArchivePath'

# _ssh_download_dir = None


class WLSMigrationArchiver(object):

    def __init__(self, machine, model_context, dictionary, base_location, model, wlst_mode=None, aliases=None, credential_injector=None):
        """
        :param model_context: context about the model for this instance of discoverDomain
        :param base_location: to look for common WebLogic resources. By default, this is the global path or '/'
        :param wlst_mode: offline or online
        :param aliases: optional, aliases object to use
        :param credential_injector: optional, injector to collect credentials
        """
        _method_name = '__init__'
        self._machine=machine
        self._discovered_domain=dictionary
        self._model = model
        self._model_context = model_context
        self._base_location = base_location
        self._wlst_mode = wlst_mode
        if aliases:
            self._aliases = aliases
        else:
            self._aliases = Aliases(self._model_context,
                                    exception_type=ExceptionType.DISCOVER)
        # self._credential_injector = credential_injector
        self._att_handler_map = OrderedDict()
        self._custom_folder = CustomFolderHelper(self._aliases, _logger, self._model_context, ExceptionType.DISCOVER)
        self._weblogic_helper = model_context.get_weblogic_helper()
        self._wlst_helper = WlstHelper(ExceptionType.DISCOVER)

        # self._wls_version = model_context.get_effective_wls_version()
        self.path_helper = path_helper.get_path_helper()

        self._os_helper = RemoteUnixCommandLineHelper()
        ssh_context = model_context.get_ssh_context()
        if self._model_context.is_ssh():
            if ssh_context.is_windows:
                # Todo :  Add WindowsCommandLineHelper
                self._os_helper = RemoteUnixCommandLineHelper()
            self.path_helper.set_remote_path_module(ssh_context.is_windows)
        self._cmd_helper=CommandHelper(model_context.is_ssh(), self._os_helper, ssh_context)


    def archive(self):
        _method_name = 'archive'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        local_path=self._model_context.get_local_output_dir()
        remote_path=self._model_context.get_remote_output_dir()
        _ssh_download_dir=remote_path
        if self._model_context.is_ssh():
            # TODO: (joi) verify remote path exists.
            archive_dir_name = self.path_helper.get_remote_parent_directory(remote_path)
        else:
            archive_dir_name = self.path_helper.get_local_parent_directory(local_path)
            if not os.path.exists(archive_dir_name):
                ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                           'WLSDPLY-06026', archive_dir_name)
                _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
                raise ex

        domain_name = self._model.get_model_topology()[model_constants.DOMAIN_NAME]
        domain_path = self._model.get_model_topology()[infra_constants.DOMAIN_HOME_DIR]
        oracle_path = self._model.get_model_topology()[infra_constants.ORACLE_HOME_DIR] or self._model_context.get_oracle_home()
        extra_directories = self._model.get_model_resources()["Machines"][self._machine]["ExtraOSPaths"]
        # check if it exist, assume same path for everyone.
        self.__process_java_home(domain_name,_ssh_download_dir)
        self.__process_domain_home(domain_name,domain_path,_ssh_download_dir)
        self.__process_weblogic_home(domain_name,oracle_path,_ssh_download_dir)
        self.__process_custom_directories(domain_name,extra_directories,_ssh_download_dir)
        return infra_constants.SUCCESS


        ###Directory Archiving ####
    def __process_java_home(self,domain_name,ssh_download_dir):
        _method_name="__process_java_home"
        dir_to_compress = self._model.get_model_resources()["Machines"][self._machine]["CanonicalJavaPath"]
        _logger.entering(self._machine, dir_to_compress, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)

        suffix="java_home"
        # archive_file_name = self._machine+"-"+domain_name+"-java_home.tar.gz"
        file_path=self._model_context.get_local_output_dir()
        if self._model_context.is_ssh():
            file_path=self._model_context.get_remote_output_dir()
        archive_file_name = '%s/%s-%s-%s.tar.gz' % (file_path,self._machine, domain_name, suffix)
        archive=self.__archive_directory(dir_to_compress,archive_file_name, ssh_download_dir,suffix)
        _logger.exiting(class_name=_class_name, method_name=_method_name)



    def __process_domain_home(self,domain_name, domain_path,ssh_download_dir):
        _method_name="__process_domain_home"
        _logger.entering(self._machine, domain_path, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)
        suffix ="domain_home"
        file_path=self._model_context.get_local_output_dir()
        if self._model_context.is_ssh():
            file_path=self._model_context.get_remote_output_dir()
        archive_file_name = '%s/%s-%s-%s.tar.gz' % (file_path,self._machine, domain_name, suffix)
        archive=self.__archive_directory(domain_path,archive_file_name, ssh_download_dir,suffix)

        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __process_weblogic_home(self, domain_name, weblogic_home, ssh_download_dir):
        _method_name="__process_weblogic_home"
        _logger.entering(self._machine, weblogic_home, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)
        suffix="weblogic_home"
        file_path=self._model_context.get_local_output_dir()
        if self._model_context.is_ssh():
            file_path=self._model_context.get_remote_output_dir()
        archive_file_name = '%s/%s-%s-%s.tar.gz' % (file_path,self._machine, domain_name, suffix)
        archive=self.__archive_directory(weblogic_home,archive_file_name,ssh_download_dir,suffix)
        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __process_custom_directories(self, domain_name, extra_directories, ssh_download_dir):
        _method_name="__process_custom_directory"
        suffix="custom_dirs"
        _logger.entering(domain_name, suffix, extra_directories,
                              class_name=_class_name, method_name=_method_name)
        if len(extra_directories) == 0 :
            _logger.info('WLSDPLY-06034', "custom_dirs", "no custom_dirs",
                         class_name=_class_name, method_name=_method_name)
            return
        if len(extra_directories) == 1 and extra_directories[0] == "/":
            _logger.info('WLSDPLY-06034', "custom_dirs", "Extra dir found to be root / - ignoring",
                         class_name=_class_name, method_name=_method_name)
            return
        #flatten list of custom archives

        file_path=self._model_context.get_local_output_dir()
        if self._model_context.is_ssh():
            file_path=self._model_context.get_remote_output_dir()
        archive_file_name = '%s/%s-%s-%s.tar.gz' % (file_path,self._machine, domain_name, suffix)
        self.__archive_directory(extra_directories,archive_file_name,ssh_download_dir,suffix)
        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __archive_directory(self, dir_to_compress, archive_file_name, ssh_download_dir, path_key):
        _method_name="__archive_directory"
        _logger.entering(self._machine, dir_to_compress, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)

        # Delete any existing archive file for discoverDomain so that we always start with a fresh compressed file.
        archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        if archive_file_obj.exists() and not archive_file_obj.delete():
            ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
                                                       _program_name, archive_file_name)
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

        is_dry_run = self._model_context.is_skip_archive()
        response=self._cmd_helper.compress_archive(archive_file_name, dir_to_compress, is_dry_run)
        if not is_dry_run :
            if self._model_context.is_ssh():
                    entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,archive_file_name,
                                                                                   self._model_context.get_local_output_dir(),
                                                                               "")
                    _logger.info('WLSDPLY-06034', path_key, entry_path,
                                 class_name=_class_name, method_name=_method_name)
        else:
            # if -skip_archive or -remote, add to the remote map for manual addition
            self.add_to_remote_map(path_key,
                                   response,
                                   "FILE_STORE")

        _logger.exiting(class_name=_class_name, method_name=_method_name)

    # def __remove_files_directories_from_archive(self, archive_file):
    #         _method_name="_remove_files_directories_from_archive"
    #         file_list = archive_file.listCustomFiles()
    #         # filter files by regexp
    #         #Default file exclusions
    #         # server_home/data/nodemanager/*.lck
    #         # server_home/*/adr/diag/ofm/*/*/lck/*.lck
    #
    #         # server_home/data/nodemanager/*.pid
    #         # server_home/tmp
    #         # server_home/data/nodemanager/*.state
    #         # Todo: Exclude core dumps.  Research.
    #         # Todo:  Jul 25th
    #         # server_home/*/adr/oracle-dfw-*/sampling/jvm_threads*
    #         # server_home/tmp
    #         # _lock_regex = re.compile('-D([a-zA-Z0-9-_.]+ ?)(=([\S]+ ?))?')
    #         # __sys_props_regex = re.compile('-D([a-zA-Z0-9-_.]+ ?)(=([\S]+ ?))?')
    #         # exclude_logs_dir_regexp='^.*/logs/.*'
    #         # exclude_filters=exclude_logs_dir_regexp
    #         exclude_filters='^(.*/logs/.*)|^(.*/sampling/jvm_threads.*)|^(.*/servers/.*/tmp)'
    #         regex = re.compile(exclude_filters,re.IGNORECASE)
    #         for file_or_dir in file_list:
    #             # hack for now.
    #             file_or_dir = file_or_dir[len("wlsdeploy/custom/")::]
    #             print("JOI: file in the list: "+file_or_dir)
    #             if file_or_dir.lower().endswith(".lck") or file_or_dir.lower().endswith(".pid") or file_or_dir.lower().endswith(".state"):
    #                 print("JOI: match ending in lck, pid, state"+file_or_dir)
    #                 archive_file.removeCustomEntry(file_or_dir,True)
    #                 continue
    #             if file_or_dir.lower().endswith(".log") or "tmp" in file_or_dir.lower():
    #                 print("JOI: match ending in log and tmp"+file_or_dir)
    #                 archive_file.removeCustomEntry(file_or_dir,True)
    #                 continue
    #             if regex.match(file_or_dir):
    #                 print("JOI: pattern found a match"+file_or_dir)
    #                 archive_file.removeCustomEntry(file_or_dir,True)
    #                 continue

    def add_to_remote_map(self, local_name, archive_name, file_type):
        # we don't know the remote machine type, so automatically
        # turn into forward slashes.
        local_name = self.path_helper.fixup_path(local_name, self._model_context.get_domain_home())
        remote_dict[local_name] = OrderedDict()
        remote_dict[local_name][REMOTE_TYPE] = file_type
        remote_dict[local_name][REMOTE_ARCHIVE_PATH] = archive_name

        if file_type == 'FILE_STORE' or file_type == 'COHERENCE_PERSISTENCE_DIR':
            _logger.todo('WLSDPLY-06042', file_type, archive_name)
        else:
            _logger.todo('WLSDPLY-06041', file_type, local_name, archive_name)

    def log_message(self, suffix, path, domain_name):
        """
        Print the log message
        :param suffix: used for file name
        :param path: path for which the archives have to be created
        :param domain_name: name of the domain
        :return: none, prints the log message with the tar commands to create archives
        """
        file_path = self._model_context.get_local_output_dir()
        if self._model_context.is_ssh():
            file_path = self._model_context.get_remote_output_dir()

        file_type = "FILE_STORE"
        skip_archive_dry_run = True

        archive_file_name = '%s/%s-%s-%s.tar.gz' % (file_path, self._machine, domain_name, suffix)
        tar_cmd = self._cmd_helper.compress_archive(archive_file_name, path, skip_archive_dry_run)
        _logger.todo('WLSDPLY-06042', file_type, tar_cmd)


    def print_per_host_todo_commands(self):
        """
        Print the tar commands for particular host (self._machine) only.
        """
        topology = self._model.get_model_topology()
        domain_name = topology[model_constants.DOMAIN_NAME]
        domain_path = topology[infra_constants.DOMAIN_HOME_DIR]

        # Oracle Home lookup as the key values are different for 12.2.1.4 and 14.1.2.0
        try:
            weblogic_home = topology[infra_constants.ORACLE_HOME_DIR]
        except KeyError:
            try:
                weblogic_home = topology['OraclePath']
            except KeyError:
                weblogic_home = self._model_context.get_oracle_home()

        # Build extra_directories and java_home when skip-archive is active:
        java_home = None
        extra_dirs = []
        try:
            machines = self._model.get_model_resources()["Machines"]
            if machines is not None and self._machine in machines:
                md = machines[self._machine]
                if md is not None:
                    try:
                        java_home = md["CanonicalJavaPath"]
                    except Exception:
                        pass
                    try:
                        extra_dirs = md["ExtraOSPaths"]
                    except Exception:
                        extra_dirs = []
        except Exception:
            # Machines section missing/null or host not present: skip per-host java_home TODOs
            pass

        # --- Print tar commands for java_home for this host ---
        if java_home:
            suffix = "java_home"
            self.log_message(suffix, java_home, domain_name)

        # --- Print domain_home tar commands  for this host ---
        suffix = "domain_home"
        self.log_message(suffix, domain_path, domain_name)

        # --- Print weblogic_home tar commands for this host ---
        suffix = "weblogic_home"
        self.log_message(suffix, weblogic_home, domain_name)

        # --- Print custom_dirs tar commands for this host if present and not just root ---
        if extra_dirs and (len(extra_dirs) != 1 or extra_dirs[0] != "/"):
            suffix = "custom_dirs"
            self.log_message(suffix, extra_dirs, domain_name)
