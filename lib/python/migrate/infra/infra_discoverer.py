"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl
"""
import os
import sys
import re
import tempfile

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
from wlsdeploy.util import dictionary_utils
from wlsdeploy.util import model_helper
from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.aliases.model_constants import APPLICATION
from wlsdeploy.aliases.model_constants import LIBRARY
from wlsdeploy.aliases.model_constants import MODULE_TYPE
from wlsdeploy.aliases.model_constants import SOURCE_PATH
from wlsdeploy.aliases.model_constants import PLAN_DIR
from wlsdeploy.aliases.model_constants import PLAN_PATH
from wlsdeploy.aliases.model_constants import SERVER
from wlsdeploy.aliases.model_constants import TOPOLOGY
from wlsdeploy.aliases.model_constants import MACHINE
from wlsdeploy.aliases.model_constants import CUSTOM_IDENTITY_KEYSTORE_FILE
from wlsdeploy.aliases.model_constants import CUSTOM_TRUST_KEYSTORE_FILE
from wlsdeploy.aliases.model_constants import SSL

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

    def __init__(self, model_context, deployments_dictionary, base_location, discovered_model,
                machine_to_discover,wlst_mode=WlstModes.OFFLINE, aliases=None, credential_injector=None, extra_tokens=None):
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
        self._os_helper = RemoteUnixCommandLineHelper()
        ssh_context = model_context.get_ssh_context()
        if self._model_context.is_ssh():
            if ssh_context.is_windows:
                # Todo :  Add WindowsCommandLineHelper
                self._os_helper = RemoteUnixCommandLineHelper()
        self._cmd_helper=CommandHelper(model_context.is_ssh(), self._os_helper, ssh_context)
        self.machine=machine_to_discover

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
        app_deployments = self._discovered_model.get_model_app_deployments()
        if string_utils.is_empty(domain_path)  or string_utils.is_empty(domain_name):
            ex = exception_helper.create_discover_exception('WLSDPLY-06023')
            _logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex

        _logger.finest("WLSDPLY-06102", oracle_path, domain_path)
        #unique_paths contains a list of filesystem directory paths that were already discovered. such us jdk /opt/jdk, domain_homes /opt/domains/mydomain
        unique_paths = list()
        unique_paths.append(domain_path)
        unique_paths.append(oracle_path)


        model_top_folder_name, host = self.get_host_details()
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, host)

        # Find if domain_path is on a shared mount or volume
        # Not in v1.
        # model_top_folder_name, fs_shared = self.get_fs_details(domain_path)
        # discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, fs_shared)

        # Adds OS user, OS group (if linux) weblogic domain directory owner
        model_top_folder_name, owner = self.get_weblogic_owner_details(domain_path)
        discoverer.add_to_model_if_not_empty(self._dictionary, model_top_folder_name, owner)


        # Find all jvms running and filter by domain_name
        all_running_jvms = self._find_running_jvms()

        # Discover node_mgr_jvm.  Should only be one.
        node_mgr_jvm= self._discover_node_manager(all_running_jvms, domain_name)
        # discoverer.add_to_model(self._dictionary, infra_constants.NM_VM, node_mgr_jvm)
        discoverer.add_to_model(self._dictionary, infra_constants.NM_VM, [jvm.get_arguments_string() for jvm in node_mgr_jvm])



        # Discover admin or wls jvm.
        wls_servers_jvm=self._discover_weblogic_server_jvms(all_running_jvms)
        domain_only_jvms = self._get_domain_jvms(wls_servers_jvm,domain_name)
        discoverer.add_to_model(self._dictionary, infra_constants.WLS_SERVER_VM, [jvm.get_arguments_string() for jvm in domain_only_jvms])

        # find jdk_home
        model_top_folder_name, jdk_home = self.find_jdk_homes(all_running_jvms)
        unique_paths.append(jdk_home)
        discoverer.add_to_model(self._dictionary, model_top_folder_name, jdk_home)

        # find canonical_jdk_path
        model_top_folder_name, canonical_jdk_path = self.find_canonical_jdk_path(jdk_home)
        unique_paths.append(canonical_jdk_path)
        discoverer.add_to_model(self._dictionary, model_top_folder_name, canonical_jdk_path)

        domain_jvms=node_mgr_jvm + domain_only_jvms

        model_top_folder_name, fs = self.find_wls_extra_dir(app_deployments=app_deployments , jvms=domain_jvms,exclude_paths=unique_paths, domain_name=domain_name)


        discoverer.add_to_model(self._dictionary, model_top_folder_name, fs)

        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return self._dictionary

    def _discover_weblogic_server_jvms(self,jvms):
        return self._cmd_helper.get_weblogic_server_processes(jvms)

    def _discover_node_manager(self,jvms, domain_name):
        _method_name="_discover_node_manager"
        _logger.entering(class_name=_class_name, method_name=_method_name)
        nm_jvms=self._cmd_helper.get_node_manager_vm(jvms)
        if len(nm_jvms) == 0:
            #TODO if empty, attempt to look it other way?
            _logger.info("No Node Manager found",class_name=_class_name, method_name=_method_name)
            return infra_constants.EMPTY_ARRAY
        if len(nm_jvms) == 1 :
            #Assume this is a single node manager per host
            _logger.exiting(class_name=_class_name, method_name=_method_name)
            return nm_jvms
        else:
            #Attempt to filter by domain_name.
            expr = r'%s(.*)%s' % (domain_name,infra_constants.NM_JAVA_PROCESS_KEY)
            nm_jvms=self._cmd_helper.filter_jvms_by_key(nm_jvms,expr)
        _logger.exiting(class_name=_class_name, method_name=_method_name)
        return nm_jvms

    def _get_domain_jvms(self,jvms, domain_name):
        # expr = r'%s(.*)%s' % (infra_constants.JAVA_PROCESS_KEY, domain_name)
        expr = r'%s(.*)' % domain_name
        return self._cmd_helper.filter_jvms_by_key(jvms,expr)

    def _find_running_jvms(self):
        return self._cmd_helper.get_java_processes()

    def find_jdk_homes(self,jvms):
        jdk_homes = self._cmd_helper.get_unique_java_homes(jvms)
        return infra_constants.JAVA_DIR,jdk_homes

    def find_canonical_jdk_path(self,jdk_home):
        """
        :param jdk_home: path to the JDK home
        :return: constant representing the canonical JDK path and canonical JDK path
        """
        jdk_home = self._cmd_helper.get_canonical_path(jdk_home)
        return infra_constants.CANONICAL_JAVA_DIR,jdk_home

    def get_host_details(self):
        """
        Discover hostname, ip, and extras.
        :return: infra_constants.DETAILS_KEY, result containing hostname, ip, and extras.
        """
        _method_name = 'get_host_details'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        result = self._cmd_helper.get_server_details()
        hostname= self._cmd_helper.get_server_hostname()
        result[infra_constants.HOSTING_SERVER_KEY]=hostname
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=hostname)
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

    #Takes App_Deployments, jvms, and filesystem paths to be excluded due to mass archiving like Oracle_home, jvm_home and creates a list of
    # custom directories to archive.
    def find_wls_extra_dir(self, app_deployments, jvms, exclude_paths, domain_name):
        _method_name = 'find_wls_extra_dir'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        extra_dirs=[]
        if app_deployments is not None and not self._model_context.is_ssh():
            # get Library and Application
            # for each element inside Library and Application get Attribute SourcePath
            # if SourcePath is not None: (found)
            #    if SourcePath startswith @@ORACLE_HOME@@   - ignore as this will be included in Middleware Archive
            #    if SourcePath is a full path - starts /   -
            #       then check if it does not start with domain_path or oracle_path add it to the list.
            #            extra_dirs.append(SourcePath)
            libraries = app_deployments[model_constants.LIBRARY]
            applications = app_deployments[model_constants.APPLICATION]
            _logger.fine('appDeployments found. Applications deployed? {0}',
                         applications,class_name=_class_name,method_name=_method_name)
            for application_name in applications or []:
                application=dictionary_utils.get_dictionary_element(applications, application_name)
                deployment_source_path = dictionary_utils.get_element(application, SOURCE_PATH)
                is_custom_path,custom_path = self._is_custom_dir(deployment_source_path)
                _logger.fine('application {0}, source path {1} , custom_path {2}',
                             application_name, deployment_source_path, custom_path,class_name=_class_name,method_name=_method_name)
                if is_custom_path:
                    extra_dirs.append(custom_path)
                deployment_plan_path= self._get_combined_model_plan_path(application)
                is_custom_path,custom_path = self._is_custom_dir(deployment_plan_path)
                if is_custom_path:
                    extra_dirs.append(custom_path)

           # Clean duplicated paths.

        if len(jvms) > 0:
            jvm_paths=self._cmd_helper.get_unique_paths_in_jvms(jvms, exclude_paths)
            extra_dirs = extra_dirs + jvm_paths

        #"managedserver1" : {
        #   "SSL" : {
        #       "TrustedCAFileName" : "/u01/data/keystores/trust.p12",

        #   "CustomIdentityKeyStoreFileName" : "/opt/domains/keystores/identity.p12",
        #   "AdministrationPortEnabled" : true,
        #   "Machine" : "machinename1",
        #   "KeyStores" : "CustomIdentityAndCustomTrust",
        #   "CustomIdentityKeyStoreType" : "PKCS12",
        #   "CustomTrustKeyStoreFileName" : "/opt/domains/keystores/trust.p12",
        security_configuration_extra_dirs = OrderedDict()
        # topology_folder = dictionary_utils.get_dictionary_element(self._discovered_model, TOPOLOGY)
        topology_folder = self._discovered_model.get_model_topology()
        servers_folder = dictionary_utils.get_dictionary_element(topology_folder, SERVER)
        _logger.fine("server folder servers {0}",servers_folder,class_name=_class_name, method_name=_method_name)
        for server in servers_folder:
            _logger.fine("found a server",class_name=_class_name, method_name=_method_name)
            machine_folder = servers_folder[server]
            machine_name = dictionary_utils.get_element(machine_folder, MACHINE)
            if machine_name and (machine_name == self.machine ):
                _logger.fine("found a machine match {0}",machine_name,class_name=_class_name, method_name=_method_name)
                custom_identity_keystore_file_name = dictionary_utils.get_element(machine_folder, CUSTOM_IDENTITY_KEYSTORE_FILE)
                custom_trust_keystore_file = dictionary_utils.get_element(machine_folder, CUSTOM_TRUST_KEYSTORE_FILE)
                is_custom_path,custom_path = self._is_custom_dir(custom_trust_keystore_file)
                _logger.fine("found a extra dir in trust_keystore? {0}",custom_path,class_name=_class_name, method_name=_method_name)
                if is_custom_path:
                    discoverer.add_to_model(security_configuration_extra_dirs,custom_path, CUSTOM_IDENTITY_KEYSTORE_FILE)
                is_custom_path,custom_path = self._is_custom_dir(custom_identity_keystore_file_name)
                _logger.fine("found a extra dir in identity keystore? {0}",custom_path,class_name=_class_name, method_name=_method_name)
                if is_custom_path:
                    discoverer.add_to_model(security_configuration_extra_dirs,custom_path, CUSTOM_TRUST_KEYSTORE_FILE)
                _logger.fine("found a extra dir in CAFileName? {0}",custom_path,class_name=_class_name, method_name=_method_name)
                ssl_folder = dictionary_utils.get_dictionary_element(machine_folder, SSL)
                trusted_ca_file = dictionary_utils.get_element(ssl_folder, "TrustedCAFileName")
                is_custom_path,custom_path = self._is_custom_dir(trusted_ca_file)
                _logger.fine("found a extra dir in Trusted CA FileName? {0}",custom_path,class_name=_class_name, method_name=_method_name)
                if is_custom_path:
                    discoverer.add_to_model(security_configuration_extra_dirs,custom_path, CUSTOM_TRUST_KEYSTORE_FILE)
                _logger.fine("extra dirs list ? {0}",security_configuration_extra_dirs,class_name=_class_name, method_name=_method_name)
                unique_paths = [path for path in security_configuration_extra_dirs.iterkeys()]
                _logger.fine("extra dirs unique list ? {0}",unique_paths,class_name=_class_name, method_name=_method_name)
                extra_dirs = extra_dirs + unique_paths

        extra_dirs=self._cmd_helper.get_unique_paths(extra_dirs)
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=extra_dirs)
        return infra_constants.FILESYSTEM, extra_dirs

    def _is_custom_dir(self,string_value):
        _method_name = '_is_custom_dir'
        _logger.entering(class_name=_class_name, method_name=_method_name)
        _path_helper = path_helper.get_path_helper()
        path=""
        result = False
        if string_value is None:
            result = False
        elif string_value.startswith(self._model_context.ORACLE_HOME_TOKEN):
            result = False
        elif string_value.startswith(self._model_context.WL_HOME_TOKEN):
            result = False
        elif string_value.startswith(self._model_context.DOMAIN_HOME_TOKEN):
            result = False
        elif string_value.startswith(self._model_context.JAVA_HOME_TOKEN):
            result = False
        elif string_value.startswith(self._model_context.CURRENT_DIRECTORY_TOKEN):
            result = False
        elif string_value.startswith(self._model_context.TEMP_DIRECTORY_TOKEN):
            result = True
            path=self._model_context.replace_token_string(string_value)
            parent_dir_name = _path_helper.get_parent_directory(path)
            path=parent_dir_name
        elif _path_helper.is_relative_local_path(string_value):
            result = False
        elif _path_helper.is_absolute_path(string_value):
            result = True
            parent_dir_name = _path_helper.get_parent_directory(string_value)
            path=parent_dir_name
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=path)
        return result, path



    # def _replace_path_tokens_for_deployment(self, deployment_type, deployment_name, deployment_dict):
    #     _method_name = '_replace_path_tokens_for_deployment'
    #     _logger.entering(deployment_type, deployment_name, deployment_dict,
    #                          class_name=self._class_name, method_name=_method_name)
    #
    #     self.model_context.replace_tokens(deployment_type, deployment_name, SOURCE_PATH, deployment_dict)
    #     self.model_context.replace_tokens(deployment_type, deployment_name, PLAN_DIR, deployment_dict)
    #     self.model_context.replace_tokens(deployment_type, deployment_name, PLAN_PATH, deployment_dict)
    #
    #     self.logger.exiting(class_name=self._class_name, method_name=_method_name)

    def _get_combined_model_plan_path(self, application_dict):
        """
        Combine the PlanDir and PlanPath attributes from the model dictionary
        to create a single path.
        :param deployment_dict: a model deployment dictionary
        :return: a full path for deployment plan
        """
        _method_name = '_get_combined_model_plan_path'
        _logger.entering(application_dict, class_name=_class_name, method_name=_method_name)
        _path_helper = path_helper.get_path_helper()
        plan_dir = dictionary_utils.get_element(application_dict, PLAN_DIR)
        plan_path = dictionary_utils.get_element(application_dict, PLAN_PATH)

        full_path = None
        if not string_utils.is_empty(plan_path):
            if string_utils.is_empty(plan_dir):
                full_path = plan_path
            else:
                # not an archive location...
                full_path = _path_helper.local_join(plan_dir, plan_path)

        _logger.exiting(class_name=_class_name, method_name=_method_name, result=full_path)
        return full_path