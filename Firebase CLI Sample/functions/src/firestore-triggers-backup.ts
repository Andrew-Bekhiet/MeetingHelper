import * as functions from "firebase-functions";

import { auth, firestore } from "firebase-admin";
import {
  Timestamp,
  FieldValue,
  DocumentReference,
} from "@google-cloud/firestore";
import { FirebaseDynamicLinks } from "firebase-dynamic-links";

import { getChangeType } from "./common";

export const onClassUpdated = functions.firestore
  .document("Classes/{class}")
  .onWrite(async (change, context) => {
    try {
      const changeType = getChangeType(change);
      if (changeType === "update" || changeType === "create") {
        const batch = firestore().batch();
        batch.create(change.after.ref.collection("EditHistory").doc(), {
          By: change.after.data()!.LastEdit,
          Time: FieldValue.serverTimestamp(),
          ClassId: change.after.ref,
        });
        return await batch.commit();
      } else {
        console.log(
          `Deleting Class children: ${change.before.data()!.Name}, ${
            change.before.id
          }`
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
          pendingChanges.delete(snapshot.docs[i].ref);
        }
        const docID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .set({ Time: Timestamp.now() });
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .collection("Classes")
          .doc(change.before.id)
          .set(change.before.data()!);
        return pendingChanges.commit();
      }
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Class.onWrite on Class: ${
          change.after.data()!.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onPersonUpdated = functions.firestore
  .document("Persons/{person}")
  .onWrite(async (change) => {
    try {
      if (getChangeType(change) === "delete") {
        const docID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .set({ Time: Timestamp.now() });
        return await firestore()
          .collection("Deleted")
          .doc(docID)
          .collection("Persons")
          .doc(change.before.id)
          .set(change.before.data()!);
      }

      const batch = firestore().batch();
      if (
        (change.after.data()?.LastVisit as Timestamp)?.seconds !==
        (change.before?.data()?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: change.after.data()?.LastEdit,
          Time: change.after.data()?.LastVisit,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
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
        });
      }
      if (
        (change.after.data()?.LastCall as Timestamp)?.seconds !==
        (change.before?.data()?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: change.after.data()?.LastEdit,
          Time: change.after.data()?.LastCall,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: change.after.data()?.LastEdit,
        Time: FieldValue.serverTimestamp(),
        ClassId: change.after.data()?.ClassId,
        PersonId: change.after.ref,
      });

      batch.update(change.after.data()?.ClassId, {
        LastEdit: change.after.data()?.LastEdit,
        LastEditTime: FieldValue.serverTimestamp(),
      });
      await batch.commit();

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

export const onUserUpdated = functions.firestore
  .document("UsersData/{user}")
  .onWrite(async (change) => {
    try {
      if (getChangeType(change) === "delete") {
        const docID = new Date().toISOString().split("T")[0];
        await firestore()
          .collection("Deleted")
          .doc(docID)
          .set({ Time: Timestamp.now() });
        return await firestore()
          .collection("Deleted")
          .doc(docID)
          .collection("UsersData")
          .doc(change.before.id)
          .set(change.before.data()!);
      }

      const batch = firestore().batch();
      if (change.after.data()?.ClassId !== change.before?.data()?.ClassId) {
        batch.update(
          firestore().collection("Users").doc(change.after.data()!.UID),
          { ClassId: change.after.data()!.ClassId }
        );
      }
      if (change.after.data()?.Name !== change.before?.data()?.Name) {
        batch.update(
          firestore().collection("Users").doc(change.after.data()!.UID),
          { Name: change.after.data()!.Name }
        );
      }
      if (
        (change.after.data()?.LastVisit as Timestamp)?.seconds !==
        (change.before?.data()?.LastVisit as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("VisitHistory").doc(), {
          By: change.after.data()?.LastEdit,
          Time: change.after.data()?.LastVisit,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
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
        });
      }
      if (
        (change.after.data()?.LastCall as Timestamp)?.seconds !==
        (change.before?.data()?.LastCall as Timestamp)?.seconds
      ) {
        batch.create(change.after.ref.collection("CallHistory").doc(), {
          By: change.after.data()?.LastEdit,
          Time: change.after.data()?.LastCall,
          ClassId: change.after.data()?.ClassId,
          PersonId: change.after.ref,
        });
      }
      batch.create(change.after.ref.collection("EditHistory").doc(), {
        By: change.after.data()?.LastEdit,
        Time: FieldValue.serverTimestamp(),
        ClassId: change.after.data()?.ClassId,
        PersonId: change.after.ref,
      });

      batch.update(change.after.data()!.ClassId, {
        LastEdit: change.after.data()?.LastEdit,
        LastEditTime: FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return "OK";
    } catch (err) {
      console.error(err);
      console.error(
        `Error occured while executing Person.onWrite on Person: ${
          change.after.data()!.Name
        }, ${change.after.id}`
      );
    }
    return null;
  });

export const onHistoryDayDeleted = functions.firestore
  .document("History/{day}")
  .onDelete(async (change) => {
    return firestore().recursiveDelete(change.ref);
  });

export const onHistoryRecordWrite = functions.firestore
  .document("History/{day}/{type}/{doc}")
  .onWrite(async (change, context) => {
    if (getChangeType(change) !== "delete") {
      if (
        getChangeType(change) === "update" &&
        change.after.data()?.ClassId !== change.before.data()?.ClassId
      )
        return (
          "Skipped: ClassId changed from " +
          (change.before.data()?.ClassId as DocumentReference).path +
          " to " +
          (change.after.data()?.ClassId as DocumentReference).path
        );
      const data: Record<string, any> = {
        LastEdit: change.after.data()?.RecordedBy,
      };
      data["Last" + context.params.type] = change.after.data()?.Time;
      return await firestore()
        .collection("Persons")
        .doc(change.after.data()!.ID)
        .update(data);
    } else {
      const batch = firestore().batch();
      const queryRes = await firestore()
        .collection("Persons")
        .doc(change.before.data()!.ID)
        .collection("EditHistory")
        .orderBy("Time", "desc")
        .limit(2)
        .get();
      batch.delete(queryRes.docs[0].ref);

      const queryRes2 = await firestore()
        .collectionGroup(context.params.type)
        .where("ID", "==", change.before.data()!.ID)
        .orderBy("Time", "desc")
        .limit(1)
        .get();
      const data: Record<string, any> = {
        LastEdit: queryRes.docs[1].data().By,
      };
      if (queryRes2.empty) {
        data["Last" + context.params.type] = null;
      } else {
        data["Last" + context.params.type] = queryRes2.docs[0].data().Time;
      }
      batch.update(
        firestore().collection("Persons").doc(change.before.data()!.ID),
        data
      );
      return await batch.commit();
    }
  });

export const onServantsHistoryRecordWrite = functions.firestore
  .document("ServantsHistory/{day}/{type}/{doc}")
  .onWrite(async (change, context) => {
    const currentUser = await auth().getUser(
      change.after?.id ?? change.before.id
    );
    if (getChangeType(change) !== "delete") {
      if (
        getChangeType(change) === "update" &&
        change.after.data()?.ClassId !== change.before.data()?.ClassId
      )
        return (
          "Skipped: ClassId changed from " +
          (change.before.data()!.ClassId as DocumentReference).path +
          " to " +
          (change.after.data()!.ClassId as DocumentReference).path
        );
      const data: Record<string, any> = {
        LastEdit: change.after.data()!.RecordedBy,
      };
      data["Last" + context.params.type] = change.after.data()!.Time;
      return await firestore()
        .collection("UsersData")
        .doc(currentUser.customClaims!.personId)
        .update(data);
    } else {
      const batch = firestore().batch();
      const queryRes = await firestore()
        .collection("UsersData")
        .doc(currentUser.customClaims!.personId)
        .collection("EditHistory")
        .orderBy("Time", "desc")
        .limit(2)
        .get();
      batch.delete(queryRes.docs[0].ref);

      const queryRes2 = await firestore()
        .collectionGroup(context.params.type)
        .where("ID", "==", currentUser.customClaims!.personId)
        .orderBy("Time", "desc")
        .limit(1)
        .get();
      const data: Record<string, any> = {
        LastEdit: queryRes.docs[1].data().By,
      };
      if (queryRes2.empty) {
        data["Last" + context.params.type] = null;
      } else {
        data["Last" + context.params.type] = queryRes2.docs[0].data().Time;
      }
      batch.update(
        firestore()
          .collection("UsersData")
          .doc(currentUser.customClaims!.personId),
        data
      );
      return await batch.commit();
    }
  });
export const onInvitationCreated = functions.firestore
  .document("Invitations/{invitation}")
  .onCreate(async (change) => {
    await change.ref.update({
      Link: (
        await new FirebaseDynamicLinks(
          process.env.FirebaseDynamicLinksKey!
        ).createLink({
          dynamicLinkInfo: {
            domainUriPrefix: "https://meetinghelper.page.link",
            link:
              "https://meetinghelper.com/register?InvitationId=" + change.id,
            androidInfo: {
              androidPackageName: "com.AndroidQuartz.meetinghelper",
              androidFallbackLink:
                "https://github.com/Andrew-Bekhiet/MeetingHelper/releases/",
              androidMinPackageVersionCode: "3",
            },
          },
          suffix: { option: "UNGUESSABLE" },
        })
      ).shortLink,
    });
  });
