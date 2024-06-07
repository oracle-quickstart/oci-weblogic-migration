"""
Copyright (c) 2017, 2019, Oracle Corporation and/or its affiliates.  All rights reserved.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
"""
import os
import sys

from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict



sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))

import infra_constants
from remote.command_helper import CommandHelper
from infra_constants import Owner
from remote.command_line_helper import RemoteUnixCommandLineHelper

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))


from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging import platform_logger
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.tool.discover.discoverer import Discoverer
from wlsdeploy.aliases import model_constants
from wlsdeploy.util import path_helper
from wlsdeploy.util import string_utils
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.exception import exception_helper



_class_name = 'InfraDiscoverer'
_logger = platform_logger.PlatformLogger(discoverer.get_discover_logger_name())

remote_dict = OrderedDict()
REMOTE_TYPE = 'Type'
REMOTE_ARCHIVE_PATH = 'ArchivePath'

_ssh_download_dir = None

class InfraDiscoverer(Discoverer):
    """
    Discover the topology part of the model. The resulting data dictionary describes the topology of the domain,
    including clusters, servers, server templates, machines and migratable targets,
    """

    def __init__(self, model_context, deployments_dictionary, base_location, discovered_model
                 ,wlst_mode=WlstModes.OFFLINE, aliases=None, credential_injector=None, extra_tokens=None):
        """
        Instantiate an instance of the TopologyDiscoverer class with the runtime information provided by
        the init parameters.
        :param model_context: containing the arguments for this discover
        :param topology_dictionary: dictionary in which to add discovered topology information
        :param wlst_mode: indicates whether this discover is run in online or offline mode
        """
        Discoverer.__init__(self, model_context, base_location, wlst_mode)
        self._dictionary = deployments_dictionary
        self._discovered_model = discovered_model
        ssh_context = model_context.get_ssh_context()
        if self._model_context.is_ssh():
            if not ssh_context.is_windows:
                self._os_helper = RemoteUnixCommandLineHelper()
        self._cmd_helper=CommandHelper(model_context.is_ssh(), self._os_helper, ssh_context)


    def discover(self):
        """
        Discover the clusters, servers and machines that describe the domain's topology and return
        the resulting topology data dictionary. Add any pertinent libraries referenced by a server's
        start classpath to the archive file.
        :return: topology data dictionary
        """
        _method_name = 'discover'
        _logger.entering(class_name=_class_name, method_name=_method_name)

        domain_name = self._discovered_model.get_model_topology()[model_constants.DOMAIN_NAME]
        domain_path = self._discovered_model.get_model_topology()[infra_constants.DOMAIN_HOME_DIR]
        oracle_path = self._discovered_model.get_model_topology()[infra_constants.ORACLE_HOME_DIR] or self._model_context.get_oracle_home()

        if string_utils.is_empty(domain_path)  or string_utils.is_empty(domain_name):
            ex = exception_helper.create_discover_exception('WLSDPLY-06023')
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex
        _logger.finest("WLSDPLY-06102", oracle_path, domain_path)
        unique_paths = list()
        unique_paths.append(domain_path)
        unique_paths.append(oracle_path)

        # _logger.info('WLSDPLY-06600', class_name=_class_name, method_name=_method_name)
        model_top_folder_name, host = self.get_host_details()
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, host)

        # Find if domain_path is on a shared mount or volume
        # Not in v1.
        # model_top_folder_name, fs_shared = self.get_fs_details(domain_path)
        # discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, fs_shared)


        # Adds OS user, OS group (if linux) who owns weblogic domain directory
        model_top_folder_name, owner = self.get_weblogic_owner_details(domain_path)
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, owner)

        # # Adds OS user, OS group (if linux) who owns weblogic domain directory
        # model_top_folder_name, owner = self.get_weblogic_owner_details(self._model_context.get_model_home())
        # discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, owner)

        # Find all jvms running and filter by domain_name
        all_running_jvms = self._cmd_helper.get_java_processes(domain_name)

        model_top_folder_name, jdk_home = self.find_jdk_homes(all_running_jvms)

        unique_paths.append(jdk_home)
        discoverer.add_to_model(self._dictionary, model_top_folder_name, jdk_home)

        model_top_folder_name, fs = self.find_wls_extra_dir(all_running_jvms,unique_paths, domain_name)
        discoverer.add_to_model(self._dictionary, model_top_folder_name, fs)

        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return self._dictionary

    def find_jdk_homes(self,jvms):
        jdk_homes = self._cmd_helper.get_unique_java_homes(jvms)
        return infra_constants.JAVA_DIR,jdk_homes
    def get_host_details(self):
        """
        Discover hostname, ip, and extras.
        :return: model name for the dictionary and the dictionary containing the shared library information
        """
        _method_name = 'get_host_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        #Todo get IP  # get Hostname
        result = self._cmd_helper.get_server_details()
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return  infra_constants.DETAILS_KEY,result

    def get_fs_details(self, wls_directory):
        _method_name = 'get_fs_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        fs_details=self._cmd_helper.is_fs_shared(wls_directory)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=fs_details)
        return infra_constants.FILESYSTEM_TYPE, fs_details

    def get_weblogic_owner_details(self,wls_path):
        _method_name = 'get_weblogic_owner_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        result=self._cmd_helper.get_owner(wls_path)
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return infra_constants.OWNER, result

    def find_wls_extra_dir(self, jvms, exclude_paths, domain_name):
        _method_name = 'get_wls_extra_dir'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        if len(jvms) > 0:
                extra_dirs=self._cmd_helper.get_unique_paths_in_jvms(jvms, exclude_paths)
                _logger.exiting(class_name=_class_name, method_name=_method_name, result=extra_dirs)
                return infra_constants.FILESYSTEM, extra_dirs

