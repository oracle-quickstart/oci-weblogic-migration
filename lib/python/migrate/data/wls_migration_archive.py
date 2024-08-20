"""
Copyright (c) 2023, 2024, Oracle Corporation and/or its affiliates.
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
        # global _ssh_download_dir
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
        _ssh_download_dir=None
        if self._model_context.is_ssh():
        # if self._ssh_download_dir is None:
            try:
                download_dir_file = FileUtils.createTempDirectory('wdt-downloadtemp-'+self._machine)
                download_dir_file.deleteOnExit()
            except IOException, e:
                ex = exception_helper.create_discover_exception('WLSDPLY-06161',
                                                                e.getLocalizedMessage(), error=e)
                _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
                raise ex

            _ssh_download_dir = download_dir_file.getAbsolutePath()
        # self.download_temporary_dir = _ssh_download_dir
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
        path=self._model.get_model_topology()["NMProperties"]["JavaHome"]
        _logger.entering(self._machine, path, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)

        #TODO add env variable to chane location --outputdir
        suffix="java_home"
        # archive_file_name = self._machine+"-"+domain_name+"-java_home.zip"
        archive_file_name = '%s-%s-%s.zip' % (self._machine, domain_name, suffix)
        self.__archive_directory(path,archive_file_name, ssh_download_dir,suffix)
        # archive_dir_name = self.path_helper.get_local_parent_directory(archive_file_name)
        # if not os.path.exists(archive_dir_name):
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06026', archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # # Delete any existing archive file for discoverDomain so that we always start with a fresh zip file.
        # archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        # if archive_file_obj.exists() and not archive_file_obj.delete():
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
        #                                                _program_name, archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # try:
        #     archive = WLSDeployArchive(archive_file_name)
        # except (IllegalArgumentException, IllegalStateException), ie:
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06013', _program_name, archive_file_name,
        #                                                ie.getLocalizedMessage(), error=ie)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        # entries = []
        # file_list = []
        # if self._model_context.is_ssh():
        #     # only if it exists
        #     file_list = self._model_context.get_ssh_context().get_directory_contents(path, True)
        #     file_list = self._cmd_helper.filter_top_dir(file_list)
        # elif os.path.isdir(path):
        #     # file_list = os.listdir(path)
        #     file_list.append(path)
        # if archive:
        #     for entry_path in file_list:
        #         try:
        #             if self._model_context.is_ssh():
        #                 entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,entry_path,
        #                                                                                ssh_download_dir,
        #                                                                          "java_home")
        #
        #             updated_name=archive.addCustomEntry(entry_path,"java_home"+path, True)
        #             entries.append(updated_name)
        #         except WLSDeployArchiveIOException, wioe:
        #             de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
        #                                                             wioe.getLocalizedMessage())
        #             _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
        #             raise de
        # else:
        #     # if -skip_archive or -remote, add to the remote map for manual addition
        #     self.add_to_remote_map(path,
        #                                  "java_home",
        #                                  WLSDeployArchive.ArchiveEntryType.CUSTOM.name())
        #
        #     _logger.finer('WLSDPLY-06422', path, class_name=_class_name,
        #                   method_name=_method_name)
        _logger.exiting(class_name=_class_name, method_name=_method_name)



    def __process_domain_home(self,domain_name, domain_path,ssh_download_dir):
        _method_name="__process_domain_home"
        _logger.entering(self._machine, domain_path, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)

        # #TODO add env variable to chane location --outputdir
        suffix ="domain_home"
        archive_file_name = '%s-%s-%s.zip' % (self._machine, domain_name, suffix)
        files_added, archive=self.__archive_directory(domain_path,archive_file_name, ssh_download_dir,suffix)
        if files_added:
            try:
                self.__remove_files_directories_from_archive(archive)
            except WLSDeployArchiveIOException, wioe:
                de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
                                                                wioe.getLocalizedMessage())
                _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
                raise de

        # archive_dir_name = self.path_helper.get_local_parent_directory(archive_file_name)
        # if not os.path.exists(archive_dir_name):
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06026', archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # # Delete any existing archive file for discoverDomain so that we always start with a fresh zip file.
        # archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        # if archive_file_obj.exists() and not archive_file_obj.delete():
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
        #                                                _program_name, archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # try:
        #     archive = WLSDeployArchive(archive_file_name)
        # except (IllegalArgumentException, IllegalStateException), ie:
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06013', _program_name, archive_file_name,
        #                                                ie.getLocalizedMessage(), error=ie)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        # files_added=False
        # file_list = []
        # if self._model_context.is_ssh():
        #     file_list = self._model_context.get_ssh_context().get_directory_contents(domain_path, False)
        #     file_list = self._cmd_helper.filter_top_dir(file_list)
        # elif os.path.isdir(domain_path):
        #     # file_list = os.listdir(domain_path)
        #     file_list.append(domain_path)
        # if archive:
        #     try:
        #         for entry_path in file_list:
        #             if self._model_context.is_ssh():
        #                 entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,entry_path,
        #                                                                                ssh_download_dir,
        #                                                                                "domain_home")
        #
        #             archive.addCustomEntry(entry_path,"domain_home"+domain_path, True)
        #             files_added=True
        #             # entries.append(updated_name)
        #     except WLSDeployArchiveIOException, wioe:
        #         de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
        #                                                         wioe.getLocalizedMessage())
        #         _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
        #         raise de
        # else:
        #     # if -skip_archive or -remote, add to the remote map for manual addition
        #     self.add_to_remote_map(domain_path,
        #                            "java_home",
        #                            WLSDeployArchive.ArchiveEntryType.CUSTOM.name())


        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __process_weblogic_home(self, domain_name, weblogic_home, ssh_download_dir):
        _method_name="__process_weblogic_home"
        _logger.entering(self._machine, weblogic_home, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)
        suffix="weblogic_home"
        #TODO add env variable to chane location --outputdir
        archive_file_name = '%s-%s-%s.zip' % (self._machine, domain_name, suffix)
        self.__archive_directory(weblogic_home,archive_file_name,ssh_download_dir,suffix)
        #
        #
        # archive_dir_name = self.path_helper.get_local_parent_directory(archive_file_name)
        # if not os.path.exists(archive_dir_name):
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06026', archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # # Delete any existing archive file for discoverDomain so that we always start with a fresh zip file.
        # archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        # if archive_file_obj.exists() and not archive_file_obj.delete():
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
        #                                                _program_name, archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # try:
        #     archive = WLSDeployArchive(archive_file_name)
        # except (IllegalArgumentException, IllegalStateException), ie:
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06013', _program_name, archive_file_name,
        #                                                ie.getLocalizedMessage(), error=ie)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        # files_added=False
        # file_list = []
        # if self._model_context.is_ssh():
        #     file_list = self._model_context.get_ssh_context().get_directory_contents(weblogic_home, False)
        #     file_list = self._cmd_helper.filter_top_dir(file_list)
        # elif os.path.isdir(weblogic_home):
        #     # file_list = os.listdir(weblogic_home)
        #     file_list.append(weblogic_home)
        # if archive:
        #     for entry_path in file_list:
        #         try:
        #             if self._model_context.is_ssh():
        #                 entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,entry_path,
        #                                                                                ssh_download_dir,
        #                                                                                suffix)
        #
        #             archive.addCustomEntry(entry_path, '%s%s' % (suffix, weblogic_home), True)
        #             files_added=True
        #             # entries.append(updated_name)
        #         except WLSDeployArchiveIOException, wioe:
        #             de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
        #                                                             wioe.getLocalizedMessage())
        #             _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
        #             raise de
        #
        #     # if files_added:
        #     #     self.__remove_files_directories_from_archive(archive)
        #
        # else:
        #     # if -skip_archive or -remote, add to the remote map for manual addition
        #     self.add_to_remote_map(weblogic_home,
        #                            suffix,
        #                            WLSDeployArchive.ArchiveEntryType.CUSTOM.name())


        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __process_custom_directories(self, domain_name, extra_directories, ssh_download_dir):
        _method_name="__process_custom_directory"
        suffix="extra_dirs"
        _logger.entering(domain_name, suffix, extra_directories,
                              class_name=_class_name, method_name=_method_name)
        #TODO add env variable to chane location --outputdir

        archive_file_name = '%s-%s-%s.zip' % (self._machine, domain_name, suffix)
        self.__archive_directory(extra_directories,archive_file_name,ssh_download_dir,suffix)
        #
        # archive_dir_name = self.path_helper.get_local_parent_directory(archive_file_name)
        # if not os.path.exists(archive_dir_name):
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06026', archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # # Delete any existing archive file for discoverDomain so that we always start with a fresh zip file.
        # archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        # if archive_file_obj.exists() and not archive_file_obj.delete():
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
        #                                                _program_name, archive_file_name)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        #
        # try:
        #     archive = WLSDeployArchive(archive_file_name)
        # except (IllegalArgumentException, IllegalStateException), ie:
        #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
        #                                                'WLSDPLY-06013', _program_name, archive_file_name,
        #                                                ie.getLocalizedMessage(), error=ie)
        #     _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        #     raise ex
        # for dir in extra_directories:
        #     file_list = []
        #     if self._model_context.is_ssh():
        #         file_list = self._model_context.get_ssh_context().get_directory_contents(dir, False)
        #         file_list = self._cmd_helper.filter_top_dir(file_list)
        #     elif os.path.isdir(dir):
        #         # print("is_dir:"+dir)
        #         # file_list = os.listdir(dir)
        #         file_list.append(dir)
        #         # print(file_list)
        #     if archive:
        #         for entry_path in file_list:
        #             try:
        #                 if self._model_context.is_ssh():
        #                     entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,entry_path,
        #                                                                                    ssh_download_dir,
        #                                                                                    suffix)
        #
        #                 archive.addCustomEntry(entry_path, '%s%s' % (suffix, dir), True)
        #                 files_added=True
        #                 # entries.append(updated_name)
        #             except WLSDeployArchiveIOException, wioe:
        #                 de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
        #                                                                 wioe.getLocalizedMessage())
        #                 _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
        #                 raise de
        #
        #         # if files_added:
        #         #     self.__remove_files_directories_from_archive(archive)
        #
        #     else:
        #         # if -skip_archive or -remote, add to the remote map for manual addition
        #         self.add_to_remote_map(dir,
        #                                suffix,
        #                                WLSDeployArchive.ArchiveEntryType.CUSTOM.name())


        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __archive_directory(self,path, archive_file_name,ssh_download_dir,path_key ):
        _method_name="__archive_directory"
        _logger.entering(self._machine, path, ssh_download_dir,
                         class_name=_class_name, method_name=_method_name)
        archive_dir_name = self.path_helper.get_local_parent_directory(archive_file_name)
        if not os.path.exists(archive_dir_name):
            ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                       'WLSDPLY-06026', archive_file_name)
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

        # Delete any existing archive file for discoverDomain so that we always start with a fresh zip file.
        archive_file_obj = FileUtils.getCanonicalFile(archive_file_name)
        if archive_file_obj.exists() and not archive_file_obj.delete():
            ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06047',
                                                       _program_name, archive_file_name)
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

        try:
            archive = WLSDeployArchive(archive_file_name)
        except (IllegalArgumentException, IllegalStateException), ie:
            ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                       'WLSDPLY-06013', _program_name, archive_file_name,
                                                       ie.getLocalizedMessage(), error=ie)
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

        files_added=False
        extra_directories=[]
        if isinstance(path, basestring):
            extra_directories.append(path)
        else:
            extra_directories=path
        for dir in extra_directories:
            file_list = []
            if self._model_context.is_ssh():
                file_list = self._model_context.get_ssh_context().get_directory_contents(path, False)
                file_list = self._cmd_helper.filter_top_dir(file_list)
            elif os.path.isdir(dir):
                # print("is_dir:"+dir)
                # file_list = os.listdir(dir)
                file_list.append(dir)
                # print(file_list)
            if archive:
                try:
                    for entry_path in file_list:
                        if self._model_context.is_ssh():
                            entry_path = self._cmd_helper.download_file_from_remote_server(self._model_context,entry_path,
                                                                                       ssh_download_dir,
                                                                                       path_key)

                        archive.addCustomEntry(entry_path, '%s%s' % (path_key, path), True)
                        files_added=True

                    return files_added,archive
                except WLSDeployArchiveIOException, wioe:
                    de = exception_helper.create_discover_exception('WLSDPLY-06421', entry_path,
                                                                    wioe.getLocalizedMessage())
                    _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
                    raise de

            else:
                # if -skip_archive or -remote, add to the remote map for manual addition
                self.add_to_remote_map(path,
                                       path_key,
                                       WLSDeployArchive.ArchiveEntryType.CUSTOM.name())

        _logger.exiting(class_name=_class_name, method_name=_method_name)

    def __remove_files_directories_from_archive(self, archive_file):
            _method_name="_remove_files_directories_from_archive"
            file_list = archive_file.listCustomFiles()
            # filter files by regexp
            #Default file exclusions
            # server_home/data/nodemanager/*.lck
            # server_home/*/adr/diag/ofm/*/*/lck/*.lck

            # server_home/data/nodemanager/*.pid
            # server_home/tmp
            # server_home/data/nodemanager/*.state
            # Todo: Exclude core dumps.  Research.
            # Todo:  Jul 25th
            # server_home/*/adr/oracle-dfw-*/sampling/jvm_threads*
            # server_home/tmp
            # _lock_regex = re.compile('-D([a-zA-Z0-9-_.]+ ?)(=([\S]+ ?))?')
            # __sys_props_regex = re.compile('-D([a-zA-Z0-9-_.]+ ?)(=([\S]+ ?))?')
            # exclude_logs_dir_regexp='^.*/logs/.*'
            # exclude_filters=exclude_logs_dir_regexp
            exclude_filters='^(.*/logs/.*)|^(.*/sampling/jvm_threads.*)|^(.*/servers/.*/tmp)'
            regex = re.compile(exclude_filters,re.IGNORECASE)
            for file_or_dir in file_list:
                # hack for now.
                file_or_dir = file_or_dir[len("wlsdeploy/custom/")::]
                print("JOI: file in the list: "+file_or_dir)
                if file_or_dir.lower().endswith(".lck") or file_or_dir.lower().endswith(".pid") or file_or_dir.lower().endswith(".state"):
                    print("JOI: match ending in lck, pid, state"+file_or_dir)
                    archive_file.removeCustomEntry(file_or_dir,True)
                    continue
                if file_or_dir.lower().endswith(".log") or "tmp" in file_or_dir.lower():
                    print("JOI: match ending in log and tmp"+file_or_dir)
                    archive_file.removeCustomEntry(file_or_dir,True)
                    continue
                if regex.match(file_or_dir):
                    print("JOI: pattern found a match"+file_or_dir)
                    archive_file.removeCustomEntry(file_or_dir,True)
                    continue

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