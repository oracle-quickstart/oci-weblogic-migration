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

class WLSInstance(object):
    """
        Class that serves as the navigation context during model processing.
        """

    def __init__(self, hostname=None):
        """
        Creates a new instance of the object that serves as the
        navigation context during model processing.

        If ``another_location`` is None, then an empty list is
        stored in the list.
        :param another_location: list of folder names that are part of the model
        """
        if (hostname is None):
            self._hostname = ""
        else:
            self._hostname = hostname

        self._ip = "0.0.0.0/32"
        self._user = "oracle"
        self._group = "oinstall"
        self._fs = dict()


    def add_filesystem(self, name, value):
        """
        Adds a filesystem-value pair to the list of filesystems.
        :param name: string Name to use for filesystem
        :param value: filesystem path
        :return: self, for method chaining
        """
        self._fs[name] = value
        return self

