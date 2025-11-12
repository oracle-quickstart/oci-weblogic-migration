# -*- coding: utf-8 -*-
"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

The main module for the WebLogic Deploy tool to verify the user's SSH configuration is compatible with WDT.
"""
import os
import sys
import traceback
import fnmatch

from oracle.weblogic.deploy.util import SSHException, WLSDeployArchive
from oracle.weblogic.deploy.util import CLAException
from oracle.weblogic.deploy.encrypt import EncryptionUtils

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','infra'))
import infra_constants
import common

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))),'lib', 'python','migrate','data'))
from wls_migration_archive import WLSMigrationArchiver

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(sys.argv[0])))), 'deps', 'wdt', 'lib', 'python'))

from wlsdeploy.aliases.location_context import LocationContext
from wlsdeploy.util.model import Model
from wlsdeploy.util.cla_utils import TOOL_TYPE_DEFAULT
from wlsdeploy.tool.discover import discoverer
from wlsdeploy.json import json_translator
from java.io import ByteArrayInputStream

from oracle.weblogic.deploy.util import FileUtils
from oracle.weblogic.deploy.util import PyOrderedDict as OrderedDict
from oracle.weblogic.deploy.discover import DiscoverException
from oracle.weblogic.deploy.util import TranslateException
from wlsdeploy.aliases import model_constants
from wlsdeploy.aliases.aliases import Aliases
from wlsdeploy.aliases.model_constants import TOPOLOGY
from wlsdeploy.exception.exception_types import ExceptionType
from wlsdeploy.tool.util import model_context_helper
from wlsdeploy.tool.util.wlst_helper import WlstHelper
from wlsdeploy.tool.util import wlst_helper
from wlsdeploy.util import cla_helper
from wlsdeploy.aliases.model_constants import UNIX_MACHINE
from wlsdeploy.aliases.model_constants import MACHINE
from wlsdeploy.util import dictionary_utils

from wlsdeploy.aliases.wlst_modes import WlstModes
from wlsdeploy.exception import exception_helper
from wlsdeploy.logging.platform_logger import PlatformLogger
from wlsdeploy.tool.util import filter_helper
from wlsdeploy.util import env_helper
from wlsdeploy.util.exit_code import ExitCode

from wlsdeploy.util.cla_utils import CommandLineArgUtil
CommandLineArgUtil.SPACE_MAP_SWITCH = '-space_map'      # new switch for JSON map
CommandLineArgUtil.ADMIN_RETURN_SWITCH = '-admin_return'  # new switch for admin space flag

wlst_helper.wlst_functions = globals()

_store_result_environment_variable = '__WLSDEPLOY_STORE_RESULT__'

_program_name = 'verifySSH'
_class_name = 'archive_infra'
__logger = PlatformLogger('wlsdeploy.tool.util')

result_dict = OrderedDict()
model_context_dict = OrderedDict()
__wlst_mode = WlstModes.OFFLINE
init_argument_map= None

__required_arguments = [
    CommandLineArgUtil.ORACLE_HOME_SWITCH,
    CommandLineArgUtil.MODEL_FILE_SWITCH,
    CommandLineArgUtil.REMOTE_OUTPUT_DIR_SWITCH,
    CommandLineArgUtil.LOCAL_OUTPUT_DIR_SWITCH
    #-output_dir <path to store archives>
    #-remote_output_dir <path to generate it remotely>
    #-local_output_dir <path to store archives>
    #-skip_archive  : skip archive generation and show commands
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
    CommandLineArgUtil.SKIP_ARCHIVE_FILE_SWITCH,
    CommandLineArgUtil.SPACE_MAP_SWITCH,
    CommandLineArgUtil.ADMIN_RETURN_SWITCH
    #
    # OUTPUT_DIR_SWITCH          = "-output_dir"
    # REMOTE_OUTPUT_DIR_SWITCH   = '-remote_output_dir'
    # LOCAL_OUTPUT_DIR_SWITCH    = '-local_output_dir'

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
        __verify_remote_output_dir_argument(init_argument_map)
    model_context = model_context_helper.create_context(_program_name, init_argument_map)
    return model_context

def __check_initialize_argument_map():
    global init_argument_map
    if init_argument_map is None:
        return True
    return False

def __verify_java_home(optional_arg_map):
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


def __verify_remote_output_dir_argument(argument_map):
    _method_name = '__verify_remote_output_dir_argument'
    if CommandLineArgUtil.SSH_USER_SWITCH in argument_map or CommandLineArgUtil.REMOTE_SWITCH in argument_map:
        if not CommandLineArgUtil.REMOTE_OUTPUT_DIR_SWITCH in argument_map:
            ex = exception_helper.create_cla_exception(ExitCode.ARG_VALIDATION_ERROR, 'WLSDPLY-32902',
                                                       argument_map[CommandLineArgUtil.REMOTE_OUTPUT_DIR_SWITCH])
            __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
            raise ex



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


def load_env_file(file_path):
    """Reads key=value lines from an env file and returns them as a dict.

    :param file_path: path of the file to be loaded
    :return: dict of keys : values from the file
    """
    _method_name = 'load_env_file'
    env = {}
    if not os.path.isfile(file_path):
        __logger.info('WLSDPLY-05027', 'on-prem.env file not found, skipping load_env_file function...',
                      class_name=_class_name, method_name=_method_name)
        return env

    f = open(file_path, 'r')
    try:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            key, val = line.split('=', 1)
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            env[key] = val
    finally:
        try:
            f.close()
        except:
            pass

    return env


def ensure_bucket(oci_bucket_name, oci_compartment_id, log_file):
    """
    Make sure the OCI Object Storage bucket exists, creating it if necessary.

    :param oci_bucket_name:   name of the bucket to check/create
    :param oci_compartment_id: OCID of the compartment in which to create the bucket
    :param log_file:          path to a logfile to append oci CLI output to
    """
    _method_name = 'ensure_bucket'
    # 1) Try to 'get' the bucket; redirect stdout+stderr to our log_file
    get_cmd = "oci os bucket get --bucket-name %s >> %s 2>&1" % (oci_bucket_name, log_file)
    result = os.system(get_cmd)
    if result != 0:
        # bucket is not there, so try to create it
        __logger.info('WLSDPLY-05027', 'Bucket does not exist. Attempting to create bucket...',
                      class_name=_class_name, method_name=_method_name)
        # debug‑log the exact create command
        debug_msg = "Running command: oci os bucket create --name %s --compartment-id %s" % (
            oci_bucket_name, oci_compartment_id)
        __logger.info('WLSDPLY-05027', 'Debug: %s' %debug_msg,
                      class_name=_class_name, method_name=_method_name)

        create_cmd = ("oci os bucket create --name %s "
                      "--compartment-id %s >> %s 2>&1") % (
                         oci_bucket_name, oci_compartment_id, log_file)
        result2 = os.system(create_cmd)
        if result2 != 0:
            # creation failed
            __logger.warning('WLSDPLY-05027',"Error: Failed to create bucket. Check OCI credentials, policies or compartment OCID: %s. Exiting..." %oci_compartment_id, class_name=_class_name, method_name=_method_name)
            # under Jython/WLST, sys.exit(1) will abort the WLST tool with error
            sys.exit(1)

        # success
        __logger.info('WLSDPLY-05027',"Bucket created.", class_name=_class_name, method_name=_method_name)


def upload_to_bucket(file_path, log_file, on_prem_values):
    """
    Upload a file to OCI Object Storage using direct OCI CLI calls.
    Reads bucket_name and tenancy_namespace from on-prem.env.
    Adds extensive debug output to trace all steps.

    :param file_path: path of the file to be uploaded to the bucket
    :param log_file: path to a logfile to append oci CLI output to
    :param on_prem_values: The dictionary have all the on-prem.env file values
    """
    global __logger, _class_name
    _method_name = 'upload_to_bucket'

    # Read bucket and namespace and compartment
    bucket = on_prem_values.get('bucket_name')
    namespace = on_prem_values.get('tenancy_namespace')
    compartment_id = on_prem_values.get('compartment_ocid')

    if not bucket or not namespace or not compartment_id:
        msg = "Missing bucket or namespace or compartment ocid: bucket=%s, namespace=%s, compartment_ocid=%s. Cannot upload %s" % (bucket, namespace, compartment_id, file_path)
        __logger.warning('WLSDPLY-05027', msg, class_name=_class_name, method_name=_method_name)
        # under Jython/WLST, sys.exit(1) will abort the WLST tool with error
        sys.exit(1)

    ensure_bucket(bucket, compartment_id, log_file)

    cmd = "oci os object put --namespace %s --bucket-name %s --file %s --force" % (namespace, bucket, file_path)
    __logger.info('WLSDPLY-05027', 'Running command to upload to oci bucket: %s' %cmd, class_name=_class_name, method_name=_method_name)

    try:
        result = os.system(cmd)
    except Exception, e:
        __logger.warning('WLSDPLY-05027', 'Exception running upload command: %s' % str(e),
                         class_name=_class_name, method_name=_method_name)
        return

    if result == 0:
        msg = 'Successfully uploaded %s to bucket %s' % (file_path, bucket)
        __logger.info('WLSDPLY-05027', msg, class_name=_class_name, method_name=_method_name)
    else:
        msg = "Upload failed (exit code %s) for %s. Retry running bash migration_script.sh after fixing the issue." % (result, file_path)
        __logger.warning('WLSDPLY-05027', msg, class_name=_class_name, method_name=_method_name)
        # under Jython/WLST, sys.exit(1) will abort the WLST tool with error
        sys.exit(1)


def delete_local(file_path):
    """Delete a local file if it exists.

    :param file_path: path of the file to be deleted
    """
    _method_name = 'delete_local'
    if os.path.exists(file_path):
        try:
            os.remove(file_path)
            msg = "Deleted local archive %s" % file_path
            __logger.info('WLSDPLY-05027', msg, class_name=_class_name, method_name=_method_name)
        except Exception, e:
            msg = "Failed to delete %s: %s" % (file_path, str(e))
            __logger.warning('WLSDPLY-05027', msg, class_name=_class_name, method_name=_method_name)

def delete_remote_archives(model_context, file_pattern):
    """
    Perform a remote cleanup on a given host by connecting over SSH and removing matching files.

    The SSH connection details (user, host, key file, and remote output directory) are obtained
    directly from the provided model_context.

    :param model_context: the WDT model context containing SSH connection details
    :param file_pattern: the filename or wildcard pattern (e.g., "*.tar.gz") to remove from remote_dir
    """
    _method_name = 'delete_remote_archives'
    try:
        # Extract SSH parameters from model_context
        try:
            ssh_user = model_context.get_ssh_user()
            ssh_host = model_context.get_ssh_host()
            ssh_key  = model_context.get_ssh_private_key()
            remote_dir = model_context.get_remote_output_dir()
        except Exception, e:
            __logger.warning('WLSDPLY-05027',
                             'Failed to read SSH params from model_context: %s' % str(e),
                             class_name=_class_name, method_name=_method_name)
            __logger.warning('WLSDPLY-05027',
                             'Manual cleanup required for %s (param extraction failed)' % file_pattern,
                             class_name=_class_name, method_name=_method_name)
            return

        # Validate that all required SSH parameters are present
        if not ssh_user or not ssh_host or not ssh_key or not remote_dir:
            __logger.warning('WLSDPLY-05027',
                             'Missing SSH parameters in model_context, cannot perform remote cleanup',
                             class_name=_class_name, method_name=_method_name)
            __logger.warning('WLSDPLY-05027',
                             'Manual cleanup required for %s (missing params)' % file_pattern,
                             class_name=_class_name, method_name=_method_name)
            return

        cmd_array = [
            "ssh", "-i", ssh_key,
            "%s@%s" % (ssh_user, ssh_host),
            "rm -f %s/%s" % (remote_dir, file_pattern)
        ]

        __logger.info('WLSDPLY-05027', 'Running remote cleanup: %s' % (" ".join(cmd_array)),
                      class_name=_class_name, method_name=_method_name)

        runtime = Runtime.getRuntime()
        proc = runtime.exec(cmd_array)
        exit_code = proc.waitFor()

        if exit_code == 0:
            __logger.info('WLSDPLY-05027',
                          "Remote cleanup successful on host %s" % ssh_host,
                          class_name=_class_name, method_name=_method_name)
        else:
            __logger.warning('WLSDPLY-05027',
                             "Remote cleanup failed on host %s (exit %s)" % (ssh_host, exit_code),
                             class_name=_class_name, method_name=_method_name)
            __logger.warning('WLSDPLY-05027',
                             'Manual cleanup required for %s on host %s' % (file_pattern, ssh_host),
                             class_name=_class_name, method_name=_method_name)

    except Exception, e:
        __logger.warning('WLSDPLY-05027',
                         "Exception during remote cleanup: %s" % str(e),
                         class_name=_class_name, method_name=_method_name)
        __logger.warning('WLSDPLY-05027',
                         'Manual cleanup required for %s due to exception' % file_pattern,
                         class_name=_class_name, method_name=_method_name)
        return


def __archive_directories(model, model_context, helper):
    global init_argument_map
    """
    Archive WebLogic Home, Middleware Home, JDK Home, Custom Directories
    :param model_context: the model context
    :param helper: wlst_helper instance
    :raises DiscoverException: if an error occurred while discover the domain
    """
    _method_name = '__archive_directories'
    __logger.entering(class_name=_class_name, method_name=_method_name)
    per_machine_model_context = None
    topology = model.get_model_topology()
    wls_domain_name = topology['Name']
    machines = model.get_model_resources()
    hosts_details = OrderedDict()
    base_location = LocationContext()
    machine_nodes = dictionary_utils.get_dictionary_element(topology, MACHINE)
    unix_machine_nodes = dictionary_utils.get_dictionary_element(topology, UNIX_MACHINE)

    # neither SSH nor WLS Admin Host.  Exception. Stop processing.
    if len(machine_nodes) > 0:
        nodes=machine_nodes
    elif len(unix_machine_nodes) > 0:
        nodes=unix_machine_nodes

    # Determine env file location (fallback if __file__ not set)
    try:
        script_path = __file__
    except NameError:
        script_path = sys.argv[0]

    script_path = os.path.abspath(script_path)
    base_dir = os.path.dirname(os.path.dirname(script_path))  # go from lib/python → base
    env_file = os.path.abspath(os.path.join(base_dir,'..', 'config', 'on-prem.env'))
    log_file = os.path.abspath(os.path.join(base_dir,'..', 'logs', 'upload_to_oci_archive.log'))

    # Define the archive file patterns
    archive_patterns = (
        "%s-weblogic_home.tar.gz" % wls_domain_name,
        "%s-java_home.tar.gz" % wls_domain_name,
        "%s-domain_home.tar.gz" % wls_domain_name,
        "%s-custom_dirs.tar.gz" % wls_domain_name
    )

    # Load the on-prem.env file
    on_prem_values = load_env_file(env_file)

    # Read admin-level precheck return code (0=OK,1=not enough space)
    space_admin_rc = int(os.environ.get('SPACE_ADMIN_RETURNCODE', '0'))
    space_per_archive_rc = int(os.environ.get("SPACE_PER_ARCHIVE_RETURNCODE", "0"))

    # Read per-node JSON map {host:0/1}
    json_space_input = os.environ.get('SPACE_STATUS_JSON', '{}')

    # turn the Python string into a Java InputStream
    bais = ByteArrayInputStream(json_space_input.encode('utf-8'))

    # parse it
    try:
        space_status = json_translator.JsonStreamToPython('SPACE_STATUS_JSON', bais, False).parse()
    except Exception, je:
        # je will already be a JsonException if parsing failed
        __logger.warning('Failed to parse SPACE_STATUS_JSON, defaulting to empty map: %s', je)
        space_status = {}

    # Read skip_transfer flag from on-prem.env
    skip_transfer = on_prem_values.get('skip_transfer', 'false').lower() == 'true'

    admin_server_name = topology['AdminServerName']
    admin_machine = None
    if 'Machine' in topology['Server'][admin_server_name]:
        admin_machine=topology['Server'][admin_server_name]["Machine"]
    else:
        ex = exception_helper.create_cla_exception(ExitCode.ERROR, 'WLSDPLY-32902', "Admin machine not found")
        __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
        raise ex

    # Case 1: Admin has enough space-just create all the archives, and if skip-transfer is true then don't upload or delete, else upload and delete
    if space_admin_rc == 0:
        if admin_machine in nodes:
            #Do local Discovery.  It should include any managed server registered.
            archive_result=WLSMigrationArchiver(admin_machine,model_context, OrderedDict(), base_location, model).archive("all_archives")
            if not infra_constants.SUCCESS == archive_result:
                ex = exception_helper.create_cla_exception(ExitCode.ERROR, 'WLSDPLY-32902', "Admin archive failed")
                __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
                raise ex

        for machine in nodes:
            if not machine == admin_machine:
                node_details = OrderedDict()
                listen_address = common.traverse(machine_nodes, machine, model_constants.NODE_MANAGER, model_constants.LISTEN_ADDRESS)
                init_argument_map[CommandLineArgUtil.SSH_HOST_SWITCH] = listen_address
                is_encryption_supported = EncryptionUtils.isEncryptionSupported()
                if is_encryption_supported:
                    __logger.info('WLSDPLY-20044',
                                  init_argument_map, class_name=_class_name, method_name=_method_name)
                else:
                    __logger.info('WLSDPLY-20045',
                                  init_argument_map, class_name=_class_name, method_name=_method_name)
                per_machine_model_context = __process_args(init_argument_map, is_encryption_supported)
                host_result = WLSMigrationArchiver(machine, per_machine_model_context, node_details, base_location, model).archive("all_archives")
                if not infra_constants.SUCCESS == host_result:
                    ex = exception_helper.create_cla_exception(ExitCode.ERROR, 'WLSDPLY-32902', "Node archive failed")
                    __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
                    raise ex

        if not skip_transfer:
            admin_out = model_context.get_local_output_dir()
            for fname in os.listdir(admin_out):
                for pattern in archive_patterns:
                    if fnmatch.fnmatch(fname, "*%s" % pattern):
                        upload_to_bucket(os.path.join(admin_out, fname), log_file, on_prem_values)
                        delete_local(os.path.join(admin_out, fname))
                        # remote cleanup on per-host model context
                        if per_machine_model_context:
                            delete_remote_archives(per_machine_model_context, fname)

    # Case 2: Admin has NO space for all the archives together and skip_transfer = false (Selective remote per archive + upload + delete)
    elif space_per_archive_rc == 0 and not skip_transfer:
        for machine in nodes:
            node_details = OrderedDict()
            listen_address = common.traverse(machine_nodes, machine, model_constants.NODE_MANAGER, model_constants.LISTEN_ADDRESS)
            init_argument_map[CommandLineArgUtil.SSH_HOST_SWITCH] = listen_address
            is_encryption_supported = EncryptionUtils.isEncryptionSupported()
            if is_encryption_supported:
                __logger.info('WLSDPLY-20044',
                              init_argument_map, class_name=_class_name, method_name=_method_name)
            else:
                __logger.info('WLSDPLY-20045',
                              init_argument_map, class_name=_class_name, method_name=_method_name)
            per_machine_model_context = __process_args(init_argument_map, is_encryption_supported)
            archiver = WLSMigrationArchiver(machine, per_machine_model_context, node_details, base_location, model)

            # checking per node space
            if space_status.get(listen_address, 1) == 1:
                archiver.print_per_host_todo_commands()
                __logger.warning('WLSDPLY-05027',
                                 'Not enough space on %s to create the archives. Please run the commands manually mentioned in the TODO to create the archive, '
                                 'scp to the admin host and upload to bucket.' % machine,
                                 class_name=_class_name, method_name=_method_name)
                continue

            for archive_type in ("oracle_home", "weblogic_home", "java_home", "custom_dirs"):
                result = archiver.archive(archive_type)
                if not infra_constants.SUCCESS == result:
                    ex = exception_helper.create_cla_exception(ExitCode.ERROR, 'WLSDPLY-32902', "Node archive failed")
                    __logger.throwing(ex, class_name=_class_name, method_name=_method_name)
                    raise ex

                # Upload and delete
                node_dir = per_machine_model_context.get_local_output_dir()
                for fname in os.listdir(node_dir):
                    for pattern in archive_patterns:
                        if fnmatch.fnmatch(fname, "*%s" % pattern):
                            path = os.path.join(node_dir, fname)
                            upload_to_bucket(path,log_file,on_prem_values)
                            delete_local(path)
                            # remote cleanup on per-host model context
                            if per_machine_model_context:
                                delete_remote_archives(per_machine_model_context, fname)

    # Case 3: Admin has NO space or skip_transfer = true (Manual steps only)
    else :
        __logger.warning('WLSDPLY-05027',
                         'Admin VM has insufficient space and skip_transfer = true.\n',
                         class_name=_class_name, method_name=_method_name)
        return

    if len(hosts_details) == 0:
        return

    __logger.exiting(class_name=_class_name, method_name=_method_name, result=model.get_model_resources())
    return

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

    model_file_value = model_context.get_model_file()
    try:
        model_dictionary = cla_helper.merge_model_files(model_file_value)
    except TranslateException, te:
        __logger.severe('WLSDPLY-09014', program_name, model_file_value, te.getLocalizedMessage(), error=te,
                        class_name=_class_name, method_name=_method_name)
        tool_exception = \
            exception_helper.create_exception(aliases.get_exception_type(), 'WLSDPLY-09014', program_name,
                                              model_file_value, te.getLocalizedMessage(), error=te)
        __logger.throwing(tool_exception, class_name=_class_name, method_name=_method_name)
        raise tool_exception

    filter_helper.apply_filters(model_dictionary, filter_type, model_context)

    return model_dictionary



def main(model_context):
    """
    The main entry point for the archive WLS infra tool.

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
        try:
            __archive_directories(model, model_context, helper)
        except Exception:
            traceback.print_exc()
            raise

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
    common.run_tool(main, __process_args, sys.argv, _program_name, _class_name, __logger)
