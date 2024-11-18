from xml.dom.minidom import parseString,parse, Node
import sys

def new_property(doc, prop_name, prop_value):
    prop = doc.createElement("property")
    name = doc.createElement("name")
    name.appendChild(doc.createTextNode(prop_name))
    prop.appendChild(name)
    value = doc.createElement("value")
    value.appendChild(doc.createTextNode(prop_value))
    prop.appendChild(value)
    return prop

def create_wallet_props(doc, properties, wallet_prop):
    for name,value in wallet_prop.items():
        properties.appendChild(new_property(doc,name,value))


def enable_wallet_ds_config(xmlfile, jdbc_string, wallet_path,output_xml_file=None):
    """Adds a sub-element to an existing element in an XML file."""

    wallet_prop ={
        "oracle.jdbc.fanEnabled": "false",
        "oracle.net.tns_admin": wallet_path,
        "oracle.net.ssl_version":"1.2",
        "oracle.net.ssl_server_dn_match":"true",
        "oracle.net.wallet_location":wallet_path
    }

    document=parse(xmlfile)
    node = document.documentElement
    jdbc_data_source= document.getElementsByTagName("jdbc-data-source")[0]
    jdbc_params=jdbc_data_source.getElementsByTagName("jdbc-driver-params")[0]
    url=jdbc_params.getElementsByTagName("url")
    if url is None or url.length == 0:
        raise Exception("Datasource mal formed. Must include url attribute")
    if jdbc_string is not None or len(jdbc_string) > 0:
        url[0].firstChild.data = jdbc_string
    properties=jdbc_params.getElementsByTagName("properties")

    if properties is None or properties.length == 0:
        print("properties does not exist")
        properties = document.createElement("properties")
        jdbc_params.appendChild(properties)

    property_list = properties[0].getElementsByTagName("property")

    # Check if Prop exist and replace or add
    for wallet_prop_key, wallet_prop_value in wallet_prop.items():
        found = False
        for prop in property_list:
            name = prop.getElementsByTagName("name")[0]
            value = prop.getElementsByTagName("value")[0]
            if name.firstChild.data == wallet_prop_key :
                print("found entry "+ wallet_prop_key)
                value.firstChild.data = wallet_prop_value
                found=True
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
        #outfile.write(document.toprettyxml().replace(u'<?xml version="1.0" ?>',
        #                                             u'<?xml version="1.0" encoding="UTF-8"?>' ))
        outfile.write(xml_to_write)
        outfile.close()


if __name__ == "__main__":
    if len(sys.argv)<2:
        print ("Usage: ds_change_xml_config.py ${weblogic jdbc config file} ${wallet_path} ${jdbc url property value}")
        sys.exit(1)
    xml_file = sys.argv[1]
    wallet_path = sys.argv[2]
    jdbc_string = sys.argv[3]
    # test_file =  sys.argv[4]
    enable_wallet_ds_config(xml_file, jdbc_string,wallet_path)