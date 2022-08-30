import {
  DocumentReference,
  FieldValue,
  Timestamp,
} from "@google-cloud/firestore";
import { firestore, storage } from "firebase-admin";
import { FirebaseDynamicLinks } from "firebase-dynamic-links";
// import { region } from "firebase-functions";
import { firestore as firestore_1 } from "firebase-functions";
import {
  firebase_dynamic_links_key,
  firebase_dynamic_links_prefix,
  packageName,
  projectId,
} from "./adminPassword";
import { getChangeType } from "./common";

// const firestore_1 = region("europe-west1").firestore;

export const onClassUpdated = firestore_1
  .document("Classes/{class}")
  .onWrite(async (change, context) => {
    try {
      const changeType = getChangeType(change);
      if (changeType === "update" || changeType === "create") {
        const batch = firestore().batch();
        batch.create(change.after.ref.collection("EditHistory").doc(), {
          By: change.after.data()!.LastEdit ?? null,
          Time: FieldValue.serverTimestamp(),
          ClassId: change.after.ref,
        });
        return await batch.commit();
      } else {
        console.log(
          `Deleting Class children: ${change.before.data()!.Name}, ${
            change.before.id
          }`,
          " that have null or empty Services"
        );

        let pendingChanges = firestore().batch();

        const snapshot = await firestore()
          .collection("Persons")
          .where(
            "ClassId",
            "==",
            firestore().doc("Classes/" + context.params.class)
          )
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
        }

        const dayID = new Date().toISOString().split("T")[0];

        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .set({ Time: Timestamp.now() });
        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .collection("Classes")
          .doc(change.before.id)
          .set(change.before.data()!);

        await pendingChanges.commit();

        if (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("ClassesPhotos/" + change.before.id)
            .exists()
        )
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("ClassesPhotos/" + change.before.id)
            .move("Deleted/" + dayID + "/ClassesPhotos/" + change.before.id);
      }
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Class.onWrite on Class: ${
          change.after.data()?.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onServiceUpdated = firestore_1
  .document("Services/{service}")
  .onWrite(async (change, context) => {
    try {
      const changeType = getChangeType(change);
      if (changeType === "update" || changeType === "create") {
        const batch = firestore().batch();
        batch.create(change.after.ref.collection("EditHistory").doc(), {
          By: change.after.data()!.LastEdit ?? null,
          Time: FieldValue.serverTimestamp(),
          Services: [change.after.ref],
        });
        return await batch.commit();
      } else {
        console.log(
          `Deleting Service children: ${change.before.data()!.Name}, ${
            change.before.id
          }`,
          " that have null or empty ClassId"
        );

        let pendingChanges = firestore().batch();

        const docs = [
          ...(
            await firestore()
              .collection("Persons")
              .where(
                "Services",
                "array-contains",
                firestore().doc("Services/" + context.params.service)
              )
              .get()
          ).docs,
          ...(
            await firestore()
              .collection("UsersData")
              .where(
                "Services",
                "array-contains",
                firestore().doc("Services/" + context.params.service)
              )
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
            )?.filter((r) => !r.isEqual(change.before.ref))?.length
          )
            pendingChanges.delete(docs[i].ref);
        }
        const dayID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .set({ Time: Timestamp.now() });
        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .collection("Services")
          .doc(change.before.id)
          .set(change.before.data()!);

        await pendingChanges.commit();

        pendingChanges = firestore().batch();

        const usersData = (
          await firestore()
            .collection("UsersData")
            .where(
              "AdminServices",
              "array-contains",
              firestore().doc("Services/" + context.params.service)
            )
            .get()
        ).docs;

        for (let i = 0; i < usersData.length; i++) {
          if ((i + 1) % 500 === 0) {
            await pendingChanges.commit();
            pendingChanges = firestore().batch();
          }
          pendingChanges.update(usersData[i].ref, {
            AdminServices: FieldValue.arrayRemove(change.before.ref),
          });
        }
        await pendingChanges.commit();

        if (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("ServicesPhotos/" + change.before.id)
            .exists()
        )
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("ServicesPhotos/" + change.before.id)
            .move("Deleted/" + dayID + "/ServicesPhotos/" + change.before.id);
      }
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Service.onWrite on Service: ${
          change.after.data()?.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onPersonUpdated = firestore_1
  .document("Persons/{person}")
  .onWrite(async (change) => {
    try {
      if (getChangeType(change) === "delete") {
        const dayID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .set({ Time: Timestamp.now() });
        await firestore()
          .collection("Deleted")
          .doc(dayID)
          .collection("Persons")
          .doc(change.before.id)
          .set(change.before.data()!);

        if (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + change.before.id)
            .exists()
        )
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + change.before.id)
            .move("Deleted/" + dayID + "/PersonsPhotos/" + change.before.id);
        return "OK";
      }

      const batch = firestore().batch();
      if (
        (change.after.data()?.LastVisit as Timestamp)?.seconds !==
        (change.before?.data()?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: change.after.data()?.LastEdit ?? null,
          Time: change.after.data()?.LastVisit,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      if (
        (change.after.data()?.LastConfession as Timestamp)?.seconds !==
        (change.before?.data()?.LastConfession as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("ConfessionHistory").doc(), {
          Time: change.after.data()?.LastConfession,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      if (
        (change.after.data()?.LastCall as Timestamp)?.seconds !==
        (change.before?.data()?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: change.after.data()?.LastEdit ?? null,
          Time: change.after.data()?.LastCall,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: change.after.data()?.LastEdit ?? null,
        Time: FieldValue.serverTimestamp(),
        ClassId: change.after.data()?.ClassId,
        PersonId: change.after.ref,
        Services: change.after.data()?.Services ?? null,
      });

      if (change.after.data()?.ClassId)
        batch.update(change.after.data()?.ClassId, {
          LastEdit: change.after.data()?.LastEdit,
          LastEditTime: FieldValue.serverTimestamp(),
        });
      await batch.commit();

      if (
        getChangeType(change) === "update" &&
        change.after.data()?.ClassId &&
        (!(change.after.data()?.ClassId as DocumentReference).isEqual(
          change.before.data()?.ClassId
        ) ||
          !refArraysEqual(
            change.after.data()?.Services ? change.after.data()?.Services : [],
            change.before.data()?.Services ? change.before.data()?.Services : []
          ))
      ) {
        let pendingChanges = firestore().batch();

        let batchCount = 0;

        let snapshot: firestore.QuerySnapshot<firestore.DocumentData>;
        for (const collection of ["Meeting", "Kodas", "Confession"]) {
          snapshot = await firestore()
            .collectionGroup(collection)
            .where("ID", "==", change.after.id)
            .get();
          for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
            if (batchCount % 500 === 0) {
              await pendingChanges.commit();
              pendingChanges = firestore().batch();
            }
            if (snapshot.docs[i].ref.parent.parent?.parent.id === "History") {
              pendingChanges.update(snapshot.docs[i].ref, {
                ClassId: change.after.data()!["ClassId"],
                Services: change.after.data()!["Services"],
              });
              console.log(
                "Update Person " +
                  change.after.ref.path +
                  " ClassId and Services in record " +
                  snapshot.docs[i].id
              );
            }
          }
        }

        await pendingChanges.commit();
      }
      return "OK";
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Person.onWrite on Person: ${
          change.after.data()?.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onUserUpdated = firestore_1
  .document("UsersData/{user}")
  .onWrite(async (change) => {
    try {
      if (getChangeType(change) === "delete") {
        const docID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .set({ Time: Timestamp.now() });
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .collection("UsersData")
          .doc(change.before.id)
          .set(change.before.data()!);

        let deleteBatch = firestore().batch();

        const historyToDelete = [
          ...(
            await firestore()
              .collectionGroup("Meeting")
              .where("ID", "==", change.before.id)
              .get()
          ).docs,
          ...(
            await firestore()
              .collectionGroup("Confession")
              .where("ID", "==", change.before.id)
              .get()
          ).docs,
          ...(
            await firestore()
              .collectionGroup("Kodas")
              .where("ID", "==", change.before.id)
              .get()
          ).docs,
        ];

        let batchCount = 0;
        for (let i = 0, l = historyToDelete.length; i < l; i++, batchCount++) {
          if (batchCount % 500 === 0) {
            await deleteBatch.commit();
            deleteBatch = firestore().batch();
          }
          deleteBatch.delete(historyToDelete[i].ref);
        }
        await deleteBatch.commit();
        return "OK";
      }

      const batch = firestore().batch();
      if (
        getChangeType(change) === "update" &&
        !(change.after.data()?.ClassId as DocumentReference)?.isEqual(
          change.before.data()?.ClassId
        )
      ) {
        batch.update(
          firestore().collection("Users").doc(change.after.data()?.UID),
          { ClassId: change.after.data()?.ClassId }
        );
      }
      if (change.after.data()?.Name !== change.before?.data()?.Name) {
        batch.update(
          firestore().collection("Users").doc(change.after.data()?.UID),
          { Name: change.after.data()?.Name }
        );
      }
      if (
        (change.after.data()?.LastVisit as Timestamp)?.seconds !==
        (change.before?.data()?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: change.after.data()?.LastEdit ?? null,
          Time: change.after.data()?.LastVisit,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      if (
        (change.after.data()?.LastConfession as Timestamp)?.seconds !==
        (change.before?.data()?.LastConfession as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("ConfessionHistory").doc(), {
          Time: change.after.data()?.LastConfession,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      if (
        (change.after.data()?.LastCall as Timestamp)?.seconds !==
        (change.before?.data()?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: change.after.data()?.LastEdit ?? null,
          Time: change.after.data()?.LastCall,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
          Services: change.after.data()?.Services ?? null,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: change.after.data()?.LastEdit ?? null,
        Time: FieldValue.serverTimestamp(),
        ClassId: change.after.data()?.ClassId,
        PersonId: change.after.ref,
        Services: change.after.data()?.Services ?? null,
      });

      if (change.after.data()?.ClassId)
        batch.update(change.after.data()?.ClassId, {
          LastEdit: change.after.data()?.LastEdit,
          LastEditTime: FieldValue.serverTimestamp(),
        });
      await batch.commit();

      if (
        getChangeType(change) === "update" &&
        change.after.data()?.ClassId &&
        (!(change.after.data()?.ClassId as DocumentReference).isEqual(
          change.before.data()?.ClassId
        ) ||
          !refArraysEqual(
            change.after.data()?.Services ? change.after.data()?.Services : [],
            change.before.data()?.Services ? change.before.data()?.Services : []
          ))
      ) {
        let pendingChanges = firestore().batch();

        let batchCount = 0;

        let snapshot: firestore.QuerySnapshot<firestore.DocumentData>;
        for (const collection of ["Meeting", "Kodas", "Confession"]) {
          snapshot = await firestore()
            .collectionGroup(collection)
            .where("ID", "==", change.after.id)
            .get();
          for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
            if (batchCount % 500 === 0) {
              await pendingChanges.commit();
              pendingChanges = firestore().batch();
            }
            if (
              snapshot.docs[i].ref.parent.parent?.parent.id ===
              "ServantsHistory"
            ) {
              pendingChanges.update(snapshot.docs[i].ref, {
                ClassId: change.after.data()!["ClassId"],
                Services: change.after.data()!["Services"],
              });
              console.log(
                "Update Users Person " +
                  change.after.ref.path +
                  " ClassId and Services in record " +
                  snapshot.docs[i].id
              );
            }
          }
        }

        await pendingChanges.commit();
      }
      return "OK";
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Person.onWrite on Person: ${
          change.after.data()?.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onHistoryDayDeleted = firestore_1
  .document("History/{day}")
  .onDelete(async (change) => {
    return firestore().recursiveDelete(change.ref);
  });

export const onHistoryRecordWrite = firestore_1
  .document("History/{day}/{type}/{doc}")
  .onWrite(async (change, context) => {
    if (getChangeType(change) !== "delete") {
      if (
        getChangeType(change) === "update" &&
        !(change.after.data()?.ClassId as DocumentReference).isEqual(
          change.before.data()?.ClassId
        )
      ) {
        console.log(
          "Skipped: ClassId changed from " +
            (change.before.data()?.ClassId as DocumentReference).path +
            " to " +
            (change.after.data()?.ClassId as DocumentReference).path
        );
        return "OK";
      }
      const data: Record<string, any> = {
        LastEdit: change.after.data()?.RecordedBy,
      };

      if (
        context.params.type == "Meeting" ||
        context.params.type == "Kodas" ||
        context.params.type == "Confession"
      )
        data["Last" + context.params.type] = change.after.data()?.Time;
      else {
        data["Last"] = {};
        data["Last"][context.params.type] = change.after.data()?.Time;
      }

      return await firestore()
        .collection("Persons")
        .doc(change.after.data()?.ID)
        .set(data, { merge: true });
    } else {
      if (
        !(
          await firestore()
            .collection("Persons")
            .doc(change.before.data()?.ID)
            .get()
        ).exists
      )
        return;
      const batch = firestore().batch();
      const queryRes = await firestore()
        .collection("Persons")
        .doc(change.before.data()?.ID)
        .collection("EditHistory")
        .orderBy("Time", "desc")
        .limit(2)
        .get();
      batch.delete(queryRes.docs[0].ref);

      const queryRes2 = await firestore()
        .collectionGroup(context.params.type)
        .where("ID", "==", change.before.data()?.ID)
        .orderBy("Time", "desc")
        .limit(1)
        .get();
      const data: Record<string, any> = {
        LastEdit: queryRes.docs[1].data()?.By,
      };
      if (queryRes2.empty) {
        if (
          context.params.type == "Meeting" ||
          context.params.type == "Kodas" ||
          context.params.type == "Confession"
        )
          data["Last" + context.params.type] = null;
        else {
          data["Last"] = {};
          data["Last"][context.params.type] = null;
        }
      } else {
        if (
          context.params.type == "Meeting" ||
          context.params.type == "Kodas" ||
          context.params.type == "Confession"
        )
          data["Last" + context.params.type] = queryRes2.docs[0].data()?.Time;
        else {
          data["Last"] = {};
          data["Last"][context.params.type] = queryRes2.docs[0].data()?.Time;
        }
      }
      batch.set(
        firestore().collection("Persons").doc(change.before.data()?.ID),
        data,
        { merge: true }
      );
      return await batch.commit();
    }
  });

export const onServantsHistoryRecordWrite = firestore_1
  .document("ServantsHistory/{day}/{type}/{doc}")
  .onWrite(async (change, context) => {
    const personId = context.params.doc;

    if (getChangeType(change) !== "delete") {
      if (
        getChangeType(change) === "update" &&
        !(change.after.data()?.ClassId as DocumentReference).isEqual(
          change.before.data()?.ClassId
        )
      ) {
        console.log(
          "Skipped: ClassId changed from " +
            (change.before.data()?.ClassId as DocumentReference).path +
            " to " +
            (change.after.data()?.ClassId as DocumentReference).path
        );
        return "OK";
      }
      const data: Record<string, any> = {
        LastEdit: change.after.data()?.RecordedBy,
      };
      if (
        context.params.type == "Meeting" ||
        context.params.type == "Kodas" ||
        context.params.type == "Confession"
      )
        data["Last" + context.params.type] = change.after.data()?.Time;
      else {
        data["Last"] = {};
        data["Last"][context.params.type] = change.after.data()?.Time;
      }

      return await firestore()
        .collection("UsersData")
        .doc(personId)
        .set(data, { merge: true });
    } else {
      if (
        !(await firestore().collection("UsersData").doc(personId).get()).exists
      )
        return;
      const batch = firestore().batch();
      const queryRes = await firestore()
        .collection("UsersData")
        .doc(personId)
        .collection("EditHistory")
        .orderBy("Time", "desc")
        .limit(2)
        .get();
      batch.delete(queryRes.docs[0].ref);

      const queryRes2 = await firestore()
        .collectionGroup(context.params.type)
        .where("ID", "==", personId)
        .orderBy("Time", "desc")
        .limit(1)
        .get();
      const data: Record<string, any> = {
        LastEdit: queryRes.docs[1].data()?.By,
      };
      if (queryRes2.empty) {
        if (
          context.params.type == "Meeting" ||
          context.params.type == "Kodas" ||
          context.params.type == "Confession"
        )
          data["Last" + context.params.type] = null;
        else {
          data["Last"] = {};
          data["Last"][context.params.type] = null;
        }
      } else {
        if (
          context.params.type == "Meeting" ||
          context.params.type == "Kodas" ||
          context.params.type == "Confession"
        )
          data["Last" + context.params.type] = queryRes2.docs[0].data()?.Time;
        else {
          data["Last"] = {};
          data["Last"][context.params.type] = queryRes2.docs[0].data()?.Time;
        }
      }
      batch.set(
        firestore().collection("Persons").doc(change.before.data()?.ID),
        data,
        { merge: true }
      );
      return await batch.commit();
    }
  });
export const onInvitationCreated = firestore_1
  .document("Invitations/{invitation}")
  .onCreate(async (change) => {
    await change.ref.update({
      Link: (
        await new FirebaseDynamicLinks(firebase_dynamic_links_key).createLink({
          dynamicLinkInfo: {
            domainUriPrefix: firebase_dynamic_links_prefix,
            link:
              "https://meetinghelper.com/register?InvitationId=" + change.id,
            androidInfo: {
              androidPackageName: packageName,
              androidFallbackLink:
                "https://github.com/Andrew-Bekhiet/MeetingHelper/releases/",
              androidMinPackageVersionCode: "3",
            },
          },
          suffix: { option: "UNGUESSABLE" },
        })
      ).shortLink,
    });
    return;
  });

function refArraysEqual(
  a: Array<DocumentReference>,
  b: Array<DocumentReference>
): boolean {
  if (a === b) return true;
  if (a == null || b == null) return false;
  if (a.length !== b.length) return false;

  return a.every((o) => b.find((o2) => o.isEqual(o2)));
}
