"""
Copyright (c) 2017, 2019, Oracle Corporation and/or its affiliates.  All rights reserved.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))

import infra_constants
from migration_discoverer_NOT_USED import MigrationDiscoverer
from infra_constants import Owner


sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))

from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging import platform_logger
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.tool.discover.discoverer import Discoverer
from wlsdeploy.aliases import model_constants
from wlsdeploy.tool.util.wlst_helper import WlstHelper

from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict


sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))

_class_name = 'InfraDiscoverer'
_logger = platform_logger.PlatformLogger(discoverer.get_discover_logger_name())



class WLSDiscoverer(MigrationDiscoverer):
    """
    Discover the topology part of the model. The resulting data dictionary describes the topology of the domain,
    including clusters, servers, server templates, machines and migratable targets,
    """

    def __init__(self, model_context, deployments_dictionary, base_location,
                 wlst_mode=WlstModes.OFFLINE, aliases=None, credential_injector=None, extra_tokens=None):
        """
        Instantiate an instance of the TopologyDiscoverer class with the runtime information provided by
        the init parameters.
        :param model_context: containing the arguments for this discover
        :param topology_dictionary: dictionary in which to add discovered topology information
        :param wlst_mode: indicates whether this discover is run in online or offline mode
        """
        MigrationDiscoverer.__init__(self, model_context, base_location, wlst_mode)
        self._dictionary = deployments_dictionary



    def discover(self):
        """
        Discover the clusters, servers and machines that describe the domain's topology and return
        the resulting topology data dictionary. Add any pertinent libraries referenced by a server's
        start classpath to the archive file.
        :return: topology data dictionary
        """
        _method_name = 'discover'
        _logger.entering(class_name=_class_name, method_name=_method_name)

        _logger.info('WLSDPLY-06600', class_name=_class_name, method_name=_method_name)

        model_top_folder_name, host = self.get_domain_home()
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, host)

        # Todo include path from discovered domain model.  this is required to get wls onwer
        # model_top_folder_name, host = self.get_fs_details(self._dictionary[model_constants.PATH])
        model_top_folder_name, fs_shared = self.get_fs_details("/u01")
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, fs_shared)

        # model_top_folder_name, host = self.get_owner_details(self._dictionary[model_constants.PATH])
        model_top_folder_name, owner = self.get_weblogic_owner_details("/u01")
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, owner)

        # _logger.info('WLSDPLY-06311', len(coherence_clusters), class_name=_class_name, method_name=_method_name)

        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return self._dictionary, self._security_provider_map

    def get_host_details(self):
        """
        Discover hostname, ip, and extras.
        :return: model name for the dictionary and the dictionary containing the shared library information
        """
        _method_name = 'get_host_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        #Todo get IP  # get Hostname
        result = self.get_server_details()
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=infra_constants.HOSTING_SERVER_KEY)
        return  infra_constants.DETAILS_KEY,result

    def get_fs_details(self, wls_directory):
        _method_name = 'get_fs_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        # result = OrderedDict()
        # for each path, check if it is df /home/aland/ -t nfs
        # if found then set to shared.  add fs  infra_constants.
        #
        #
        #
        fs_details=self.is_fs_shared(wls_directory)

        _logger.exiting(class_name=_class_name, method_name=_method_name, result=fs_details)
        return infra_constants.FILESYSTEM_TYPE, fs_details

    def get_weblogic_owner_details(self,wls_path):
        _method_name = 'get_weblogic_owner_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        # result = OrderedDict()
        # # get home : home_dir = os.path.expanduser("~")
        # # get User, get Group, get
        # # get Hostname
        # user=None
        # g_id=None
        # u_id=None
        # g_name=None
        # home_dir= os.path.expanduser("~")
        # owner=Owner(u_id,user,g_id,g_name, home_dir)
        # result.add owner
        result=self.get_owner(wls_path)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=result)
        return infra_constants.OWNER, result

