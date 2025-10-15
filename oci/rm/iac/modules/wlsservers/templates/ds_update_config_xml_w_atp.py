# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

from xml.dom.minidom import parse, Node
import sys

def new_property(doc, prop_name, prop_value):
    """Create a new <property> XML element with name and value."""
    prop = doc.createElement("property")
    name = doc.createElement("name")
    name.appendChild(doc.createTextNode(prop_name))
    prop.appendChild(name)
    value = doc.createElement("value")
    value.appendChild(doc.createTextNode(prop_value))
    prop.appendChild(value)
    return prop

def enable_wallet_ds_config(xmlfile, jdbc_string, wallet_path, output_xml_file=None):
    """Modifies the JDBC XML file to enable wallet-based secure connection."""

    wallet_prop = {
        "oracle.jdbc.fanEnabled": "false",
        "oracle.net.tns_admin": wallet_path,
        "oracle.net.ssl_version": "1.2",
        "oracle.net.ssl_server_dn_match": "true",
        "oracle.net.wallet_location": wallet_path
    }

    document = parse(xmlfile)
    jdbc_data_source = document.getElementsByTagName("jdbc-data-source")[0]
    jdbc_params = jdbc_data_source.getElementsByTagName("jdbc-driver-params")[0]
    # Update JDBC URL
    url = jdbc_params.getElementsByTagName("url")
    if url is None or url.length == 0:
        raise Exception("Datasource mal formed. Must include url attribute")
    if jdbc_string is not None and len(jdbc_string) > 0:
        url[0].firstChild.data = jdbc_string.strip()

    # Handle <properties> node
    properties=jdbc_params.getElementsByTagName("properties")
    if properties is None or properties.length == 0:
        print("[INFO] No <properties> node found. Creating one.")
        new_props = document.createElement("properties")
        jdbc_params.appendChild(new_props)
        properties = jdbc_params.getElementsByTagName("properties")  # Re-fetch updated nodeeibccblltll

    property_list = properties[0].getElementsByTagName("property")

    # Check if Prop exist and replace or add
    for wallet_prop_key, wallet_prop_value in wallet_prop.items():
        found = False
        for prop in property_list:
            name = prop.getElementsByTagName("name")[0]
            if name.firstChild and name.firstChild.data.strip() == wallet_prop_key:
                print(f"[INFO] Updating existing property: {wallet_prop_key}")

                # Update all <value> or <encrypted-value-encrypted> nodes
                value_nodes = prop.getElementsByTagName("value")
                encrypted_nodes = prop.getElementsByTagName("encrypted-value-encrypted")

                if value_nodes:
                    for value_node in value_nodes:
                        if value_node.firstChild:
                            value_node.firstChild.data = wallet_prop_value
                        else:
                            value_node.appendChild(document.createTextNode(wallet_prop_value))
                elif encrypted_nodes:
                    for enc_node in encrypted_nodes:
                        if enc_node.firstChild:
                            enc_node.firstChild.data = wallet_prop_value
                        else:
                            enc_node.appendChild(document.createTextNode(wallet_prop_value))
                else:
                    print(f"Warning: No <value> or <encrypted-value-encrypted> found for {wallet_prop_key}")
                found = True
                break
        # Property not found — create it
        if not found:
            properties[0].appendChild(new_property(document,wallet_prop_key,wallet_prop_value))
    #
    # print(properties)
    # # wallet properties
    # # oracle.jdbc.fanEnabled=false
    # # oracle.net.tns_admin=/tmp/demoatp
    # # oracle.net.ssl_version=1.2
    # # oracle.net.ssl_server_dn_match=true
    # # oracle.net.wallet_location=/tmp/demoatp

    if output_xml_file is not None and len(output_xml_file) > 0:
        fileName=output_xml_file
        print("test file xml printed")
    else:
        fileName=xmlfile
        print("Original xml file overwritten.")
    # replacing JDBC config file.
    out_byte = document.toprettyxml(encoding="utf-8")
    xml_to_write = out_byte.decode("utf-8")
    with open(fileName, mode='w', encoding="utf-8") as outfile:
        outfile.write(xml_to_write)
        outfile.close()


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print ("Usage: ds_change_xml_config.py ${weblogic jdbc config file} ${wallet_path} ${jdbc url property value}")
        sys.exit(1)
    xml_file = sys.argv[1]
    wallet_path = sys.argv[2]
    jdbc_string = sys.argv[3]
    enable_wallet_ds_config(xml_file, jdbc_string, wallet_path)