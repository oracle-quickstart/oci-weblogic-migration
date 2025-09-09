/**
* Copyright (c) 2016, 2024, Oracle and/or its affiliates.  All rights reserved.
* This software is dual-licensed to you under the Universal Permissive License (UPL) 1.0 as shown at https://oss.oracle.com/licenses/upl or Apache License 2.0 as shown at http://www.apache.org/licenses/LICENSE-2.0. You may choose either license.
*/

package oracle.weblogic.migration.archive;

import com.oracle.bmc.ConfigFileReader;
import com.oracle.bmc.Region;
import com.oracle.bmc.auth.AuthenticationDetailsProvider;
import com.oracle.bmc.auth.ConfigFileAuthenticationDetailsProvider;
import com.oracle.bmc.objectstorage.ObjectStorage;
import com.oracle.bmc.objectstorage.ObjectStorageClient;
import com.oracle.bmc.objectstorage.model.CreateBucketDetails;
import com.oracle.bmc.objectstorage.model.BucketSummary;
import com.oracle.bmc.objectstorage.requests.GetNamespaceRequest;
import com.oracle.bmc.objectstorage.requests.GetObjectRequest;
import com.oracle.bmc.objectstorage.requests.CreateBucketRequest;
import com.oracle.bmc.objectstorage.responses.CreateBucketResponse;
import com.oracle.bmc.objectstorage.responses.GetNamespaceResponse;
import com.oracle.bmc.objectstorage.responses.GetObjectResponse;
import com.oracle.bmc.objectstorage.requests.GetWorkRequestRequest;
import com.oracle.bmc.objectstorage.responses.GetWorkRequestResponse;
import com.oracle.bmc.objectstorage.requests.PutObjectRequest;
import com.oracle.bmc.objectstorage.requests.HeadObjectRequest;
import com.oracle.bmc.objectstorage.model.WorkRequest;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;

import java.io.InputStream;

public class OCIArchiveHelper {

    /**
     * The entry point for OCIArchiveHelper.
     *
     * @param args Arguments to provide to OCIArchiveHelper. The following arguments are expected:
     *     <ul>
     *       <li>The first argument is the OCID of the compartment.
     *       <li>The second is the name of bucket to create
     *       <li>The third is the name of source object to copy to*
     *     </ul>
     */
    public static void main(String[] args) throws Exception {

        String configurationFilePath = "~/.oci/config";
        String profile = "DEFAULT";

        if (args.length != 3) {
            throw new IllegalArgumentException(
                    "Unexpected number of arguments received. Consult the script header comments for expected arguments");
        }

        final String compartmentId = args[0];
        final String sourceBucket = args[1];
        final String sourceObject = args[2];
        // Configuring the AuthenticationDetailsProvider. It's assuming there is a default OCI
        // config file
        // "~/.oci/config", and a profile in that config with the name "DEFAULT". Make changes to
        // the following
        // line if needed and use ConfigFileReader.parse(configurationFilePath, profile);

        final ConfigFileReader.ConfigFile configFile = ConfigFileReader.parseDefault();

        final AuthenticationDetailsProvider provider =
                new ConfigFileAuthenticationDetailsProvider(configFile);

        ObjectStorage client =
                ObjectStorageClient.builder().build(provider);

        System.out.println("Getting the namespace.");
        GetNamespaceResponse namespaceResponse =
                client.getNamespace(GetNamespaceRequest.builder().build());
        String namespaceName = namespaceResponse.getValue();

        System.out.println("Creating the source bucket.");
        CreateBucketDetails createSourceBucketDetails =
                CreateBucketDetails.builder()
                        .compartmentId(compartmentId)
                        .name(sourceBucket)
                        .build();

        CreateBucketRequest createSourceBucketRequest =
                CreateBucketRequest.builder()
                        .namespaceName(namespaceName)
                        .createBucketDetails(createSourceBucketDetails)
                        .build();
        CreateBucketResponse createBucketResponse = client.createBucket(createSourceBucketRequest);

//         CreateBucketResponse.builder().opcRequestId(createSourceBucketRequest.getOpcClientRequestId()).build();


        System.out.println("Creating the source object");
        PutObjectRequest putObjectRequest =
                PutObjectRequest.builder()
                        .namespaceName(namespaceName)
                        .bucketName(sourceBucket)
                        .objectName(sourceObject)
                        .contentLength(4L)
                        .putObjectBody(
                                new ByteArrayInputStream("data".getBytes(StandardCharsets.UTF_8)))
                        .build();
        client.putObject(putObjectRequest);

        System.out.println("Wait for copy to finish.");
        GetWorkRequestRequest getWorkRequestRequest =
                GetWorkRequestRequest.builder()
                        .workRequestId(putObjectRequest.getOpcClientRequestId())
                        .build();
        GetWorkRequestResponse getWorkRequestResponse =
                client.getWaiters().forWorkRequest(getWorkRequestRequest).execute();
        WorkRequest.Status status = getWorkRequestResponse.getWorkRequest().getStatus();
        System.out.println("Work request is now in " + status + " state.");

        if (status == WorkRequest.Status.Completed) {
            System.out.println("Verify that the object has been copied.");
            HeadObjectRequest headObjectRequest =
                    HeadObjectRequest.builder()
                            .namespaceName(namespaceName)
                            .bucketName(sourceBucket)
                            .objectName(sourceObject)
                            .build();
            client.headObject(headObjectRequest);
        }

        client.close();
    }
}
