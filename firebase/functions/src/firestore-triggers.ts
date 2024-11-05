import {
  DocumentReference,
  FieldValue,
  GeoPoint,
  Timestamp,
} from "@google-cloud/firestore";
import { firestore, storage } from "firebase-admin";
import { FirebaseDynamicLinks } from "firebase-dynamic-links";
import { firestore as firestore_1 } from "firebase-functions";
import { DateTime } from "luxon";
import { getChangeType } from "./common";
import {
  firebaseDynamicLinksAPIKey,
  firebaseDynamicLinksPrefix,
  packageName,
  projectId,
  supabaseClient,
} from "./environment";

export const onClassUpdated = firestore_1
  .document("Classes/{class}")
  .onWrite(async (change, context) => {
    try {
      const changeType = getChangeType(change);
      const changeDataAfter = change.after.data();
      const changeDataBefore = change.before.data();

      if (changeType === "update" || changeType === "create") {
        const batch = firestore().batch();
        batch.create(change.after.ref.collection("EditHistory").doc(), {
          By: changeDataAfter!.LastEdit ?? null,
          Time: FieldValue.serverTimestamp(),
          ClassId: change.after.ref,
        });
        await batch.commit();

        return;
      } else {
        console.log(
          `Deleting Class children: ${changeDataBefore!.Name}, ${
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
          .set(changeDataBefore!);

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
      const changeDataAfter = change.after.data();
      const changeDataBefore = change.before.data();

      if (changeType === "update" || changeType === "create") {
        const batch = firestore().batch();
        batch.create(change.after.ref.collection("EditHistory").doc(), {
          By: changeDataAfter!.LastEdit ?? null,
          Time: FieldValue.serverTimestamp(),
          Services: [change.after.ref],
        });
        await batch.commit();

        return;
      } else {
        console.log(
          `Deleting Service children: ${changeDataBefore!.Name}, ${
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
          .set(changeDataBefore!);

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
      const changeType = getChangeType(change);
      const changeDataAfter = change.after.data();
      const changeDataBefore = change.before.data();

      if (changeType === "delete") {
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

        console.dir(
          await supabaseClient
            ?.from("persons")
            .delete()
            .match({ firestore_id: change.before.id }),
          { depth: 4 }
        );

        if (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + change.before.id)
            .exists()
        ) {
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + change.before.id)
            .move("Deleted/" + dayID + "/PersonsPhotos/" + change.before.id);
        }

        return "OK";
      }

      const batch = firestore().batch();
      if (
        (changeDataAfter?.LastVisit as Timestamp)?.seconds !==
        (changeDataBefore?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: changeDataAfter?.LastEdit ?? null,
          Time: changeDataAfter?.LastVisit,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      if (
        (changeDataAfter?.LastConfession as Timestamp)?.seconds !==
        (changeDataBefore?.LastConfession as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("ConfessionHistory").doc(), {
          Time: changeDataAfter?.LastConfession,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      if (
        (changeDataAfter?.LastCall as Timestamp)?.seconds !==
        (changeDataBefore?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: changeDataAfter?.LastEdit ?? null,
          Time: changeDataAfter?.LastCall,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: changeDataAfter?.LastEdit ?? null,
        Time: FieldValue.serverTimestamp(),
        ClassId: changeDataAfter?.ClassId,
        PersonId: change.after.ref,
        Services: changeDataAfter?.Services ?? null,
      });

      if (changeDataAfter?.ClassId)
        batch.update(changeDataAfter?.ClassId, {
          LastEdit: changeDataAfter?.LastEdit,
          LastEditTime: FieldValue.serverTimestamp(),
        });

      if (
        (changeDataAfter?.BirthDate as Timestamp)?.seconds !==
        (changeDataBefore?.BirthDate as Timestamp)?.seconds
      ) {
        let birthDate: DateTime = DateTime.fromMillis(
          (changeDataAfter!.BirthDate as Timestamp).toMillis()!
        ).setZone("Africa/Cairo");

        if (birthDate.hour > 12) {
          birthDate = birthDate.startOf("day").plus({ days: 1 });
        } else {
          birthDate = birthDate.startOf("day");
        }

        batch.update(change.after.ref, {
          BirthDateString: birthDate.toISODate(),
          BirthDateMonthDay: `${birthDate.month}-${birthDate.day}`,
          BirthDateMonth: birthDate.month,
        });
      }

      await batch.commit();

      const grade: number = (
        await (
          (changeDataAfter?.StudyYear ??
            (await changeDataAfter!.ClassId.get()).data()
              ?.StudyYear) as DocumentReference
        )?.get()
      )?.data()?.Grade;
      console.log(grade);

      const service = (
        await supabaseClient
          ?.from("services")
          .select("id")
          .filter("studyYearFrom", "lte", grade)
          .filter("studyYearTo", "gte", grade)
          .limit(1)
          .single()
      )?.data;

      await supabaseClient?.from("persons").upsert(
        {
          firestore_id: change.after.id,
          name: changeDataAfter!["Name"],
          isStudent: true,
          geolocation:
            changeDataAfter!["Location"] == null
              ? null
              : "Point(" +
                (changeDataAfter!["Location"] as GeoPoint).longitude +
                " " +
                (changeDataAfter!["Location"] as GeoPoint).latitude +
                ")",
        },
        { onConflict: "firestore_id" }
      );

      const supabase_id = (
        await supabaseClient?.from("persons").select().match({
          firestore_id: change.after.id,
          name: changeDataAfter!["Name"],
        })
      )?.data?.[0].id;

      if (service != null)
        console.dir(
          await supabaseClient?.from("persons_services").upsert({
            personID: supabase_id,
            serviceID: service.id,
          }),
          { depth: 4 }
        );

      if (
        changeType === "update" &&
        changeDataAfter?.ClassId &&
        (!(changeDataAfter?.ClassId as DocumentReference)?.isEqual(
          change.before.data()?.ClassId
        ) ||
          !refArraysEqual(
            changeDataAfter?.Services ? changeDataAfter?.Services : [],
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
                ClassId: changeDataAfter!["ClassId"],
                Services: changeDataAfter!["Services"],
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
      const changeType = getChangeType(change);
      const changeDataAfter = change.after.data();
      const changeDataBefore = change.before.data();

      if (changeType === "delete") {
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
          .set(changeDataBefore!);

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
        changeType === "update" &&
        !(changeDataAfter?.ClassId as DocumentReference)?.isEqual(
          changeDataBefore?.ClassId
        )
      ) {
        batch.update(
          firestore().collection("Users").doc(changeDataAfter?.UID),
          { ClassId: changeDataAfter?.ClassId }
        );
      }
      if (changeDataAfter?.Name !== change.before?.data()?.Name) {
        batch.update(
          firestore().collection("Users").doc(changeDataAfter?.UID),
          { Name: changeDataAfter?.Name }
        );
      }
      if (
        (changeDataAfter?.LastVisit as Timestamp)?.seconds !==
        (change.before?.data()?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: changeDataAfter?.LastEdit ?? null,
          Time: changeDataAfter?.LastVisit,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      if (
        (changeDataAfter?.LastConfession as Timestamp)?.seconds !==
        (change.before?.data()?.LastConfession as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("ConfessionHistory").doc(), {
          Time: changeDataAfter?.LastConfession,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      if (
        (changeDataAfter?.LastCall as Timestamp)?.seconds !==
        (change.before?.data()?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: changeDataAfter?.LastEdit ?? null,
          Time: changeDataAfter?.LastCall,
          ClassId: changeDataAfter?.ClassId,
          PersonId: change.after.ref,
          Services: changeDataAfter?.Services ?? null,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: changeDataAfter?.LastEdit ?? null,
        Time: FieldValue.serverTimestamp(),
        ClassId: changeDataAfter?.ClassId,
        PersonId: change.after.ref,
        Services: changeDataAfter?.Services ?? null,
      });

      if (changeDataAfter?.ClassId)
        batch.update(changeDataAfter?.ClassId, {
          LastEdit: changeDataAfter?.LastEdit,
          LastEditTime: FieldValue.serverTimestamp(),
        });
      await batch.commit();

      if (
        changeType === "update" &&
        changeDataAfter?.ClassId &&
        (!(changeDataAfter?.ClassId as DocumentReference)?.isEqual(
          changeDataBefore?.ClassId
        ) ||
          !refArraysEqual(
            changeDataAfter?.Services ? changeDataAfter?.Services : [],
            changeDataBefore?.Services ? changeDataBefore?.Services : []
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
                ClassId: changeDataAfter!["ClassId"],
                Services: changeDataAfter!["Services"],
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
    const changeType = getChangeType(change);
    const changeDataAfter = change.after.data();
    const changeDataBefore = change.before.data();

    if (changeType !== "delete") {
      if (
        changeType === "update" &&
        !(changeDataAfter?.ClassId as DocumentReference)?.isEqual(
          changeDataBefore?.ClassId
        )
      ) {
        console.log(
          "Skipped: ClassId changed from " +
            (changeDataBefore?.ClassId as DocumentReference)?.path +
            " to " +
            (changeDataAfter?.ClassId as DocumentReference)?.path
        );
        return "OK";
      }
      const data: Record<string, any> = {
        LastEdit: changeDataAfter?.RecordedBy,
      };

      if (
        context.params.type == "Meeting" ||
        context.params.type == "Kodas" ||
        context.params.type == "Confession"
      )
        data["Last" + context.params.type] = changeDataAfter?.Time;
      else {
        data["Last"] = {};
        data["Last"][context.params.type] = changeDataAfter?.Time;
      }

      return await firestore()
        .collection("Persons")
        .doc(changeDataAfter?.ID)
        .set(data, { merge: true });
    } else {
      if (
        !(
          await firestore()
            .collection("Persons")
            .doc(changeDataBefore?.ID)
            .get()
        ).exists
      )
        return;
      const batch = firestore().batch();
      const queryRes = await firestore()
        .collection("Persons")
        .doc(changeDataBefore?.ID)
        .collection("EditHistory")
        .orderBy("Time", "desc")
        .limit(2)
        .get();
      batch.delete(queryRes.docs[0].ref);

      const queryRes2 = await firestore()
        .collectionGroup(context.params.type)
        .where("ID", "==", changeDataBefore?.ID)
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
        firestore().collection("Persons").doc(changeDataBefore?.ID),
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
    const changeType = getChangeType(change);
    const changeDataAfter = change.after.data();
    const changeDataBefore = change.before.data();

    if (changeType !== "delete") {
      if (
        changeType === "update" &&
        !(changeDataAfter?.ClassId as DocumentReference)?.isEqual(
          changeDataBefore?.ClassId
        )
      ) {
        console.log(
          "Skipped: ClassId changed from " +
            (changeDataBefore?.ClassId as DocumentReference)?.path +
            " to " +
            (changeDataAfter?.ClassId as DocumentReference)?.path
        );
        return "OK";
      }
      const data: Record<string, any> = {
        LastEdit: changeDataAfter?.RecordedBy,
      };
      if (
        context.params.type == "Meeting" ||
        context.params.type == "Kodas" ||
        context.params.type == "Confession"
      )
        data["Last" + context.params.type] = changeDataAfter?.Time;
      else {
        data["Last"] = {};
        data["Last"][context.params.type] = changeDataAfter?.Time;
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
        firestore().collection("Persons").doc(changeDataBefore?.ID),
        data,
        { merge: true }
      );
      return await batch.commit();
    }
  });

export const onInvitationCreated = firestore_1
  .document("Invitations/{invitation}")
  .onCreate(async (change) => {
    if (
      !firebaseDynamicLinksAPIKey ||
      !firebaseDynamicLinksPrefix ||
      !packageName
    ) {
      return null;
    }

    await change.ref.update({
      Link: (
        await new FirebaseDynamicLinks(firebaseDynamicLinksAPIKey).createLink({
          dynamicLinkInfo: {
            domainUriPrefix: firebaseDynamicLinksPrefix,
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
