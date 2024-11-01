import xml.etree.ElementTree as ET
import sys

def new_property(prop_name, prop_value,namespace):
    property = ET.Element('property')
    new_name = ET.SubElement(property, 'name')
    new_name.text = prop_name
    new_value = ET.SubElement(property, 'value')
    # new_value.text = "'{}'".format(prop_value)
    new_value.text = prop_value
    return property

def enable_wallet_ds_config(xml_file, jdbc_driver_params_properties, wallet_path,output_xml_file=None):
    """Adds a sub-element to an existing element in an XML file."""

    tree = ET.parse(xml_file)
    namespaces = {
        "xmlns" : "http://xmlns.oracle.com/weblogic/jdbc-data-source"
    }
    root = tree.getroot()

    properties = root.find(jdbc_driver_params_properties,namespaces)

    if properties is None:
        properties = ET.Element('properties')
        root.append(properties)

    # wallet properties
    # oracle.jdbc.fanEnabled=false
    # oracle.net.tns_admin=/tmp/demoatp
    # oracle.net.ssl_version=1.2
    # oracle.net.ssl_server_dn_match=true
    # oracle.net.wallet_location=/tmp/demoatp
    # wallet_jdbc_fan_prop= ET.Element('property')
    # new_name = ET.SubElement(wallet_jdbc_fan_prop, 'name')
    # new_name.text = 'oracle.jdbc.fanEnabled'
    # new_value = ET.SubElement(wallet_jdbc_fan_prop, 'value')
    # new_value.text = 'false'
    # properties.append(wallet_jdbc_fan_prop)
    #
    # wallet_net_tns_admin = ET.Element('property')
    # new_name = ET.SubElement(wallet_net_tns_admin, 'name')
    # new_name.text = 'oracle.net.tns_admin'
    # new_value = ET.SubElement(wallet_net_tns_admin, 'value')
    # new_value.text = "'{}'".format(wallet_path)
    # properties.append(wallet_jdbc_fan_prop)
    # oracle.jdbc.fanEnabled=false
    wallet_jdbc_fan= new_property("oracle.jdbc.fanEnabled", 'false' ,namespaces)
    properties.append(wallet_jdbc_fan)
    # oracle.net.tns_admin=/tmp/demoatp
    wallet_net_tns_admin = new_property("oracle.net.tns_admin", wallet_path, namespaces)
    properties.append(wallet_net_tns_admin)
    # oracle.net.ssl_version=1.2
    net_ssl_version = new_property("oracle.net.ssl_version", '1.2',namespaces)
    properties.append(net_ssl_version)
    # oracle.net.ssl_server_dn_match=true
    oracle_net_ssl_dn_match=new_property("oracle.net.ssl_server_dn_match", 'true',namespaces)
    properties.append(oracle_net_ssl_dn_match)
    # oracle.net.wallet_location=/tmp/demoatp
    oracle_net_wallet_location=new_property("oracle.net.wallet_location", wallet_path,namespaces)
    properties.append(oracle_net_wallet_location)
    ET.register_namespace("","http://xmlns.oracle.com/weblogic/jdbc-data-source")
    tree.write(output_xml_file)
    # if output_xml_file is not None:
    #     tree.write(output_xml_file)
    #     print("test file xml printed")
    # else:
    #     tree.write(xml_file)
    #     print("Original xml file overwritten.")

# Example usage:
if __name__ == "__main__":
    xml_file = sys.argv[1]
    test_file =  sys.argv[2]
    element_path = "xmlns:jdbc-driver-params/xmlns:properties"
    enable_wallet_ds_config(xml_file, element_path, "/u01/domains/wallet",test_file)