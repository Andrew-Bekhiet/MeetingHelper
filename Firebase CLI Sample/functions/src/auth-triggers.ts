import { auth as auth_1 } from "firebase-functions";

import { firestore, database, storage, messaging, auth } from "firebase-admin";
import { FieldValue } from "@google-cloud/firestore";
import * as download from "download";

export const onUserSignUp = auth_1.user().onCreate(async (user) => {
  let customClaims: Record<string, any>;

  const doc = firestore().collection("UsersData").doc();
  if ((await auth().listUsers(2)).users.length === 1) {
    customClaims = {
      password: null, //Empty password
      manageUsers: true, //Can manage Users' names, reset passwords and permissions
      manageAllowedUsers: true, //Can manage specific Users' names, reset passwords and permissions
      manageDeleted: true, //Can read deleted items and restore them
      superAccess: true, //Can read everything
      write: true, //Can write avalibale data
      secretary: true, //Can write servants history
      changeHistory: true, //Can edit old history
      export: true, //Can Export individual Classes to Excel sheet
      birthdayNotify: true, //Can receive Birthday notifications
      confessionsNotify: true,
      tanawolNotify: true,
      kodasNotify: true,
      meetingNotify: true,
      visitNotify: true,
      approved: true, //A User with 'Manage Users' permission must approve new users
      lastConfession: null, //Last Confession in millis for the user
      lastTanawol: null, //Last Tanawol in millis for the user
      servingStudyYear: null,
      servingStudyGender: null,
      personId: doc.id,
    };
  } else {
    customClaims = {
      password: null, //Empty password
      manageUsers: false, //Can manage Users' names, reset passwords and permissions
      manageAllowedUsers: false, //Can manage specific Users' names, reset passwords and permissions
      manageDeleted: false, //Can read deleted items and restore them
      superAccess: false, //Can read everything
      write: true, //Can write avalibale data
      secretary: false, //Can write servants history
      changeHistory: false,
      export: true, //Can Export individual Classes to Excel sheet
      birthdayNotify: true, //Can receive Birthday notifications
      confessionsNotify: true,
      tanawolNotify: true,
      kodasNotify: true,
      meetingNotify: true,
      visitNotify: true,
      approved: false, //A User with 'Manage Users' permission must approve new users
      lastConfession: null, //Last Confession in millis for the user
      lastTanawol: null, //Last Tanawol in millis for the user
      servingStudyYear: null,
      servingStudyGender: null,
      personId: doc.id,
    };
  }
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
    Name: user.displayName ? user.displayName : null,
    Email: user.email ? user.email : null,
    ClassId: null,
    AllowedUsers: [],
    LastTanawol: null,
    LastConfession: null,
    Permissions: {
      ManageUsers: customClaims.manageUsers,
      ManageAllowedUsers: customClaims.manageAllowedUsers,
      ManageDeleted: customClaims.manageDeleted,
      SuperAccess: customClaims.superAccess,
      Write: customClaims.write,
      Secretary: customClaims.secretary,
      ChangeHistory: customClaims.changeHistory,
      export: customClaims.export,
      BirthdayNotify: customClaims.birthdayNotify,
      ConfessionsNotify: customClaims.confessionsNotify,
      TanawolNotify: customClaims.tanawolNotify,
      KodasNotify: customClaims.kodasNotify,
      MeetingNotify: customClaims.meetingNotify,
      ApproveLocations: customClaims.approveLocations,
      Approved: customClaims.approved,
    },
  });
  await auth().setCustomUserClaims(user.uid, customClaims);
  await database()
    .ref()
    .child("Users/" + user.uid + "/forceRefresh")
    .set(true);
  await download(user.photoURL!, "/tmp/", { filename: user.uid + ".jpg" });
  await storage()
    .bucket()
    .upload("/tmp/" + user.uid + ".jpg", {
      contentType: "image/jpeg",
      destination: "UsersPhotos/" + user.uid,
      gzip: true,
    });
  return "OK";
});

export const onUserDeleted = auth_1.user().onDelete(async (user) => {
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
    user.customClaims?.personId !== null &&
    user.customClaims?.personId !== undefined
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
