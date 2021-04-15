import * as functions from "firebase-functions";

import { firestore, database, storage, messaging, auth } from "firebase-admin";
import { FieldValue } from "@google-cloud/firestore";
import * as download from "download";

export const onUserSignUp = functions.auth.user().onCreate(async (user) => {
  const doc = firestore().collection("UsersData").doc();
  const customClaims = {
    password: null, //Empty password
    manageUsers: false, //Can manage Users' names, reset passwords and permissions
    manageAllowedUsers: false, //Can manage specific Users' names, reset passwords and permissions
    manageDeleted: false, //Can read deleted items and restore them
    superAccess: false, //Can read everything
    write: true, //Can write avalibale data
    secretary: false, //Can write servants history
    exportClasses: true, //Can Export individual Classes to Excel sheet
    birthdayNotify: true, //Can receive Birthday notifications
    confessionsNotify: true,
    tanawolNotify: true,
    kodasNotify: true,
    meetingNotify: true,
    approveLocations: false,
    approved: false, //A User with 'Manage Users' permission must approve new users
    lastConfession: null, //Last Confession in millis for the user
    lastTanawol: null, //Last Tanawol in millis for the user
    servingStudyYear: null,
    servingStudyGender: null,
    personId: doc.id,
  };
  await messaging().sendToTopic(
    "ManagingUsers",
    {
      notification: {
        title: "قام " + user.displayName + " بتسجيل حساب بالبرنامج",
        body:
          "ان كنت تعرف " +
          user.displayName +
          "فقم بتنشيط حسابه ليتمكن من الدخول للبرنامج",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "ManagingUsers",
        title: "قام " + user.displayName + " بتسجيل حساب بالبرنامج",
        content: "",
        attachement: "https://meetinghelper.page.link/viewUser?UID=" + user.uid,
        time: String(Date.now()),
      },
    },
    {
      priority: "high",
      timeToLive: 24 * 60 * 60,
      restrictedPackageName: "com.AndroidQuartz.meetinghelper",
    }
  );
  await doc.set({
    UID: user.uid,
    Name: user.displayName ?? null,
    Email: user.email ?? null,
    ClassId: null,
    AllowedUsers: [],
    LastTanawol: null,
    LastConfession: null,
    Permissions: {
      ManageUsers: false,
      ManageAllowedUsers: false,
      ManageDeleted: false,
      SuperAccess: false,
      Write: true,
      Secretary: false,
      ExportClasses: true,
      BirthdayNotify: true,
      ConfessionsNotify: true,
      TanawolNotify: true,
      KodasNotify: true,
      MeetingNotify: true,
      ApproveLocations: false,
      Approved: false,
    },
  });
  await auth().setCustomUserClaims(user.uid, customClaims);
  await database()
    .ref()
    .child("Users/" + user.uid + "/forceRefresh")
    .set(true);
  await download(user.photoURL, "/tmp/", { filename: user.uid + ".jpg" });
  await storage()
    .bucket()
    .upload("/tmp/" + user.uid + ".jpg", {
      contentType: "image/jpeg",
      destination: "UsersPhotos/" + user.uid,
      gzip: true,
    });
  return "OK";
});

export const onUserDeleted = functions.auth.user().onDelete(async (user) => {
  await database()
    .ref()
    .child("Users/" + user.uid)
    .set(null);
  await storage()
    .bucket()
    .file("UsersPhotos/" + user.uid)
    .delete();
  await firestore().collection("Users").doc(user.uid).delete();
  if (
    user.customClaims.personId !== null &&
    user.customClaims.personId !== undefined
  )
    await firestore()
      .collection("UsersData")
      .doc(user.customClaims.personId)
      .delete();
  let batch = firestore().batch();
  for (const doc of (
    await firestore()
      .collection("Classes")
      .where("Allowed", "array-contains", user.uid)
      .get()
  ).docs) {
    batch.update(doc.ref, { Allowed: FieldValue.arrayRemove(user.uid) });
  }
  await batch.commit();
  batch = firestore().batch();
  for (const doc of (
    await firestore()
      .collection("Invitations")
      .where("GeneratedBy", "==", user.uid)
      .get()
  ).docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  batch = firestore().batch();
  for (const doc of (
    await firestore()
      .collection("Invitations")
      .where("UsedBy", "==", user.uid)
      .get()
  ).docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
});
