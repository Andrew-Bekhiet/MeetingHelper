import { FieldValue, v1 } from "@google-cloud/firestore";
import { auth, firestore, storage } from "firebase-admin";
import { UserRecord } from "firebase-admin/auth";
import { pubsub, runWith } from "firebase-functions/v1";
import { projectId } from "./environment";

export const doBackupFirestoreData = runWith({
  timeoutSeconds: 540,
  memory: "1GB",
})
  .pubsub.schedule("0 0 * * 0")
  .onRun(async () => {
    const client = new v1.FirestoreAdminClient();
    const databaseName = client.databasePath(projectId!, "(default)");
    const timestamp = new Date().toISOString();

    console.log(
      `Starting backup project ${projectId} database ${databaseName} with name ${timestamp}`
    );

    const servicesIds = (
      await firestore().collection("Services").get()
    ).docs.map((doc) => doc.id);

    return client
      .exportDocuments({
        name: databaseName,
        outputUriPrefix: `gs://${projectId}-firestore-backup/${timestamp}`,
        collectionIds: [
          "Churches",
          "Classes",
          "Colleges",
          "Exams",
          "Fathers",

          "History",

          "Kodas",
          "Meeting",
          "Confession",
          "ConfessionHistory",
          "Tanawol",
          "TanawolHistory",
          "VisitHistory",
          "CallHistory",
          "FatherVisitHistory",

          "Invitations",
          "Persons",
          "Schools",
          "ServantsHistory",
          "Services",
          "StudyYears",
          "Users",
          "UsersData",
          ...servicesIds,
        ],
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
        .deleteFiles({ prefix: "Exports/" });
      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .deleteFiles({ prefix: "Imports/" });
      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .deleteFiles({ prefix: "Deleted/" });
      await firestore().recursiveDelete(
        firestore().collection("Deleted"),
        writer
      );
    }
  });

export const deleteUnapprovedAccounts = pubsub
  .schedule("0 0 * * 0")
  .onRun(async () => {
    const users = await getAllUsers();

    for (const user of users.filter(
      (u) => u.customClaims?.["approved"] !== true
    )) {
      console.log(
        `Deleting unapproved user ${user.uid} with email: ${user.email}`
      );
      console.log(`User claims: ${JSON.stringify(user.customClaims)}`);

      await auth().deleteUser(user.uid);
    }
  });

export const updateStudyYears = pubsub
  .schedule("0 0 11 9 *")
  .timeZone("Africa/Cairo")
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

async function getAllUsers(): Promise<UserRecord[]> {
  const result: Array<UserRecord> = [];
  let nextPageToken: string | undefined = undefined;

  do {
    const { users, pageToken } = await auth().listUsers(1000, nextPageToken);

    nextPageToken = pageToken;
    result.push(...users);
  } while (nextPageToken);

  return result;
}
