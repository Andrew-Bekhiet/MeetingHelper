import { pubsub } from "firebase-functions";
import { storage, firestore } from "firebase-admin";

export const doBackupFirestoreData = pubsub
  .schedule("0 0 * * 0")
  .onRun(async () => {
    const gcp_firestore = require("@google-cloud/firestore");
    const client = new gcp_firestore.v1.FirestoreAdminClient();
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
          await storage().bucket().deleteFiles({ prefix: "Exports/{export}" });
          await storage().bucket().deleteFiles({ prefix: "Imports/{import}" });
          await storage().bucket().deleteFiles({ prefix: "Deleted/{delete}" });
          await firestore().recursiveDelete(firestore().collection("Deleted"));
        }
        return responses;
      })
      .catch((err: any) => {
        console.error(err);
        throw new Error("Export operation failed");
      });
  });

export const updateStudyYears = pubsub
  .schedule("0 0 11 9 *")
  .onRun(async () => {
    const studyYears = await firestore()
      .collection("StudyYears")
      .orderBy("Grade")
      .get();
    const firstYear = studyYears.docs[0].data();
    const lastYear = studyYears.docs[studyYears.docs.length - 1];
    const batch = firestore().batch();

    for (let index = 1; index < studyYears.docs.length; index++) {
      batch.update(
        studyYears.docs[index - 1].ref,
        studyYears.docs[index].data()
      );
    }

    batch.set(firestore().collection("StudyYears").doc(), firstYear);
    batch.update(lastYear.ref, {
      Grade: lastYear.data().Grade + 1,
      Name: "{تم ترحيل السنة برجاء ادخال اسم}",
      IsCollegeYear: lastYear.data().Grade + 1 > 12,
    });

    await batch.commit();
  });
