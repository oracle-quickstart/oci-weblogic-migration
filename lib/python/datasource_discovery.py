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

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'deps', 'wdt','lib','python'))

from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.tool.util.targets.additional_output_helper import DATASOURCES
from wlsdeploy.tool.util.targets.additional_output_helper import HAS_DATASOURCES
from wlsdeploy.tool.util.targets.additional_output_helper import DATASOURCE_URL
from wlsdeploy.tool.util.targets.additional_output_helper import DATASOURCE_NAME
from wlsdeploy.tool.util.targets.additional_output_helper import JDBC_SYSTEM_RESOURCE
from wlsdeploy.tool.util.targets.additional_output_helper import JDBC_RESOURCE
from wlsdeploy.tool.util.targets.additional_output_helper import JDBC_DRIVER_PARAMS
from wlsdeploy.aliases.model_constants import JDBC_DATASOURCE_PARAMS
from wlsdeploy.aliases.model_constants import JDBC_DATASOURCE_PARAMS_DATASOURCE_LIST
from wlsdeploy.tool.util.targets.additional_output_helper import URL

from wlsdeploy.util.model import Model
from wlsdeploy.util import model_translator
from wlsdeploy.exception import exception_helper
from wlsdeploy.tool.util import model_context_helper
from wlsdeploy.tool.util import wlst_helper
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.util import env_helper
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
from wlsdeploy.tool.util.targets import file_template_helper


wlst_helper.wlst_functions = globals()

_store_result_environment_variable = '__WLSDEPLOY_STORE_RESULT__'

_program_name = 'discoverDomain'
_class_name = 'datasource_discovery'
__logger = PlatformLogger('wlsdeploy.tool.util')

# result_dict = OrderedDict()
model_context_dict = OrderedDict()
__wlst_mode = WlstModes.OFFLINE

TF_AUTO_TFVARS_FILE_NAME = 'db-connection-string.auto.tfvars'
TF_ORM_SCHEMA_FILE_NAME = 'schema.yaml'
TF_LOCALS_DB_CONNECTION_STRING_FILE_NAME= 'locals-db-connection-string.tf'
TF_DATASOURCE_OCI_DB_RESOURCES_FILE_NAME= 'data-oci-db-resources.tf'
TF_VARIABLES_DB_CONNECTION_STRING_FILE_NAME= 'variables-db-connection-string.tf'
#TODO: JOI MOVE RM_STACK_PATH TO A DEFINITIVE PATH
RM_STACK_PATH='oci/generated'
TFVARS_TEMPLATE_RESOURCE_PATH = os.path.join('templates',TF_AUTO_TFVARS_FILE_NAME + file_template_helper.MUSTACHE_SUFFIX)
ORM_SCHEMA_TEMPLATE_RESOURCE_PATH = os.path.join('templates',TF_ORM_SCHEMA_FILE_NAME + file_template_helper.MUSTACHE_SUFFIX)
TF_LOCALS_TEMPLATE_RESOURCE_PATH = os.path.join('templates',TF_LOCALS_DB_CONNECTION_STRING_FILE_NAME + file_template_helper.MUSTACHE_SUFFIX)
TF_DATASOURCE_OCI_DB_RESOURCES_TEMPLATE_RESOURCE_PATH = os.path.join('templates',TF_DATASOURCE_OCI_DB_RESOURCES_FILE_NAME + file_template_helper.MUSTACHE_SUFFIX)
TF_VARIABLES_DB_CONNECTION_STRING_TEMPLATE_RESOURCE_PATH = os.path.join('templates',TF_VARIABLES_DB_CONNECTION_STRING_FILE_NAME + file_template_helper.MUSTACHE_SUFFIX)
__required_arguments = [
    CommandLineArgUtil.ORACLE_HOME_SWITCH,
    CommandLineArgUtil.MODEL_FILE_SWITCH

]

__optional_arguments = [
    CommandLineArgUtil.OUTPUT_DIR_SWITCH
]


def __process_args(args, is_encryption_supported):
    """
    Process the command-line arguments and prompt the user for any missing information
    :param args: the command-line arguments list
    ###:param is_encryption_supported: whether WDT encryption is supported by the JVM
    :raises CLAException: if an error occurs while validating and processing the command-line arguments
    """


    cla_util = CommandLineArgUtil(_program_name, __required_arguments, __optional_arguments)
    combined_argument_map = cla_util.process_args(args, TOOL_TYPE_DEFAULT)
    # Todo Is process_java_home required?
    __process_java_home(combined_argument_map)
    __process_terraform_filename_arg(combined_argument_map)
    # Verify that the domain type is a known type and load its typedef.
    #
    domain_typedef = model_context_helper.create_typedef(_program_name, combined_argument_map)
    model_context = model_context_helper.create_context(_program_name, combined_argument_map, domain_typedef)
    return model_context

def __process_terraform_filename_arg(optional_arg_map):
    """
    Validate the terraform -archive- filename argument if present.
    :param optional_arg_map: containing the variable file name
    :raises: CLAException: if this argument is present but fails validation
    """
    _method_name = '__process_terraform_filename_arg'

    # if -target is specified -output_dir is required
    output_dir = dictionary_utils.get_element(optional_arg_map, CommandLineArgUtil.OUTPUT_DIR_SWITCH)
    #TODO: JOI: Does output_dir needs to be validate if exists? should it be created?
    # if (output_dir is None) or (not os.path.isdir(output_dir)):
    #     ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
    #                                        'WLSDPLY-06048', output_dir)
    #     __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
    #     raise ex

    # if CommandLineArgUtil.VARIABLE_FILE_SWITCH in optional_arg_map:
    #     terraform_tfvars_file_name = optional_arg_map[CommandLineArgUtil.VARIABLE_FILE_SWITCH]
    #     path_helper_obj = path_helper.get_path_helper()
    #     variable_dir_name = path_helper_obj.get_local_parent_directory(terraform_tfvars_file_name)
    #
    #     if not os.path.exists(variable_dir_name):
    #         ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
    #                                                    'WLSDPLY-06048', terraform_tfvars_file_name)
    #         __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
    #         raise ex
    #
    #     # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    #     variable_file_obj = FileUtils.getCanonicalFile(terraform_tfvars_file_name)
    #     if variable_file_obj.exists() and not variable_file_obj.delete():
    #         ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06049',
    #                                                    _program_name, terraform_tfvars_file_name)
    #         __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
    #         raise ex


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


# def __generate_remote_report_json(model_context):
#     _method_name = '__generate_remote_report_json'
#     __logger.entering(class_name=_class_name, method_name=_method_name)
#     # if not model_context.is_remote() or not env_helper.has_env(_store_result_environment_variable):
#     #     __logger.warning('WLSMIG-06035', _store_result_environment_variable, "not processing method. context remote or env_helper",
#     #                      class_name=_class_name, method_name=_method_name)
#     #     return
#
#     # write JSON output if the __WLSDEPLOY_STORE_RESULT__ environment variable is set.
#     # write to the file before the stdout so any logging messages come first.
#     remote_map = discoverer.remote_dict
#     # model_context.get_ssh_context
#     store_path = env_helper.getenv(_store_result_environment_variable)
#     __logger.info('WLSDPLY-06034', store_path, class_name=_class_name, method_name=_method_name)
#     missing_archive_entries = []
#     for key in remote_map:
#         archive_map = remote_map[key]
#         missing_archive_entries.append({
#             'sourceFile': key,
#             'path': archive_map[discoverer.REMOTE_ARCHIVE_PATH],
#             'type': archive_map[discoverer.REMOTE_TYPE]
#         })
#     result_root = OrderedDict()
#     result_root['missingArchiveEntries'] = missing_archive_entries
#     try:
#         json_translator.PythonToJson(result_root).write_to_json_file(store_path)
#     except JsonException, ex:
#         __logger.warning('WLSDPLY-06035', _store_result_environment_variable, ex.getLocalizedMessage(),
#                          class_name=_class_name, method_name=_method_name)


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

def __discover_datasources(model, model_context, helper):
    """
    Populate the model from the domain.
    :param model_context: the model context
    :param helper: wlst_helper instance
    :return: a OrderedDict with a list of unique datasources.
    :raises DiscoverException: if an error occurred while discover the domain
    """
    _method_name = '__discover'
    __logger.entering(class_name=_class_name, method_name=_method_name)
    resources = model.get_model_resources()
    unique_strings = []
    datasource_map = {}
    template_hash = dict()
    template_hash['is_mds']="false"
    jdbc_system_resources = dictionary_utils.get_dictionary_element(resources, JDBC_SYSTEM_RESOURCE)
    for jdbc_name in jdbc_system_resources:
        named = dictionary_utils.get_dictionary_element(jdbc_system_resources, jdbc_name)
        resources = dictionary_utils.get_dictionary_element(named, JDBC_RESOURCE)
        driver_params = dictionary_utils.get_dictionary_element(resources, JDBC_DRIVER_PARAMS)
        url = dictionary_utils.get_element(driver_params, URL)
        dslist_params = dictionary_utils.get_dictionary_element(resources, JDBC_DATASOURCE_PARAMS)
        dslist = dictionary_utils.get_element(dslist_params, JDBC_DATASOURCE_PARAMS_DATASOURCE_LIST)

        #Identifies if database connection string refers to a Multi data Source.
        if dslist != None:
            template_hash['is_mds']="true"

        if url is not None or url != '':
            datasource_map[url]="true"

    if len(datasource_map.keys()) > 0: #Hacky way to get uniques jdbc strings.. now put it back as map
        for index, url in enumerate(datasource_map.keys()):
            database_hash = dict()
            database_hash[DATASOURCE_NAME] = str(index)
            database_hash[DATASOURCE_URL] = url
            unique_strings.append(database_hash)

    template_hash[DATASOURCES] = unique_strings
    template_hash[HAS_DATASOURCES] = len(unique_strings) != 0
    __logger.exiting(class_name=_class_name, method_name=_method_name, result=template_hash)
    return template_hash


def __persist_auto_tfvars(unique_datasources,model_context):
    """
     Generate a shell script for creating k8s secrets.
     :param model_context: used to determine output directory
     :param token_dictionary: contains every token
     :param model_dictionary: used to determine domain UID
     :param exception_type: type of exception to throw
     """
    # script_hash = _prepare_k8s_secrets(model_context, token_dictionary, model_dictionary)
    # script_hash = {'domainUid': domain_uid, 'topComment': comment, 'namespace': domain_uid,
    #                    'maxSecretLength': str(MAX_SECRET_LENGTH)}
    _method_name = '__persist_auto_tfvars'
    _path_helper = path_helper.get_path_helper()
    variable_file= model_context.get_variable_file()
    output_dir =  model_context.get_output_dir()
    py_path=env_helper.getenv("PY_SCRIPTS_PATH", None)
    tool_Home=env_helper.getenv("toolHome", None)
    if py_path is None:
        py_path=os.path.join(tool_Home,"lib","python")
    # if variable file is set, then check output_dir, if not set,
    file_location =""
    if variable_file is not None and output_dir is None:
        file_location =  os.path.join(RM_STACK_PATH, variable_file)
    elif output_dir is not None and variable_file is None:
        file_location = os.path.join(output_dir,TF_AUTO_TFVARS_FILE_NAME)
    elif  output_dir is None and variable_file is None:
        file_location = os.path.join(tool_Home,RM_STACK_PATH,TF_AUTO_TFVARS_FILE_NAME)

    # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    template_file = os.path.join(py_path,TFVARS_TEMPLATE_RESOURCE_PATH)
    variable_dir_name = _path_helper.get_local_parent_directory(template_file)
    if not os.path.exists(variable_dir_name):
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex
    variable_file_obj = FileUtils.getCanonicalFile(template_file)
    if not variable_file_obj.exists():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    tfvars_file = File(file_location)
    __logger.info('WLSDPLY-01662', template_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', tfvars_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', unique_datasources, class_name=_class_name, method_name=_method_name)
    file_template_helper.create_file_from_file(template_file, unique_datasources, tfvars_file, ExceptionType.DISCOVER)
    FileUtils.chmod(tfvars_file.getPath(), 0640)

    __logger.exiting(class_name=_class_name, method_name=_method_name)

def __generate_orm_schema(unique_datasources,model_context):
    """
     Generate a shell script for creating k8s secrets.
     :param model_context: used to determine output directory
     :param token_dictionary: contains every token
     :param model_dictionary: used to determine domain UID
     :param exception_type: type of exception to throw
     """
    # script_hash = _prepare_k8s_secrets(model_context, token_dictionary, model_dictionary)
    # script_hash = {'domainUid': domain_uid, 'topComment': comment, 'namespace': domain_uid,
    #                    'maxSecretLength': str(MAX_SECRET_LENGTH)}
    _method_name = '__generate_orm_schema'
    _path_helper = path_helper.get_path_helper()

    output_dir =  model_context.get_output_dir()
    py_path=env_helper.getenv("PY_SCRIPTS_PATH", None)
    tool_Home=env_helper.getenv("toolHome", None)
    file_location = ""
    if py_path is None:
        py_path=os.path.join(tool_Home,"lib","python")
    if output_dir is not None:
        file_location = os.path.join(output_dir,TF_ORM_SCHEMA_FILE_NAME)
    else :
        file_location = os.path.join(tool_Home,RM_STACK_PATH,TF_ORM_SCHEMA_FILE_NAME)

    template_file = os.path.join(py_path,ORM_SCHEMA_TEMPLATE_RESOURCE_PATH)
    variable_dir_name = _path_helper.get_local_parent_directory(template_file)
    if not os.path.exists(variable_dir_name):
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    variable_file_obj = FileUtils.getCanonicalFile(file_location)
    if variable_file_obj.exists() and not variable_file_obj.delete():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06049',
                                                   _program_name, file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    variable_file_obj = FileUtils.getCanonicalFile(template_file)
    if not variable_file_obj.exists():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    schema_file = File(file_location)
    __logger.info('WLSDPLY-01662', template_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', schema_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', unique_datasources, class_name=_class_name, method_name=_method_name)
    file_template_helper.create_file_from_file(template_file, unique_datasources, schema_file, ExceptionType.DISCOVER)
    FileUtils.chmod(schema_file.getPath(), 0640)

    __logger.exiting(class_name=_class_name, method_name=_method_name)

def __create_tf_locals_db_connection_file(unique_datasources,model_context):
    """
     Generate a shell script for creating k8s secrets.
     :param model_context: used to determine output directory
     :param token_dictionary: contains every token
     :param model_dictionary: used to determine domain UID
     :param exception_type: type of exception to throw
     """
    # script_hash = _prepare_k8s_secrets(model_context, token_dictionary, model_dictionary)
    # script_hash = {'domainUid': domain_uid, 'topComment': comment, 'namespace': domain_uid,
    #                    'maxSecretLength': str(MAX_SECRET_LENGTH)}
    _method_name = '__create_tf_locals_db_connection_file'
    _path_helper = path_helper.get_path_helper()

    output_dir =  model_context.get_output_dir()
    py_path=env_helper.getenv("PY_SCRIPTS_PATH", None)
    tool_Home=env_helper.getenv("toolHome", None)
    file_location = ""
    if py_path is None:
        py_path=os.path.join(tool_Home,"lib","python")
    if output_dir is not None:
        file_location = os.path.join(output_dir,TF_LOCALS_DB_CONNECTION_STRING_FILE_NAME)
    else :
        file_location = os.path.join(tool_Home,RM_STACK_PATH,TF_LOCALS_DB_CONNECTION_STRING_FILE_NAME)

    template_file = os.path.join(py_path,TF_LOCALS_TEMPLATE_RESOURCE_PATH)
    variable_dir_name = _path_helper.get_local_parent_directory(template_file)
    if not os.path.exists(variable_dir_name):
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    variable_file_obj = FileUtils.getCanonicalFile(file_location)
    if variable_file_obj.exists() and not variable_file_obj.delete():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06049',
                                                   _program_name, file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    variable_file_obj = FileUtils.getCanonicalFile(template_file)
    if not variable_file_obj.exists():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    tf_locals_file = File(file_location)
    __logger.info('WLSDPLY-01662', template_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', tf_locals_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', unique_datasources, class_name=_class_name, method_name=_method_name)
    file_template_helper.create_file_from_file(template_file, unique_datasources, tf_locals_file, ExceptionType.DISCOVER)
    FileUtils.chmod(tf_locals_file.getPath(), 0640)

    __logger.exiting(class_name=_class_name, method_name=_method_name)

def __create_tf_ds_file(unique_datasources,model_context):
    """
     Generate a shell script for creating k8s secrets.
     :param model_context: used to determine output directory
     :param token_dictionary: contains every token
     :param model_dictionary: used to determine domain UID
     :param exception_type: type of exception to throw
     """
    # script_hash = _prepare_k8s_secrets(model_context, token_dictionary, model_dictionary)
    # script_hash = {'domainUid': domain_uid, 'topComment': comment, 'namespace': domain_uid,
    #                    'maxSecretLength': str(MAX_SECRET_LENGTH)}
    _method_name = '__create_tf_ds_file'
    _path_helper = path_helper.get_path_helper()

    output_dir =  model_context.get_output_dir()
    py_path=env_helper.getenv("PY_SCRIPTS_PATH", None)
    tool_Home=env_helper.getenv("toolHome", None)
    file_location = ""
    if py_path is None:
        py_path=os.path.join(tool_Home,"lib","python")
    if output_dir is not None:
        file_location = os.path.join(output_dir,TF_DATASOURCE_OCI_DB_RESOURCES_FILE_NAME)
    else :
        file_location = os.path.join(tool_Home,RM_STACK_PATH,TF_DATASOURCE_OCI_DB_RESOURCES_FILE_NAME)

    template_file = os.path.join(py_path,TF_DATASOURCE_OCI_DB_RESOURCES_TEMPLATE_RESOURCE_PATH)
    variable_dir_name = _path_helper.get_local_parent_directory(template_file)
    if not os.path.exists(variable_dir_name):
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    variable_file_obj = FileUtils.getCanonicalFile(file_location)
    if variable_file_obj.exists() and not variable_file_obj.delete():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06049',
                                                   _program_name, file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    variable_file_obj = FileUtils.getCanonicalFile(template_file)
    if not variable_file_obj.exists():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    tf_datasource_file = File(file_location)
    __logger.info('WLSDPLY-01662', template_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', tf_datasource_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', unique_datasources, class_name=_class_name, method_name=_method_name)
    file_template_helper.create_file_from_file(template_file, unique_datasources, tf_datasource_file, ExceptionType.DISCOVER)
    FileUtils.chmod(tf_datasource_file.getPath(), 0640)
    __logger.exiting(class_name=_class_name, method_name=_method_name)

def __create_tf_variables_db_connection_file(unique_datasources,model_context):
    """
     Generate a shell script for creating k8s secrets.
     :param model_context: used to determine output directory
     :param token_dictionary: contains every token
     :param model_dictionary: used to determine domain UID
     :param exception_type: type of exception to throw
     """
    # script_hash = _prepare_k8s_secrets(model_context, token_dictionary, model_dictionary)
    # script_hash = {'domainUid': domain_uid, 'topComment': comment, 'namespace': domain_uid,
    #                    'maxSecretLength': str(MAX_SECRET_LENGTH)}
    _method_name = '__create_tf_variables_db_connection_file'
    _path_helper = path_helper.get_path_helper()

    output_dir =  model_context.get_output_dir()
    py_path=env_helper.getenv("PY_SCRIPTS_PATH", None)
    tool_Home=env_helper.getenv("toolHome", None)
    file_location = ""
    if py_path is None:
        py_path=os.path.join(tool_Home,"lib","python")
    if output_dir is not None:
        file_location = os.path.join(output_dir,TF_VARIABLES_DB_CONNECTION_STRING_FILE_NAME)
    else :
        file_location = os.path.join(tool_Home,RM_STACK_PATH,TF_VARIABLES_DB_CONNECTION_STRING_FILE_NAME)

    template_file = os.path.join(py_path,TF_VARIABLES_DB_CONNECTION_STRING_TEMPLATE_RESOURCE_PATH)
    variable_dir_name = _path_helper.get_local_parent_directory(template_file)
    if not os.path.exists(variable_dir_name):
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    # Delete any existing variable file for discoverDomain so that we always start with a fresh file.
    variable_file_obj = FileUtils.getCanonicalFile(file_location)
    if variable_file_obj.exists() and not variable_file_obj.delete():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,'WLSDPLY-06049',
                                                   _program_name, file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    variable_file_obj = FileUtils.getCanonicalFile(template_file)
    if not variable_file_obj.exists():
        ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR,
                                                   'WLSDPLY-06048', file_location)
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    tf_variables_file = File(file_location)
    __logger.info('WLSDPLY-01662', template_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', tf_variables_file, class_name=_class_name, method_name=_method_name)
    __logger.info('WLSDPLY-01662', unique_datasources, class_name=_class_name, method_name=_method_name)
    file_template_helper.create_file_from_file(template_file, unique_datasources, tf_variables_file, ExceptionType.DISCOVER)
    FileUtils.chmod(tf_variables_file.getPath(), 0640)
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
        #TODO: JOI review code line below if needed for datasource discovery.
        # model_context.set_domain_home(_get_domain_path(model_context, model_dictionary))
        model = Model(model_dictionary)
        model_output = __discover_datasources(model, model_context, helper)
        __persist_auto_tfvars(model_output, model_context)
        __generate_orm_schema(model_output, model_context)
        __create_tf_ds_file(model_output,model_context)
        __create_tf_locals_db_connection_file(model_output,model_context)
        __create_tf_variables_db_connection_file(model_output,model_context)
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
