#!/usr/bin/env python3
"""
Copyright (c) 2023, 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

"""


import json
import sys
import os

# Gets key, value pair.
def read_key(file_path, key_path):
    try:
        with open(file_path) as f:
            data = json.load(f)

        for part in key_path.split('.'):
            data = data[part]

        print(data)
    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError as e:
        print(f"ERROR: Key '{e.args[0]}' not found in path '{key_path}'", file=sys.stderr)
        sys.exit(1)


# Gets mutliple key, value pairs.
def read_keys(file_path, key_path):
    try:
        with open(file_path) as f:
            data = json.load(f)

        for part in key_path.split('.'):
            data = data[part]

        for k in data.keys():
            print(k)
    except FileNotFoundError:
        print(f"ERROR: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
    except KeyError as e:
        print(f"ERROR: Key '{e.args[0]}' not found in path '{key_path}'", file=sys.stderr)
        sys.exit(1)



# Gets value of the given key. Fails silently.
# Print no error to stderr, just return empty string to stdout
def get_optional_key(file_path, key):
    try:
        with open(file_path) as f:
            data = json.load(f)

        print(data.get(key, ""))
    except Exception as e:
        print("")
        sys.exit(0)


# Updates the key, value pair. If it doesn't exists, it creates one.
def update_json(file_path, key, value):
    try:
        data = {}

        if os.path.exists(file_path) and os.path.getsize(file_path) > 0:
            with open(file_path) as f:
                data = json.load(f)

        data[key] = value

        tmpfile = file_path + ".tmp"

        with open(tmpfile, "w") as f:
            json.dump(data, f, indent=2)

        os.replace(tmpfile, file_path)

    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON in file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to update JSON file: {e}", file=sys.stderr)
        sys.exit(1)


# Validates the JSON file
def validate_json(file_path):
    try:
        with open(file_path) as f:
            json.load(f)
        sys.exit(0)
    except json.JSONDecodeError as e:
        print(f"ERROR: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


# Creates an empty JSON file with an empty object {}
def ensure_json_file(file_path):
    if not os.path.isfile(file_path):
        with open(file_path, 'x') as f:
            json.dump({}, f)


def usage():
    print("Usage:")
    print("  read_key <file> <key_path>")
    print("  read_keys <file> <key_path>")
    print("  get_optional_key <file> <key>")
    print("  update_json <file> <key> <value>")
    print("  validate_json <file>")
    print("  ensure_json_file <file>")
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        usage()

    command = sys.argv[1]

    if command == "read_key" and len(sys.argv) == 4:
        read_key(sys.argv[2], sys.argv[3])
    elif command == "read_keys" and len(sys.argv) == 4:
        read_keys(sys.argv[2], sys.argv[3])
    elif command == "get_optional_key" and len(sys.argv) == 4:
        get_optional_key(sys.argv[2], sys.argv[3])
    elif command == "update_json" and len(sys.argv) == 5:
        update_json(sys.argv[2], sys.argv[3], sys.argv[4])
    elif command == "validate_json" and len(sys.argv) == 3:
        validate_json(sys.argv[2])
    elif command == "ensure_json" and len(sys.argv) == 3:
        ensure_json_file(sys.argv[2])
    else:
        usage()

