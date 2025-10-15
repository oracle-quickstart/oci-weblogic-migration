"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

"""
import os
import sys

from java.lang import IllegalArgumentException

from oracle.weblogic.deploy.discover import DiscoverException
from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict
from oracle.weblogic.deploy.util import PyWLSTException
from oracle.weblogic.deploy.util import StringUtils
from oracle.weblogic.deploy.util import WLSDeployArchive
from oracle.weblogic.deploy.util import WLSDeployArchiveIOException

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))

import infra_constants

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))


from wlsdeploy.aliases import alias_utils
from wlsdeploy.aliases import model_constants
from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.aliases.model_constants import MODEL_LIST_DELIMITER
from wlsdeploy.aliases.model_constants import KSS_KEYSTORE_FILE_INDICATOR
from wlsdeploy.aliases.model_constants import UNIX_MACHINE_ATTRIBUTE
from wlsdeploy.aliases.validation_codes import ValidationCodes
from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.tool.discover.discoverer import Discoverer
from wlsdeploy.tool.discover.topology_discoverer import TopologyDiscoverer
from wlsdeploy.tool.util.saml2_security_helper import Saml2SecurityHelper
from wlsdeploy.tool.util.variable_injector import VARIABLE_SEP
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.util import dictionary_utils
from wlsdeploy.util import string_utils
import wlsdeploy.util.unicode_helper as str_helper


_class_name = 'LiftNShiftTopologyDiscoverer'
_logger = PlatformLogger(discoverer.get_discover_logger_name())

# TODO(joi)  revisit if Override is needed.  Specially method discoverer to perform directly mapping.
class LiftNShiftTopologyDiscoverer(TopologyDiscoverer):
    """
    Discover the topology part of the model. The resulting data dictionary describes the topology of the domain,
    including clusters, servers, server templates, machines and migratable targets,
    """

    def __init__(self, model_context, topology_dictionary, base_location,
                 wlst_mode=WlstModes.OFFLINE, aliases=None, credential_injector=None):
        """
        Instantiate an instance of the TopologyDiscoverer class with the runtime information provided by
        the init parameters.
        :param model_context: containing the arguments for this discover
        :param topology_dictionary: dictionary in which to add discovered topology information
        :param wlst_mode: indicates whether this discover is run in online or offline mode
        """
        TopologyDiscoverer.__init__(self, model_context, topology_dictionary, base_location, wlst_mode, aliases, credential_injector)
        # self._dictionary = topology_dictionary
        # self._add_att_handler(model_constants.CLASSPATH, self._add_classpath_libraries_to_archive)
        # self._add_att_handler(model_constants.CREATE_TABLE_DDL_FILE,
        #                       self._add_jdbc_transaction_log_create_table_ddl_file_to_archive)
        # self._add_att_handler(model_constants.CUSTOM_IDENTITY_KEYSTORE_FILE, self._add_keystore_file_to_archive)
        # self._add_att_handler(model_constants.CUSTOM_TRUST_KEYSTORE_FILE, self._add_keystore_file_to_archive)
        self._add_att_handler(infra_constants.ORACLE_HOME_DIR,self._add_classpath_libraries_to_archive)
        self._add_att_handler(infra_constants.DOMAIN_HOME_DIR, self._add_classpath_libraries_to_archive)
        # self._wlst_helper = WlstHelper(ExceptionType.DISCOVER)

    # TODO(joi)  override method or add add_att..
    def _add_classpath_libraries_to_archive(self, model_name, model_value, location):
        """
        This is a private method.

        Add the server files and directories listed in the server classpath attribute to the archive file.
        File locations in the oracle_home will be removed from the classpath and will not be added to the archive file.
        :param model_name: attribute for the server's server start classpath attribute
        :param model_value: classpath value in domain
        :param location: context containing current location information
        :return model
        """
        _method_name = 'add_classpath_libraries_to_archive'
        server_name = self._get_server_name_from_location(location)
        # _logger.entering(server_name, model_name, model_value, class_name=_class_name, method_name=_method_name)
        _logger.entering(server_name, model_name, model_value, "JOI--",class_name=_class_name, method_name=_method_name)
        classpath_string = None
        if not StringUtils.isEmpty(model_value):
            # model values are comma-separated
            classpath_entries = model_value.split(MODEL_LIST_DELIMITER)

            if classpath_entries:
                classpath_list = []
                for classpath_entry in classpath_entries:
                    _logger.entering(classpath_entry, model_name, model_value, "JOI--classpath_entry", class_name=_class_name,
                                     method_name=_method_name)
                    classpath_entry = self._model_context.replace_token_string(classpath_entry)
                    _logger.entering(classpath_entry, model_name, model_value, "JOI--classpath_entryReplaced",
                                     class_name=_class_name,
                                     method_name=_method_name)
                    new_source_name = self._add_library(server_name, classpath_entry)
                    if new_source_name is not None:
                        classpath_list.append(new_source_name)

                classpath_string = StringUtils.getStringFromList(classpath_list, MODEL_LIST_DELIMITER)
                _logger.fine('WLSDPLY-06617', server_name, classpath_string, class_name=_class_name,
                             method_name=_method_name)

        _logger.exiting(class_name=_class_name, method_name=_method_name, result=classpath_string)
        return classpath_string

    def _add_library(self, server_name, classpath_name):
        """
        This is a private method.

        Collect the binary and directories from the classpath string into the archive file.
        If the binary or directory cannot be collected into the archive file, the entry will remain in the
        classpath string, but a warning will be logged about the problem.
        :param server_name: for the classpath files being collected
        :param classpath_name: string containing the classpath entries
        :return: original name modified for the new location and tokenized
        """
        _method_name = '_add_library'
        _logger.entering(server_name, classpath_name, class_name=_class_name, method_name=_method_name)
        return_name = classpath_name
        if self._is_file_to_exclude_from_archive(classpath_name):
            _logger.info('WLSDPLY-06618', classpath_name, server_name, class_name=_class_name, method_name=_method_name)
            return_name = self._model_context.tokenize_path(classpath_name)
        else:
            _logger.finer('WLSDPLY-06619', classpath_name, server_name, class_name=_class_name,
                          method_name=_method_name)
            archive_file = self._model_context.get_archive_file()
            file_name_path = classpath_name
            if not self._model_context.is_remote():
                file_name_path = self._convert_path(classpath_name)
            new_source_name = None
            if self._model_context.is_remote():
                new_source_name = WLSDeployArchive.getClasspathArchivePath(file_name_path)
                _logger.entering(new_source_name, model_name, model_value, "JOI--new_source_name",
                                 class_name=_class_name,
                                 method_name=_method_name)
                self.add_to_remote_map(file_name_path, new_source_name,
                                       WLSDeployArchive.ArchiveEntryType.CLASSPATH_LIB.name())
            elif not self._model_context.is_skip_archive():
                try:
                    if self._model_context.is_ssh():
                        file_name_path = self.download_deployment_from_remote_server(file_name_path,
                                                                                      self.download_temporary_dir,
                                                                                      "classPathLibraries")


                    new_source_name = archive_file.addClasspathLibrary(file_name_path)
                except IllegalArgumentException, iae:
                    _logger.warning('WLSDPLY-06620', server_name, file_name_path, iae.getLocalizedMessage(),
                                    class_name=_class_name, method_name=_method_name, error=iae)
                except WLSDeployArchiveIOException, wioe:
                    de = exception_helper.create_discover_exception('WLSDPLY-06621', server_name, file_name_path,
                                                                    wioe.getLocalizedMessage(), error=wioe)
                    _logger.throwing(class_name=_class_name, method_name=_method_name, error=de)
                    raise de
            if new_source_name is not None:
                return_name = new_source_name
        _logger.exiting(class_name=_class_name, method_name=_method_name, result=return_name)
        return return_name