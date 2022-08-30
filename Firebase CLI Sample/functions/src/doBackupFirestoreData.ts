import { FieldValue, v1 } from "@google-cloud/firestore";
import { firestore, storage } from "firebase-admin";
import { pubsub, runWith } from "firebase-functions";
export const doBackupFirestoreData = runWith({
  timeoutSeconds: 540,
  memory: "1GB",
})
  .pubsub.schedule("0 0 * * 0")
  .onRun(async () => {
    const client = new v1.FirestoreAdminClient();
    const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
    const databaseName = client.databasePath(projectId!, "(default)");
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
      .catch((err: any) => {
        console.error(err);
        throw new Error("Export operation failed");
      });
  });

export const deleteStaleData = runWith({
  timeoutSeconds: 540,
  memory: "1GB",
})
  .pubsub.schedule("0 1 * * 0")
  .onRun(async () => {
    const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;

    if (new Date().getDate() <= 7) {
      const writer = firestore().bulkWriter();
      writer.onWriteResult(async (ref) => {
        if (
          ref.path.match(/^Deleted\/\d{4}-\d{2}-\d{2}\/([^\\/])+\/([^\\/])+$/)
        ) {
          const entityRef = firestore().collection(ref.parent.id).doc(ref.id);

          if ((await entityRef.get()).exists) return;

          await firestore().recursiveDelete(entityRef, writer);

          if (ref.parent.id == "Services") {
            let pendingChanges = firestore().batch();

            const docs = [
              ...(
                await firestore()
                  .collection("Persons")
                  .where("Services", "array-contains", entityRef)
                  .get()
              ).docs,
              ...(
                await firestore()
                  .collection("UsersData")
                  .where("Services", "array-contains", entityRef)
                  .get()
              ).docs,
            ];
            for (let i = 0, l = docs.length; i < l; i++) {
              if ((i + 1) % 500 === 0) {
                await pendingChanges.commit();
                pendingChanges = firestore().batch();
              }
              if (
                !(docs[i].data().ClassId as
                  | firestore.DocumentReference
                  | null
                  | undefined) &&
                !(
                  docs[i].data().Services as
                    | Array<firestore.DocumentReference>
                    | null
                    | undefined
                )?.filter((r) => !r.isEqual(entityRef))?.length
              )
                pendingChanges.delete(docs[i].ref);
              else
                pendingChanges.update(docs[i].ref, {
                  Services: FieldValue.arrayRemove(entityRef),
                });
            }

            await pendingChanges.commit();

            pendingChanges = firestore().batch();

            const usersData = (
              await firestore()
                .collection("UsersData")
                .where("Services", "array-contains", entityRef)
                .get()
            ).docs;

            for (let i = 0; i < usersData.length; i++) {
              if ((i + 1) % 500 === 0) {
                await pendingChanges.commit();
                pendingChanges = firestore().batch();
              }
              pendingChanges.update(usersData[i].ref, {
                Services: FieldValue.arrayRemove(entityRef),
              });
            }
            await pendingChanges.commit();
          } else if (ref.parent.id == "Classes") {
            let pendingChanges = firestore().batch();

            const snapshot = await firestore()
              .collection("Persons")
              .where("ClassId", "==", entityRef)
              .get();
            for (let i = 0, l = snapshot.docs.length; i < l; i++) {
              if ((i + 1) % 500 === 0) {
                await pendingChanges.commit();
                pendingChanges = firestore().batch();
              }
              if (
                !(
                  snapshot.docs[i].data().Services as
                    | Array<firestore.DocumentReference>
                    | null
                    | undefined
                )?.length
              )
                pendingChanges.delete(snapshot.docs[i].ref);
              else
                pendingChanges.update(snapshot.docs[i].ref, {
                  ClassId: null,
                });
            }
          } else if (ref.parent.id == "Persons") {
            let deleteBatch = firestore().batch();

            const historyToDelete = [
              ...(
                await firestore()
                  .collectionGroup("Meeting")
                  .where("ID", "==", entityRef.id)
                  .get()
              ).docs,
              ...(
                await firestore()
                  .collectionGroup("Confession")
                  .where("ID", "==", entityRef.id)
                  .get()
              ).docs,
              ...(
                await firestore()
                  .collectionGroup("Kodas")
                  .where("ID", "==", entityRef.id)
                  .get()
              ).docs,
            ];

            let batchCount = 0;
            for (
              let i = 0, l = historyToDelete.length;
              i < l;
              i++, batchCount++
            ) {
              if (batchCount % 500 === 0) {
                await deleteBatch.commit();
                deleteBatch = firestore().batch();
              }
              deleteBatch.delete(historyToDelete[i].ref);
            }
            await deleteBatch.commit();
          }
        }
      });

      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .deleteFiles({ prefix: "Exports/{export}" });
      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .deleteFiles({ prefix: "Imports/{import}" });
      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .deleteFiles({ prefix: "Deleted/{delete}" });
      await firestore().recursiveDelete(
        firestore().collection("Deleted"),
        writer
      );
    }
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
