"""
Copyright (c) 2025, Oracle Corporation and/or its affiliates.
Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

This script processes a WebLogic Deploy Tooling (WDT) model file and extracts
unique JDBC connection URLs from all JDBCSystemResource entries.

The script:
  - Loads a WDT model (JSON or YAML)
  - Extracts JDBC URLs from JDBCSystemResource/JDBCDriverParams
  - Ensures uniqueness and order preservation
  - Reads bucket_name from on-prem.env
  - Renders Mustache templates
  - Outputs Terraform-compatible files

Usage:
  python discover_ds.py --input_model <Path_to_discovered.json> --env_file <path_to_on_prem_env_file>

Arguments:
  --input_model    Path to input discovered.json
  --env_file       Path to the on-prem.env file

Output:
  The script generates Terraform-compatible files in the "oci/generated" directory.
  The output includes:
    - db-connection-string.auto.tfvars
    - schema.yaml
    - locals-db-connection-string.tf
    - data-oci-db-resources.tf
    - variables-db-connection-string.tf
"""

import os
import json
import yaml
from collections import OrderedDict
import re

# Resolve toolHome from script location
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOOL_HOME = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))

# Templates directory (toolHome-relative)
TEMPLATE_DIR = os.path.join(TOOL_HOME, "lib", "python", "templates")

# ---------------------------------------------------------
# Mustache-like template renderer
# ---------------------------------------------------------

def render_template_string(template, context):
    """
    YAML-safe Mustache-like template renderer in pure Python.

    This function renders a template string using a simplified Mustache-style
    syntax, suitable for generating YAML or Terraform-compatible files.

    Supported syntax:
      - {{var}}        → Replaces with `context['var']` (escaped/str)
      - {{{var}}}      → Replaces with `context['var']` literally (unescaped)
      - {{#section}} ... {{/section}} → Section rendering:
          * Boolean: renders block if True; skips if False
          * String: renders block if "true" (case-insensitive); skips if "false"
          * List of dicts: renders block for each item, merging item keys into context
          * Nested sections are supported recursively

    Arguments:
        template (str): Raw template string containing Mustache-like placeholders.
        context (dict): Dictionary containing variables and section values for rendering.

    Returns:
        str: Fully rendered template string, ready for YAML/Terraform use.
    """

    section_re = re.compile(
        r'(?m)^[ \t]*{{#(\w+)}}\s*\n(.*?)\n[ \t]*{{/\1}}\s*$',
        re.DOTALL
    )

    def render_section(match):
        """
        Render a single Mustache section ({{#section}} ... {{/section}}).

        Args:
            match: regex match object for the section

        Returns:
            str: rendered section text or empty string if section evaluates to False/empty
        """
        section = match.group(1)
        block = match.group(2)
        value = context.get(section)

        # Boolean section: render block if True
        if isinstance(value, bool):
            return render_template_string(block, context) if value else ""

        # String section: render block if value is "true" (case-insensitive)
        if isinstance(value, str):
            return render_template_string(block, context) if value.lower() == "true" else ""

        # List of dicts: render block for each item, merging context
        if isinstance(value, list):
            rendered = []
            for item in value:
                sub_ctx = context.copy()
                if isinstance(item, dict):
                    sub_ctx.update(item)
                rendered.append(render_template_string(block, sub_ctx))
            return "\n".join(rendered)

        # If section not found or unsupported type, return empty string
        return ""

    # Recursively resolve all sections until template no longer changes
    prev = None
    while prev != template:
        prev = template
        template = section_re.sub(render_section, template)

    # Replace triple braces {{{ var }}} literally
    template = re.sub(
        r'{{{\s*(\w+)\s*}}}',
        lambda m: str(context.get(m.group(1), "")),
        template
    )

    # Replace double braces {{ var }} normally
    template = re.sub(
        r'{{\s*(\w+)\s*}}',
        lambda m: str(context.get(m.group(1), "")),
        template
    )

    # Collapse excessive blank lines to at most two
    template = re.sub(r'\n{3,}', '\n\n', template)

    # Ensure final output ends with a single newline
    return template.rstrip() + "\n"


def render_template_file(template_path, output_path, context):
    """
    Read a .mustache template from file, render it using context,
    and write the output to the final path.

    Arguments:
        template_path (str): Path to template file
        output_path (str): Path to write rendered output
        context (dict): Variables for rendering
    """

    with open(template_path, "r") as f:
        tmpl = f.read()

    rendered = render_template_string(tmpl, context)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    with open(output_path, "w") as f:
        f.write(rendered)


# ---------------------------------------------------------
# Load model
# ---------------------------------------------------------

def load_model(path):
    """
    Load a WDT model file (YAML or JSON).

    Arguments:
        path (str): Path to the WDT model file.

    Returns:
        dict: Parsed WDT model.
    """
    if path.lower().endswith((".yaml", ".yml")):
        return yaml.safe_load(open(path))
    return json.load(open(path))


# ---------------------------------------------------------
# Read bucket_name from on-prem.env
# ---------------------------------------------------------

def get_bucket_name(env_file):
    """
    Read bucket_name and skip_transfer behavior from the provided on-prem.env file.

    Follows WDT tool logic:
      - If skip_transfer=true → return empty bucket name
      - Otherwise return bucket_name value

    Arguments:
        env_file (str): Path to the on-prem.env file

    Returns:
        str: bucket_name or "" if skip_transfer is enabled
    """

    if not os.path.exists(env_file):
        return ""

    bucket = ""
    skip = False

    with open(env_file, "r") as f:
        for line in f:
            if "=" not in line or line.startswith("#"):
                continue

            k, v = [x.strip().strip('"').strip("'") for x in line.split("=", 1)]

            if k == "skip_transfer" and v.lower() in ("true", "1", "yes"):
                skip = True
            elif k == "bucket_name":
                bucket = v

    return "" if skip else bucket


# ---------------------------------------------------------
# JDBC URL extraction
# ---------------------------------------------------------

def extract_jdbc_urls_from_driverparams(params):
    """
    Extract JDBC connection URL(s) from a JDBCDriverParams block.

    Supports:
        URL
        Url
        url

    Arguments:
        params (dict): JDBCDriverParams object

    Returns:
        list[str]: JDBC URLs
    """
    if not params:
        return []

    for key in ("URL", "Url", "url"):
        if key in params:
            val = params[key]

            if isinstance(val, list):
                return [v for v in val if isinstance(v, str)]

            if isinstance(val, str):
                return [val]

            return []

    return []


def extract_datasources(model):
    """
    Extract all JDBC datasources from the WDT model.

    Arguments:
        model (dict): Loaded WDT model

    Returns:
        dict with:
            datasources: list of {datasourceName, datasourceUrl}
            hasDatasources: bool
            is_mds: "true"/"false"
    """

    resources = model.get("resources", {})
    jdbc_sys = resources.get("JDBCSystemResource", {})

    unique_urls = OrderedDict()
    is_mds = False

    for name, ds in jdbc_sys.items():
        jdbc_res = ds.get("JdbcResource", {})
        driver_params = jdbc_res.get("JDBCDriverParams", {})
        data_params = jdbc_res.get("JDBCDataSourceParams", {})

        if "DataSourceList" in data_params:
            is_mds = True

        urls = extract_jdbc_urls_from_driverparams(driver_params)
        for u in urls:
            unique_urls[u] = True

    entries = [
        {"datasourceName": str(i), "url": url}
        for i, url in enumerate(unique_urls.keys())
    ]

    return {
        "datasources": entries,
        "hasDatasources": bool(entries),
        "is_mds": "true" if is_mds else "false"
    }


# ---------------------------------------------------------
# GENERIC PLACEHOLDER NORMALIZATION
# ---------------------------------------------------------

def normalize_placeholders(obj):
    """
    Replace WDT/ORM placeholders like {value} with empty string.
    Applied recursively to dicts/lists.
    """
    if isinstance(obj, dict):
        return {k: normalize_placeholders(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [normalize_placeholders(v) for v in obj]
    if isinstance(obj, str):
        if re.fullmatch(r"\{[^}]+\}", obj):
            return ""
        return obj
    return obj

# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main(input_model, env_file):
    """
    Main orchestration function.

    Arguments:
        input_model (str): Path to WDT model
        env_file (str): Path to on-prem.env file
    """

    # Always use the fixed output directory
    out_dir = os.path.join(TOOL_HOME, "oci", "generated")
    os.makedirs(out_dir, exist_ok=True)

    # Load WDT model
    model = load_model(input_model)

    # Read bucket name
    bucket = get_bucket_name(env_file)

    # Extract datasource URLs
    ds_info = extract_datasources(model)
    ds_info["oci_bucket_name"] = bucket

    # Templates to generate
    template_map = {
        "db-connection-string.auto.tfvars": "db-connection-string.auto.tfvars.mustache",
        "schema.yaml": "schema.yaml.mustache",
        "locals-db-connection-string.tf": "locals-db-connection-string.tf.mustache",
        "data-oci-db-resources.tf": "data-oci-db-resources.tf.mustache",
        "variables-db-connection-string.tf": "variables-db-connection-string.tf.mustache"
    }

    # Render each mustache template into output files
    for outfile, tmpl in template_map.items():
        render_template_file(
            os.path.join(TEMPLATE_DIR, tmpl),
            os.path.join(out_dir, outfile),
            ds_info
        )

    # Summary output
    print("\nGenerated Terraform datasource artifacts in:")
    print(os.path.abspath(out_dir))

    print("\nDiscovered JDBC URLs:")
    for d in ds_info["datasources"]:
        print("  -", d["datasourceUrl"])


# ---------------------------------------------------------
# CLI entry
# ---------------------------------------------------------

if __name__ == "__main__":
    import argparse

    # Command-line argument parser
    p = argparse.ArgumentParser(description="WDT-compatible JDBC discovery (no Jinja2)")
    p.add_argument("--input_model", required=True, help="Path to input discovered.json")
    p.add_argument("--env_file", required=True, help="Path to the on-prem.env file")
    args = p.parse_args()

    # Invoke main
    main(
        args.input_model,
        args.env_file
    )