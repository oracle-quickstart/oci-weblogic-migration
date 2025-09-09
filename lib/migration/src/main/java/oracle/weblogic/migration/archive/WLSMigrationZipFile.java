package oracle.weblogic.migration.archive;
//
//import oracle.weblogic.deploy.exception.ExceptionHelper;
//import oracle.weblogic.deploy.logging.PlatformLogger;
//import oracle.weblogic.deploy.logging.WLSDeployLogFactory;
//import oracle.weblogic.deploy.util.WLSDeployArchiveIOException;
import oracle.weblogic.deploy.util.WLSDeployZipFile;
//
import java.io.File;
import java.io.IOException;
//import java.io.InputStream;
//import java.util.LinkedHashMap;
//import java.util.Map;
//import java.util.regex.Pattern;
//import java.util.zip.ZipEntry;
//import java.util.zip.ZipFile;
//
public class WLSMigrationZipFile extends WLSDeployZipFile {
//    private static final PlatformLogger LOGGER = WLSDeployLogFactory.getLogger("wlsmigration.archive");
//    private static final String CLASS = WLSMigrationZipFile.class.getName();
//    private static final int ZIP_FILE_OPEN_MODE = ZipFile.OPEN_READ;
//    private static final char DOT = '.';
//    private static final char OPEN_PAREN_CHAR = '(';
//    private static final String OPEN_PAREN = "(";
//    private static final char CLOSE_PAREN_CHAR = ')';
//    private static final String CLOSE_PAREN = ")";
//    private static final char ZIP_SEP_CHAR = '/';
//    private static final String ZIP_SEP = "/";
//    private static final Pattern RENAME_QUALIFIER_REGEX = Pattern.compile("^\\(([1-9]\\d*)\\)$");
//    private static final int READ_BUFFER_SIZE = 4096;
//
//    private static final int MAX_DIGITS = Integer.toString(Integer.MAX_VALUE).length() - 1;
//    private static final String ARCHIVE_RENAME_PATTERN_REGEX = ".+\\([0-9]{1," + MAX_DIGITS + "}\\)/?$";
//    private static final Pattern ARCHIVE_RENAME_PATTERN = Pattern.compile(ARCHIVE_RENAME_PATTERN_REGEX);
//    private static final int ARCHIVE_RENAME_INITIAL_NUMBER = 1;
//
//    private File file;
//    private ZipFile openZipFile;
//    private boolean newFile;
//
    public WLSMigrationZipFile(File file) {
        super(file);
    }
//
//    /**
//     * Add the provided directory entry to the unsaved changes list, optionally renaming it to prevent conflicts.
//     *
//     * @param entryName the entry name to add
//     * @param rename whether to rename the entry to prevent conflicts
//     * @return the name of the added entry
//     * @throws WLSDeployArchiveIOException if an IOException occurred while adding the entry
//     */
//    public String addZipDirectoryEntry(String entryName, boolean rename) throws WLSDeployArchiveIOException {
//        final String METHOD = "addZipDirectoryEntry";
//
//        LOGGER.entering(CLASS, METHOD, entryName, rename);
////        closeOpenZipFile();
//
//        String newEntryName = entryName;
//        if (!entryName.endsWith(ZIP_SEP)) {
//            newEntryName = entryName + ZIP_SEP;
//        }
//
//        if (rename && isRenameNecessary(newEntryName)) {
//            LOGGER.finer("WLSDPLY-01507", entryName);
//            newEntryName = getNextUniqueDirectoryName(entryName);
//            LOGGER.finer("WLSDPLY-01508", entryName, newEntryName);
//            if (!newEntryName.endsWith(ZIP_SEP)) {
//                newEntryName += ZIP_SEP;
//            }
//        }
//
//        boolean success = addZipDirectoryEntry(newEntryName);
//        if (!success) {
//            newEntryName = null;
//        }
//        LOGGER.exiting(CLASS, METHOD, newEntryName);
//        return newEntryName;
//    }
//
//    /**
//     * Adds the provided directory entry to the zip if the zip does not have an entry with the same name.
//     *
//     * @param key the name of the entry to add
//     * @return whether or not the entry was added
//     * @throws WLSDeployArchiveIOException if an IOException occurred while adding the entry
//     */
//    public boolean addZipDirectoryEntry(String key) throws WLSDeployArchiveIOException {
//        final String METHOD = "addZipDirectoryEntry";
//
//        LOGGER.entering(CLASS, METHOD, key);
//        closeOpenZipFile();
//
//        boolean addedEntry = true;
//        LinkedHashMap<String, ZipEntry> zipEntriesMap = getZipFileEntries(getFile());
//        if (zipEntriesMap.containsKey(key)) {
//            LOGGER.finer("WLSDPLY-01509", getFileName(), key);
//            addedEntry = false;
//        }
//        // still true so ok to proceed
//        if (addedEntry) {
//            LOGGER.finer("WLSDPLY-01510", getFileName(), key);
//            LinkedHashMap<String, InputStream> newEntries = new LinkedHashMap<>();
//            newEntries.put(key, null);
//            saveChangesToZip(zipEntriesMap, newEntries);
//            LOGGER.finer("WLSDPLY-01511", getFileName(), key);
//        }
//        LOGGER.exiting(CLASS, METHOD, addedEntry);
//        return addedEntry;
//    }
//
//    /**
//     * Add the provided directory entry and all of its contents to the zip file, renaming the directory
//     * entry name to prevent conflicts.
//     *
//     * @param entryName the name of the directory entry to add
//     * @param directory the directory to add including all of its content, recursively
//     * @return the entry name used to store the directory or null if the add failed
//     * @throws WLSDeployArchiveIOException if an IOException occurred while adding the entry
//     * @throws IllegalArgumentException if the file provided is not a valid directory
//     */
//    public String addDirectoryZipEntries(String entryName, File directory) throws WLSDeployArchiveIOException {
//        final String METHOD = "addDirectoryZipEntries";
//
//        LOGGER.entering(CLASS, METHOD, entryName, directory);
//        closeOpenZipFile();
//
//        if (!directory.exists()) {
//            String message = ExceptionHelper.getMessage("WLSDPLY-01423", directory.getAbsolutePath());
//            IllegalArgumentException iae = new IllegalArgumentException(message);
//            LOGGER.throwing(CLASS, METHOD, iae);
//            throw iae;
//        } else if (!directory.isDirectory()) {
//            String message = ExceptionHelper.getMessage("WLSDPLY-01424", directory.getAbsolutePath());
//            IllegalArgumentException iae = new IllegalArgumentException(message);
//            LOGGER.throwing(CLASS, METHOD, iae);
//            throw iae;
//        }
//
//        String newEntryName = entryName;
//        if (!newEntryName.endsWith(ZIP_SEP)) {
//            newEntryName += ZIP_SEP;
//        }
//        if (isRenameNecessary(newEntryName)) {
//            LOGGER.finer("WLSDPLY-01507", entryName);
//            newEntryName = getNextUniqueDirectoryName(newEntryName);
//            LOGGER.finer("WLSDPLY-01508", entryName, newEntryName);
//        }
//
//        // Now, we need to add the top-level entry and recurse to add entries.  Don't need to worry about renaming
//        // any other elements since the unique directory name protects us from collisions.
//        //
//        String rootEntryName = newEntryName;
//        if (!rootEntryName.endsWith(ZIP_SEP)) {
//            rootEntryName += ZIP_SEP;
//        }
//        LinkedHashMap<String, ZipEntry> existingEntries = getZipFileEntries(getFile());
//        LinkedHashMap<String, InputStream> newEntries = new LinkedHashMap<>();
//        try {
//            addDirectoryToUnsavedMap(newEntries, directory, rootEntryName);
//            saveChangesToZip(existingEntries, newEntries);
//        } finally {
//            cleanupUnsavedEntries(newEntries);
//        }
//        LOGGER.exiting(CLASS, METHOD, newEntryName);
//        return newEntryName;
//    }
//
//    private void closeOpenZipFile() {
//        final String METHOD = "closeOpenZipFile";
//
//        LOGGER.entering(CLASS, METHOD);
//        if (getOpenZipFile() != null) {
//            LOGGER.finer("WLSDPLY-01513", getFileName());
//            ZipFile zf = getOpenZipFile();
//            try {
//                zf.close();
//            } catch (IOException ioe) {
//                LOGGER.warning("WLSDPLY-01514", ioe, getFileName(), ioe.getLocalizedMessage());
//                // continue since this is best effort only
//            } finally {
//                setOpenZipFile(null);
//            }
//        }
//        LOGGER.exiting(CLASS, METHOD);
//    }
//
//    private boolean isRenameNecessary(String entryName) throws WLSDeployArchiveIOException {
//        LOGGER.entering(entryName);
//
//        boolean renameNeeded = false;
//        Map<String, ZipEntry> zipEntryMap = getZipFileEntries(getFile());
//        // This is tricky.  If the entry is a file, then looking at the containment is sufficient.
//        // However, if it is a directory, the raw directory entry may or may not be in the zip.
//        // We need to look at each entry to see if any entries start with the entry name.
//        //
//        if (zipEntryMap.containsKey(entryName)) {
//            LOGGER.finest("WLSDPLY-01534", entryName);
//            renameNeeded = true;
//        } else if (entryName.endsWith(ZIP_SEP)) {
//            for (String key : zipEntryMap.keySet()) {
//                if (key.startsWith(entryName)) {
//                    LOGGER.finest("WLSDPLY-01534", entryName);
//                    renameNeeded = true;
//                    break;
//                }
//            }
//        }
//        LOGGER.exiting(renameNeeded);
//        return renameNeeded;
//    }
//
}
