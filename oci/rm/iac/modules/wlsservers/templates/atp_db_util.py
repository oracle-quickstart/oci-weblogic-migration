# Copyright (c) 2025, Oracle Corporation and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl

import os
import sys
import oci

def log(msg):
    print(msg)

def get_md5_hash(str):
    """
    Get MD5 hash for the specified string.

    :param str:     string to be hashed.
    :return:        md5 hash value.
    """
    if sys.platform.startswith('java'):
        import md5
        m = md5.new()
        m.update(str)
    else:
        import hashlib
        m = hashlib.md5()
        m.update(str.encode())
    return m.hexdigest()

def download_atp_wallet(atp_db_id, atp_db_wallet_pwd, download_location="/tmp/atp_wallet.zip"):
    """
    Downloads ATP wallet

     :param atp_db_id:
     :param atp_db_wallet_pwd:
     :return:
    """
    try:
        principal = oci.auth.signers.InstancePrincipalsSecurityTokenSigner()
        db_client = oci.database.DatabaseClient(config={}, signer=principal)

        db_wallet_details = oci.database.models.GenerateAutonomousDatabaseWalletDetails(password=atp_db_wallet_pwd)
        response = db_client.generate_autonomous_database_wallet(atp_db_id, db_wallet_details)

        if response.status == 200:
            try:
                open(download_location, "wb").write(response.data.content)
                log("ATP Wallet downloaded")
            except Exception as e:
                log("Error: Unable to download atp wallet : {0}".format(str(e)))
                raise Exception("Unable to download atp wallet")
        else:
            log("ATP download response code : {0}".format(str(response.status)))
            raise Exception("ATP download response code [{0}]".format(str(response.status)))

    except Exception as e:
        log("Error: Unable to get ATP wallet : {0}".format(str(e)))
        raise Exception("Unable to get ATP wallet")

if __name__ == '__main__':

    if len(sys.argv) < 2:
        print ("Usage: atp_db_util.py.py <atp_db_id> <unzip_location>")
        sys.exit(1)

    atp_db_id = sys.argv[1]
    atp_db_wallet_pwd = sys.stdin.readline()
    atp_db_wallet_pwd = atp_db_wallet_pwd.strip("\n")
    download_location = sys.argv[2]

    download_atp_wallet(atp_db_id, atp_db_wallet_pwd)
    unzip_cmd = "unzip /tmp/atp_wallet.zip -d %s" % (download_location)
    os.system(unzip_cmd)