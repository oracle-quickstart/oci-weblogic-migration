"""
Copyright (c) 2017, 2024, Oracle and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
"""
import array
import sys
import os
import pwd

from java.io import IOException
from java.net import MalformedURLException
from java.net import URI
from java.net import URISyntaxException
from oracle.weblogic.deploy.aliases import AliasException
from oracle.weblogic.deploy.discover import DiscoverException
from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))

import infra_constants
from remote.command_line_helper import RemoteUnixCommandLineHelper

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))
from wlsdeploy.aliases import alias_constants
from wlsdeploy.aliases.aliases import Aliases
from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.aliases.model_constants import MASKED_PASSWORD
from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.tool.deploy import deployer_utils
from wlsdeploy.tool.discover.custom_folder_helper import CustomFolderHelper
from wlsdeploy.tool.encrypt import encryption_utils
from wlsdeploy.tool.util.mbean_utils import MBeanUtils
from wlsdeploy.tool.util.mbean_utils import get_interface_name
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.util import path_helper
from wlsdeploy.util import string_utils
import wlsdeploy.util.unicode_helper as str_helper
from wlsdeploy.tool.discover.discoverer import Discoverer

_DISCOVER_LOGGER_NAME = 'wlsdeploy.discover'

_class_name = 'MigrationDiscoverer'
_logger = PlatformLogger(_DISCOVER_LOGGER_NAME)

remote_dict = OrderedDict()
REMOTE_TYPE = 'Type'
REMOTE_ARCHIVE_PATH = 'ArchivePath'

_ssh_download_dir = None

# class MigrationDiscoverer(Discoverer):
#
#     """
#     Discoverer contains the private methods used to facilitate discovery of the domain information by its subclasses.
#     """
#
#     def __init__(self, model_context, topology_dictionary, base_location,
#                  wlst_mode=WlstModes.OFFLINE):
#         Discoverer.__init__(self, model_context, base_location, wlst_mode)
#         ssh_context = model_context.get_ssh_context()
#         if self._model_context.is_ssh():
#             if not ssh_context.is_windows:
#                 self._os_helper = RemoteUnixCommandLineHelper()
#
#     def get_server_details(self, server=None):
#         _method_name="get_server_details"
#         _logger.entering(class_name=_class_name, method_name=_method_name)
#         cmd = self._os_helper.get_hostname()
#         if self._model_context.is_ssh():
#             result=self._os_helper.get_single_result(self._run_command(cmd))
#             response=self._os_helper.unicode_to_string(result)
#             # _logger.info('WLSMIG-06311',error=type(response),class_name=_class_name, method_name=_method_name)
#         #     todo if reponse is == fail.  then raise exception
#         else:
#             import socket
#             response=socket.gethostname()
#         _logger.exiting(class_name=_class_name, method_name=_method_name, result=str(type(response)))
#         return response
#
#     def is_fs_shared(self,path):
#         _method_name = "is_fs_shared"
#         _logger.entering(class_name=_class_name, method_name=_method_name)
#         cmd=self._os_helper.get_fs_nfs_cmd(path)
#         result = OrderedDict()
#         result[infra_constants.FILESYSTEM]=path
#         if self._model_context.is_ssh():
#             response=self._run_command(cmd)
#             if len(response) > 0 :
#                 result[infra_constants.FILESYSTEM_TYPE]=infra_constants.FS_TYPE.SHARED
#             else:
#                 result[infra_constants.FILESYSTEM_TYPE]=infra_constants.FS_TYPE.VOLUME
#         else:
#             #todo this needs to be changed when running local.
#             result=self._os_helper.statdict(path)
#         #     todo if reponse is == FAIL.  then raise exception ?
#         _logger.exiting(class_name=_class_name, method_name=_method_name,result=result)
#         return result
#     def get_owner(self,path):
#         _method_name = "get_owner"
#         _logger.entering(class_name=_class_name, method_name=_method_name)
#         cmd=self._os_helper.get_user_details(path)
#         result=OrderedDict()
#         if self._model_context.is_ssh():
#             response=self._os_helper.get_single_result(self._run_command(cmd))
#             response=self._os_helper.unicode_to_string(response)
#             user_pair=response.split(infra_constants.COMMA_SEPARATOR)[0]
#             _logger.exiting(class_name=_class_name, method_name=_method_name, result=user_pair)
#             group_pair=response.split(infra_constants.COMMA_SEPARATOR)[1]
#             _logger.exiting(class_name=_class_name, method_name=_method_name, result=group_pair)
#             result[infra_constants.USER_ID]=user_pair.split(infra_constants.COLON_SEPARATOR)[0]
#             result[infra_constants.USERNAME]=user_pair.split(infra_constants.COLON_SEPARATOR)[1]
#             result[infra_constants.GROUP_ID] = group_pair.split(infra_constants.COLON_SEPARATOR)[0]
#             result[infra_constants.GROUP_NAME] = group_pair.split(infra_constants.COLON_SEPARATOR)[1]
#         else:
#             response=self._os_helper.statdict(path)
#             #     todo if reponse is == fail.  then raise exception
#             # response="running local"
#         _logger.exiting(class_name=_class_name, method_name=_method_name,result=result)
#         return result
#
#     def get_os_details(self):
#         _method_name = "get_os_details"
#         _logger.entering(class_name=_class_name, method_name=_method_name)
#         cmd = self._os_helper.get_user_details(path)
#         result = OrderedDict()
#         if self._model_context.is_ssh():
#             response = self._os_helper.get_single_result(self._run_command(cmd))
#             response = self._os_helper.unicode_to_string(response)
#             user_pair = response.split(infra_constants.COMMA_SEPARATOR)[0]
#             _logger.exiting(class_name=_class_name, method_name=_method_name, result=user_pair)
#             group_pair = response.split(infra_constants.COMMA_SEPARATOR)[1]
#             _logger.exiting(class_name=_class_name, method_name=_method_name, result=group_pair)
#             result[infra_constants.USER_ID] = user_pair.split(infra_constants.COLON_SEPARATOR)[0]
#             result[infra_constants.USERNAME] = user_pair.split(infra_constants.COLON_SEPARATOR)[1]
#             result[infra_constants.GROUP_ID] = group_pair.split(infra_constants.COLON_SEPARATOR)[0]
#             result[infra_constants.GROUP_NAME] = group_pair.split(infra_constants.COLON_SEPARATOR)[1]
#         else:
#             response = self._os_helper.statdict(path)
#             #     todo if reponse is == fail.  then raise exception
#             # response="running local"
#         _logger.exiting(class_name=_class_name, method_name=_method_name, result=result)
#         return result
#
#     def _run_command(self,cmd):
#         _method_name = "_run_command"
#         ssh_context=self._model_context.get_ssh_context()
#         exit_code,response=ssh_context._run_exec_command(cmd)
#         if exit_code == infra_constants.FAIL:
#              response = list()
#         return response
