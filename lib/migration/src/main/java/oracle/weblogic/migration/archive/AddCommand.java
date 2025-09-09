/*
 * Copyright (c) 2023, Oracle and/or its affiliates.
 * Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
 */
package oracle.weblogic.migration.archive;

import picocli.CommandLine.Command;
import picocli.CommandLine.Option;
//import oracle.weblogic.migration.archive.add.*;

@Command(
        name = "add",
        header = "Add items to the archive file.",
        description = "\n Command-line options:",
        commandListHeading = "%nSubcommands:%n",
        subcommands = {
//                AddWLSHomeCommand.class,
//                AddJavaHomeCommand.class,
//                AddDomainHomeCommand.class,
//                AddCustomCommand.class
        }
)
public class AddCommand {
    @Option(
            names = { "-help" },
            description = "Get help for the archiveHelper add command",
            usageHelp = true
    )
    private boolean helpRequested = false;
}


