# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

from xml.dom.minidom import parseString,parse, Node
import sys


def enable_wallet_ds_config(xmlfile, jdbc_string, output_xml_file=None):
    """Adds a sub-element to an existing element in an XML file."""

    document=parse(xmlfile)
    node = document.documentElement
    jdbc_data_source= document.getElementsByTagName("jdbc-data-source")[0]
    jdbc_params=jdbc_data_source.getElementsByTagName("jdbc-driver-params")[0]
    url=jdbc_params.getElementsByTagName("url")
    if url is None or url.length == 0:
        raise Exception("Datasource mal formed. Must include url attribute")
    if jdbc_string is not None or len(jdbc_string) > 0:
        url[0].firstChild.data = jdbc_string

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
        print ("Usage: ds_change_xml_config_w_db_system.py ${weblogic jdbc config file} ${jdbc url property value}")
        sys.exit(1)
    xml_file = sys.argv[1]
    jdbc_string = sys.argv[2]
    # test_file =  sys.argv[4]
    enable_wallet_ds_config(xml_file, jdbc_string)