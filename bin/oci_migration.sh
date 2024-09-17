print_help() {
    # Menu Options
    echo "Usage: $0 [option] [env_name]"
    echo "Options:"
    echo "  create   Create a new virtual environment (default name: .venv)"
    echo "  pre-reqs   Validate if all pre- requisites are met"
    echo "  install  Install all dependencies - auto configure"
    echo "  discover  Discover remote or local WLS Domain"
    echo "  archive   Compress and transfer Weblogic Domain Directories to Local"
    echo "  uppload   Upload WLS Archives to Oracle Cloud Infrastructure Object Storage Bucket (OSS)"
    echo "  lift   End-to-End Weblogic On-Premise Domain lift "
    echo "  remove   Remove an existing virtual environment (default name: .venv)"
}

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_help
    return 0
fi

case "$1" in
    "create_venv")
        create_venv "$2"
        ;;
    "pre-reqs")
        activate_venv "$2"
        ;;
    "install")
        install_deps "$2"
        ;;
    "discover")
        discoverWLS.sh "$2"
        ;;
    "archive")
        remove_venv "$2"
        ;;
    "upload")
        remove_venv "$2"
        ;;
    "lift")
        remove_venv "$2"
        ;;
    "remove")
        remove_venv "$2"
        ;;
    *)
        echo "Unknown option: $1"
        print_help
        exit 1
        ;;
esac