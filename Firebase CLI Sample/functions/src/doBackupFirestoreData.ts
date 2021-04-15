import * as functions from "firebase-functions";
import * as tools from "firebase-tools";
import * as admin from "firebase-admin";

export const doBackupFirestoreData = functions.pubsub
  .schedule("0 0 * * 0")
  .onRun(async () => {
    const firestore = require("@google-cloud/firestore");
    const client = new firestore.v1.FirestoreAdminClient();
    const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
    const databaseName = client.databasePath(projectId, "(default)");
    const timestamp = new Date().toISOString();

    console.log(
      `Starting backup project ${projectId} database ${databaseName} with name ${timestamp}`
    );

    return client
      .exportDocuments({
        name: databaseName,
        outputUriPrefix: `gs://${projectId}-firestore-backup/${timestamp}`,
        collectionIds: [],
      })
      .then(async (responses: any[]) => {
        const response = responses[0];
        console.log(`Operation Name: ${response["name"]}`);
        if (new Date().getDate() <= 7) {
          await admin
            .storage()
            .bucket()
            .deleteFiles({ prefix: "Exports/{export}" });
          await admin
            .storage()
            .bucket()
            .deleteFiles({ prefix: "Imports/{import}" });
          return await tools.firestore.delete("Deleted", {
            project: process.env.GCLOUD_PROJECT,
            recursive: true,
            yes: true,
          });
        }
        return responses;
      })
      .catch((err: any) => {
        console.error(err);
        throw new Error("Export operation failed");
      });
  });
