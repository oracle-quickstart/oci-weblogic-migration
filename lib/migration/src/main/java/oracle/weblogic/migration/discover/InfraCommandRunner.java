package oracle.weblogic.migration.discover;

import java.io.File;
import java.text.MessageFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;


import oracle.weblogic.deploy.create.CreateException;
import static oracle.weblogic.deploy.create.ValidationUtils.validateExistingDirectory;
import static oracle.weblogic.deploy.create.ValidationUtils.validateExistingExecutableFile;
import static oracle.weblogic.deploy.create.ValidationUtils.validateNonEmptyString;
import oracle.weblogic.deploy.logging.PlatformLogger;
import oracle.weblogic.deploy.logging.WLSDeployLogFactory;
import oracle.weblogic.deploy.util.FileUtils;
import oracle.weblogic.deploy.util.ScriptRunner;
import oracle.weblogic.deploy.util.ScriptRunnerException;

public class InfraCommandRunner {
    private static final String CLASS = InfraCommandRunner.class.getName();
    private static final PlatformLogger LOGGER = WLSDeployLogFactory.getLogger("wlsdeploy.create");
    private static final List<String> EMPTY_STRING_LIST = Collections.emptyList();
    private final String scriptType;
    private final String scriptLogBasenameDefault;
    private final File scriptFile;
    private final String args;
    private int exit_code;
    private List<String> errors;
    private List<String> output;
    private Map<String, String> environmentVariables;
    /**
     * The constructor.
     *
     * @param scriptType                the map of environment variables to use for executing the external program
     * @param scriptLogBasenameDefault the base name to use for logging the stdout of the external program
     */
    public InfraCommandRunner(String scriptType, String scriptLogBasenameDefault,
                              String cmdName, String args) throws CreateException {
        final String METHOD = "<init>";
        LOGGER.entering(CLASS, METHOD, scriptType, scriptLogBasenameDefault);

        this.scriptType = validateNonEmptyString(scriptType, "script type");
        this.scriptLogBasenameDefault = validateNonEmptyString(scriptType, "script log file basename default");
        this.scriptFile = validateExistingExecutableFile(cmdName, scriptType);
        this.args=args;
        initializeEnvironment();
        LOGGER.exiting(CLASS, METHOD);
    }

    public void runScript() throws CreateException {
        final String METHOD = "runScript";
        LOGGER.entering(CLASS, METHOD);

        String[] fileComponents = FileUtils.parseFileName(this.scriptFile);
        String logFileBaseName = fileComponents.length > 0 ? fileComponents[0] : scriptLogBasenameDefault;
        ScriptRunner runner = new ScriptRunner(this.environmentVariables, logFileBaseName);

        try {
            exit_code = runner.executeScript(this.scriptFile, EMPTY_STRING_LIST, this.args);
        } catch (ScriptRunnerException sre) {
            CreateException ce = new CreateException("WLSDPLY-12013", sre, CLASS, this.scriptFile.getAbsolutePath(),
                    this.scriptType, sre.getLocalizedMessage());
            LOGGER.throwing(CLASS, METHOD, ce);
            throw ce;
        }

        if (exit_code != 0) {
            CreateException ce = new CreateException("WLSDPLY-12012", this.scriptType,
                    this.scriptFile.getAbsolutePath(), exit_code, runner.getStdoutFileName());
            LOGGER.throwing(CLASS, METHOD, ce);
            throw ce;
        }
        output = runner.getStdoutBuffer();

        LOGGER.exiting(CLASS, METHOD, exit_code);
    }



    private void initializeEnvironment() {
        Map<String, String> env = new HashMap<>(System.getenv());
        this.environmentVariables = env;
    }

    public int getExitCode() {
        return exit_code;
    }

    public List<String> getErrors() {
        return errors;
    }

    public List<String> getOutput() {
        return output;
    }
}