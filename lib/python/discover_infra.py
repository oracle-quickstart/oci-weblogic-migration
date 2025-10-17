"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

The main module for the WebLogic Deploy tool to verify the user's SSH configuration is compatible with WDT.
"""
import os
import sys

from oracle.weblogic.deploy.util import SSHException
from oracle.weblogic.deploy.util import CLAException
from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import TranslateException
from oracle.weblogic.deploy.util import VariableException
from oracle.weblogic.deploy.validate import ValidateException
from oracle.weblogic.deploy.encrypt import EncryptionUtils


# from lib.python.migrate.infra.infra_discoverer import InfraDiscoverer

from java.io import File
from java.io import IOException
from java.lang import IllegalArgumentException
from java.lang import IllegalStateException
from java.lang import String
from java.lang import System

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))
from infra_discoverer import InfraDiscoverer
import infra_constants


sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))

from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.util.model import Model
from wlsdeploy.util import model_translator
from wlsdeploy.exception import exception_helper
from wlsdeploy.tool.util import model_context_helper
from wlsdeploy.tool.util import wlst_helper
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.util import path_helper

from wlsdeploy.util.cla_utils import CommandLineArgUtil
from wlsdeploy.util.cla_utils import TOOL_TYPE_DEFAULT
from wlsdeploy.util.exit_code import ExitCode
from wlsdeploy.util import env_helper
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.json import json_translator

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



wlst_helper.wlst_functions = globals()

_store_result_environment_variable = '__WLSDEPLOY_STORE_RESULT__'

_program_name = 'verifySSH'

# _class_name = 'verify_ssh'
_class_name = 'discover_infra'
__logger = PlatformLogger('wlsdeploy.tool.util')

result_dict = OrderedDict()
model_context_dict = OrderedDict()
__wlst_mode = WlstModes.OFFLINE
init_argument_map= None

__required_arguments = [
    CommandLineArgUtil.ORACLE_HOME_SWITCH,
    CommandLineArgUtil.MODEL_FILE_SWITCH,
    CommandLineArgUtil.ARCHIVE_FILE_SWITCH
]

__optional_arguments = [
    CommandLineArgUtil.SSH_PORT_SWITCH,
    CommandLineArgUtil.SSH_USER_SWITCH,
    CommandLineArgUtil.SSH_PASS_SWITCH,
    CommandLineArgUtil.SSH_PASS_ENV_SWITCH,
    CommandLineArgUtil.SSH_PASS_FILE_SWITCH,
    CommandLineArgUtil.SSH_PASS_PROMPT_SWITCH,
    CommandLineArgUtil.SSH_PRIVATE_KEY_SWITCH,
    CommandLineArgUtil.SSH_PRIVATE_KEY_PASSPHRASE_SWITCH,
    CommandLineArgUtil.SSH_PRIVATE_KEY_PASSPHRASE_ENV_SWITCH,
    CommandLineArgUtil.SSH_PRIVATE_KEY_PASSPHRASE_FILE_SWITCH,
    CommandLineArgUtil.SSH_PRIVATE_KEY_PASSPHRASE_PROMPT_SWITCH,
    CommandLineArgUtil.SSH_HOST_SWITCH,
]


def __process_args(args, is_encryption_supported):
    """
    Process the command-line arguments and prompt the user for any missing information
    :param args: the command-line arguments list
    ###:param is_encryption_supported: whether WDT encryption is supported by the JVM
    :raises CLAException: if an error occurs while validating and processing the command-line arguments
    """
    global init_argument_map
    if __check_initialize_argument_map():
        cla_util = CommandLineArgUtil(_program_name, __required_arguments, __optional_arguments)
        combined_argument_map = cla_util.process_args(args, TOOL_TYPE_DEFAULT)
        init_argument_map=combined_argument_map
        # Todo Is process_java_home required?
        __process_java_home(combined_argument_map)

    # Verify that the domain type is a known type and load its typedef.
    #
    domain_typedef = model_context_helper.create_typedef(_program_name, init_argument_map)
    model_context = model_context_helper.create_context(_program_name, init_argument_map, domain_typedef)
    return model_context


def __check_initialize_argument_map():
    global init_argument_map
    if init_argument_map is None:
        # init_argument_map = map
        return True
    return False

def __process_java_home(optional_arg_map):
    _method_name = '__process_java_home'
    if CommandLineArgUtil.JAVA_HOME_SWITCH in optional_arg_map:
        java_home_name = optional_arg_map[CommandLineArgUtil.JAVA_HOME_SWITCH]
    else:
        java_home_name = env_helper.getenv('JAVA_HOME')
    try:
        FileUtils.validateExistingDirectory(java_home_name)
    except IllegalArgumentException, iae:
        # this value is used for java home global token in attributes.
        # If this was passed as command line, it might no longer exist.
        # The JAVA_HOME environment variable was validated by script.
        __logger.info('WLSDPLY-06027', java_home_name, iae.getLocalizedMessage(),
                      class_name=_class_name, method_name=_method_name)

def _get_domain_path(model_context, model):
    """
    Returns the domain home path.
    :param model_context: the model context
    :param model: the model
    :return: the domain path
    """
    _method_name="_get_domain_path"
    domain_parent = model_context.get_domain_parent_dir()
    if domain_parent is None:
        return model_context.get_domain_home()
    elif TOPOLOGY in model and infra_constants.DOMAIN_HOME_DIR in model[TOPOLOGY]:
        return model[TOPOLOGY][infra_constants.DOMAIN_HOME_DIR]
    else:
        ex = exception_helper.create_cla_exception(ExitCode.USAGE_ERROR, 'WLSDPLY-05020',infra_constants.DOMAIN_HOME_DIR, model_context.get_archive_file_name())
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex


def __generate_remote_report_json(model_context):
    _method_name = '__generate_remote_report_json'
    __logger.entering(class_name=_class_name, method_name=_method_name)
    # if not model_context.is_remote() or not env_helper.has_env(_store_result_environment_variable):
    #     __logger.warning('WLSMIG-06035', _store_result_environment_variable, "not processing method. context remote or env_helper",
    #                      class_name=_class_name, method_name=_method_name)
    #     return

    # write JSON output if the __WLSDEPLOY_STORE_RESULT__ environment variable is set.
    # write to the file before the stdout so any logging messages come first.
    remote_map = discoverer.remote_dict
    # model_context.get_ssh_context
    store_path = env_helper.getenv(_store_result_environment_variable)
    __logger.info('WLSDPLY-06034', store_path, class_name=_class_name, method_name=_method_name)
    missing_archive_entries = []
    for key in remote_map:
        archive_map = remote_map[key]
        missing_archive_entries.append({
            'sourceFile': key,
            'path': archive_map[discoverer.REMOTE_ARCHIVE_PATH],
            'type': archive_map[discoverer.REMOTE_TYPE]
        })
    result_root = OrderedDict()
    result_root['missingArchiveEntries'] = missing_archive_entries
    try:
        json_translator.PythonToJson(result_root).write_to_json_file(store_path)
    except JsonException, ex:
        __logger.warning('WLSDPLY-06035', _store_result_environment_variable, ex.getLocalizedMessage(),
                         class_name=_class_name, method_name=_method_name)


def _traverse(dictionary, *args):
    """
    Recursively resolve keys in nested dictionaries.
    Example: _traverse(model_dict, TOPOLOGY, SERVER, ms1)
    :return: the last element in the key list
    """
    value = dictionary
    for arg in args:
        if not isinstance(value, dict):
            # self.fail('Element ' + arg + ' parent is not a dictionary in ' + '/'.join(list(args)))
            continue
        if arg not in value:
            # self.fail('Element ' + arg + ' not found in ' + '/'.join(list(args)))
            continue
        value = value[arg]
    return value

def __discover(model, model_context, helper):
    """
    Populate the model from the domain.
    :param model_context: the model context
    :param helper: wlst_helper instance
    :return: the fully-populated model
    :raises DiscoverException: if an error occurred while discover the domain
    """
    _method_name = '__discover'
    __logger.entering(class_name=_class_name, method_name=_method_name)
    topology = model.get_model_topology()
    machines = model.get_model_resources()
    hosts_details = OrderedDict()
    base_location = LocationContext()
    machine_nodes = dictionary_utils.get_dictionary_element(topology, MACHINE)
    unix_machine_nodes = dictionary_utils.get_dictionary_element(topology, UNIX_MACHINE)
    nodes={}
    if len(machine_nodes) > 0:
        # self._create_named_mbeans(MACHINE, machine_nodes, location, log_created=True, delete_now=delete_now)
        # print("machines"+machine_nodes)
        # base_location = LocationContext()
        nodes=machine_nodes
    elif len(unix_machine_nodes) > 0:
        # __logger.info('WLSMIG-06022', unix_machine_nodes, class_name=_class_name, method_name=_method_name)
        # print("unix_machines"+unix_machine_nodes)
        # base_location = LocationContext()
        # __logger.info("WLSDPLY-09005", machine_nodes, unix_machine_nodes, method_name=_method_name, class_name=_class_name)
        nodes=unix_machine_nodes

    if not nodes:
        message = (
            "No machine configuration found in the domain model. "
            "The migration tool requires at least one machine configuration to perform infrastructure discovery."
        )
        print(message)
        sys.exit(2)

    admin_server_name = topology['AdminServerName']
    if 'Machine' in topology['Server'][admin_server_name]:
        admin_machine=topology['Server'][admin_server_name]["Machine"]
    for machine in nodes:
        node_details = OrderedDict()
        #if machine is admin server, then it is running locally. (current version)
        if admin_machine == machine:
            __logger.fine('Discovery of Admin Server machine initiated {0}', admin_machine, class_name=_class_name, method_name=_method_name)
            #Do local Discovery.  It should include any managed server registered.
            host_result=InfraDiscoverer(model_context, OrderedDict(), base_location, model, machine).discover()
            discoverer.add_to_model_if_not_empty(hosts_details,admin_machine, host_result)
        else:
            listen_address=_traverse(machine_nodes, machine, model_constants.NODE_MANAGER, model_constants.LISTEN_ADDRESS)
            global init_argument_map
            __logger.fine('Discovery of  Managed Servers machines based on listen_address {0} to be initiated', listen_address, class_name=_class_name, method_name=_method_name)
            init_argument_map[CommandLineArgUtil.SSH_HOST_SWITCH]=listen_address
            is_encryption_supported = EncryptionUtils.isEncryptionSupported()
            if is_encryption_supported:
                __logger.fine('encryption supported {0}', init_argument_map, class_name=_class_name, method_name=_method_name)
            else:
                __logger.fine('encryption Not supported {0}', init_argument_map, class_name=_class_name, method_name=_method_name)
            per_machine_model_context=__process_args(init_argument_map,is_encryption_supported)
            host_result=InfraDiscoverer(per_machine_model_context, node_details, base_location, model, machine).discover()
            discoverer.add_to_model_if_not_empty(hosts_details,machine, host_result)

    if len(hosts_details) == 0 :
        #  Todo raise an exception. Could not discover.
        return None
    # discoverer.add_to_model_if_not_empty(machines, MACHINES, hosts_details)
    discoverer.add_to_model(machines,MACHINES,hosts_details)
    # InfraDiscoverer(model_context, model.get_model_resources(), base_location).discover()
    __logger.exiting(class_name=_class_name, method_name=_method_name, result=model.get_model_resources())
    return model


def __persist_model(model, model_context):
    """
    Save the model to the specified model file name.
    :param model: the model to save
    :param model_context: the model context
    :raises DiscoverException: if an error occurs while create a temporary file for the model
                               or while adding it to the archive
    :raises TranslateException: if an error occurs while serializing the model or writing it to disk
    """
    _method_name = '__persist_model'

    __logger.entering(class_name=_class_name, method_name=_method_name)

    global __wlst_mode

    # add model comments to dictionary extracted from the Model object
    model_dict = model.get_model()
    message_1 = exception_helper.get_message('WLSDPLY-06039', WebLogicDeployToolingVersion.getVersion(), _program_name)
    model_dict.addComment(DOMAIN_INFO, message_1)
    if __wlst_mode == WlstModes.ONLINE:
        remote_wls_version = model_context.get_remote_wls_version()
        if remote_wls_version is None:
            remote_wls_version = 'UNKNOWN'

        message_2 = exception_helper.get_message('WLSDPLY-06043', model_context.get_local_wls_version(),
                                                 WlstModes.from_value(__wlst_mode), remote_wls_version)
    else:
        message_2 = exception_helper.get_message('WLSDPLY-06040', WlstModes.from_value(__wlst_mode),
                                                 model_context.get_local_wls_version())
    model_dict.addComment(DOMAIN_INFO, message_2)
    model_dict.addComment(DOMAIN_INFO, '')

    #todo identify why model_context.get_archive_file is not set.
    global init_argument_map
    # model_file_name = model_context.get_archive_file()
    model_file_name = init_argument_map[CommandLineArgUtil.ARCHIVE_FILE_SWITCH]

    model_file = FileUtils.getCanonicalFile(File(model_file_name))
    model_translator.PythonToFile(model_dict).write_to_file(model_file.getAbsolutePath())

    __logger.exiting(class_name=_class_name, method_name=_method_name)

def load_model(program_name, model_context, aliases, filter_type, wlst_mode, validate_crd_sections=True):
    """
    Load the model based on the arguments in the model context.
    Apply the variable substitution, if specified, and validate the model.
    Apply any model filters of the specified type that are configured, and re-validate if necessary
    The tool will exit if exceptions are encountered.
    :param program_name: the program name, for logging
    :param model_context: the model context
    :param aliases: the alias configuration
    :param filter_type: the type of any filters to be applied
    :param wlst_mode: offline or online
    :param validate_crd_sections: True if CRD sections (such as kubernetes) should be validated
    :return: the resulting model dictionary
    """
    _method_name = 'load_model'

    variable_map = {}
    try:
        if model_context.get_variable_file():
            # callers of this method allow multiple variable files
            variable_map = variables.load_variables(model_context.get_variable_file(), allow_multiple_files=True)
    except VariableException, ex:
        __logger.severe('WLSDPLY-20004', program_name, ex.getLocalizedMessage(), error=ex,
                        class_name=_class_name, method_name=_method_name)
        tool_exception = \
            exception_helper.create_exception(aliases.get_exception_type(), 'WLSDPLY-20004', program_name,
                                              ex.getLocalizedMessage(), error=ex)
        __logger.throwing(tool_exception, class_name=_class_name, method_name=_method_name)
        raise tool_exception

    model_file_value = model_context.get_model_file()
    try:
        model_dictionary = cla_helper.merge_model_files(model_file_value, variable_map)
    except TranslateException, te:
        __logger.severe('WLSDPLY-09014', program_name, model_file_value, te.getLocalizedMessage(), error=te,
                        class_name=_class_name, method_name=_method_name)
        tool_exception = \
            exception_helper.create_exception(aliases.get_exception_type(), 'WLSDPLY-09014', program_name,
                                              model_file_value, te.getLocalizedMessage(), error=te)
        __logger.throwing(tool_exception, class_name=_class_name, method_name=_method_name)
        raise tool_exception

    try:
        variables.substitute(model_dictionary, variable_map, model_context)
    except VariableException, ex:
        __logger.severe('WLSDPLY-20004', program_name, ex.getLocalizedMessage(), error=ex,
                        class_name=_class_name, method_name=_method_name)
        tool_exception = \
            exception_helper.create_exception(aliases.get_exception_type(), 'WLSDPLY-20004', program_name,
                                              ex.getLocalizedMessage(), error=ex)
        __logger.throwing(tool_exception, class_name=_class_name, method_name=_method_name)
        raise tool_exception

    filter_helper.apply_filters(model_dictionary, filter_type, model_context)

    # persist_model(model_context, model_dictionary)

    # validate_model(program_name, model_dictionary, model_context, aliases, wlst_mode,
    #                validate_crd_sections=validate_crd_sections)

    return model_dictionary



def main(model_context):
    """
    The main entry point for the discoverDomain tool.

    :param model_context: the model context object
    :return: exit code
    """
    _method_name = 'main'
    __logger.entering(class_name=_class_name, method_name=_method_name)

    helper = WlstHelper(ExceptionType.SSH)
    helper.silence()
    model = None
    _exit_code = ExitCode.OK
    try:
        aliases = Aliases(model_context, wlst_mode=__wlst_mode, exception_type=ExceptionType.DISCOVER)
        model_dictionary = load_model(_program_name, model_context, aliases, "discover", __wlst_mode,
                                                 validate_crd_sections=False)
        # set domain home result in model context, for use by deployers and helpers
        model_context.set_domain_home(_get_domain_path(model_context, model_dictionary))
        model = Model(model_dictionary)
        model_output = __discover(model, model_context, helper)
        __persist_model(model_output, model_context)
    except CLAException, ex:
        _exit_code = ex.getExitCode()
        __logger.severe('WLSDPLY-06011', _program_name, model_context.get_domain_name(),
                        model_context.get_domain_home(), ex.getLocalizedMessage(),
                        error=ex, class_name=_class_name, method_name=_method_name)
    except DiscoverException, ex:
        __logger.severe('WLSDPLY-06011', _program_name, model_context.get_domain_name(),
                        model_context.get_domain_home(), ex.getLocalizedMessage(),
                        error=ex, class_name=_class_name, method_name=_method_name)
        _exit_code = ExitCode.ERROR
    except SSHException,ex:
        __logger.severe('WLSDPLY-32904', _program_name, ex.getLocalizedMessage(),
                        error=ex, class_name=_class_name, method_name=_method_name)
        _exit_code = ExitCode.ERROR
    except TranslateException, ex:
        __logger.severe('WLSDPLY-20024', _program_name, model_context.get_archive_file_name(), ex.getLocalizedMessage(),
                        error=ex, class_name=_class_name, method_name=_method_name)
        _exit_code = ExitCode.ERROR
    __logger.exiting(class_name=_class_name, method_name=_method_name, result=_exit_code)
    return _exit_code

# def multi_discover():
if __name__ == '__main__' or __name__ == 'main':
    tool_main.run_tool(main, __process_args, sys.argv, _program_name, _class_name, __logger)
