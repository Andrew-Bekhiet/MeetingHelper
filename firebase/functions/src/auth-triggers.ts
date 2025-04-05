import { FieldValue } from "@google-cloud/firestore";
import download from "download";
import { auth, database, firestore, messaging, storage } from "firebase-admin";
import { auth as auth_1 } from "firebase-functions/v1";
import { HttpsError } from "firebase-functions/v1/auth";
import { getFCMTokensForUser } from "./common";
import {
  firebaseDynamicLinksPrefix,
  packageName,
  projectId,
} from "./environment";

export const beforeUserSignUp = auth_1.user().beforeCreate(async (user) => {
  if (
    user.providerData.length === 0 ||
    user.providerData.find((p) => p.providerId === "password")
  ) {
    throw new HttpsError(
      "permission-denied",
      "Sign up failed. Please try again later."
    );
  }
});

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
      recordHistory: true, //Can record persons history
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
      recordHistory: false,
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

  const admins: string[] = await getManageUsersAdmins();
  const fcmTokens = (await Promise.allSettled(admins.map(getFCMTokensForUser)))
    .filter((a) => a.status === "fulfilled")
    .flatMap((a) => a.value);

  const username = user.displayName ?? user.email;

  await messaging().sendEachForMulticast({
    tokens: fcmTokens,
    notification: {
      title: "قام " + username + " بتسجيل حساب بالبرنامج",
      body:
        "ان كنت تعرف " +
        username +
        "فقم بتنشيط حسابه ليتمكن من الدخول للبرنامج",
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      type: "ManagingUsers",
      title: "قام " + username + " بتسجيل حساب بالبرنامج",
      content: "",
      attachement: firebaseDynamicLinksPrefix + "/viewUser?UID=" + user.uid,
      time: String(Date.now()),
    },

    android: {
      priority: "high",
      ttl: 24 * 60 * 60,
      restrictedPackageName: packageName,
    },
  });

  await doc.set({
    UID: user.uid,
    Name: username ?? null,
    Email: user.email ?? null,
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
      RecordHistory: customClaims.recordHistory,
      Secretary: customClaims.secretary,
      ChangeHistory: customClaims.changeHistory,
      Export: customClaims.export,
      BirthdayNotify: customClaims.birthdayNotify,
      ConfessionsNotify: customClaims.confessionsNotify,
      TanawolNotify: customClaims.tanawolNotify,
      KodasNotify: customClaims.kodasNotify,
      MeetingNotify: customClaims.meetingNotify,
      VisitNotify: customClaims.visitNotify,
      Approved: customClaims.approved,
    },
  });
  await auth().setCustomUserClaims(user.uid, customClaims);
  await database()
    .ref()
    .child("Users/" + user.uid + "/forceRefresh")
    .set(true);

  await download(user.photoURL!, "/tmp/", {
    filename: user.uid + ".jpg",
  });
  await storage()
    .bucket("gs://" + projectId + ".appspot.com")
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

  const userPhoto = storage()
    .bucket("gs://" + projectId + ".appspot.com")
    .file("UsersPhotos/" + user.uid);

  if (await userPhoto.exists()) {
    await userPhoto.delete();
  }

  const userDoc = firestore().collection("Users").doc(user.uid);
  if ((await userDoc.get()).exists) {
    await userDoc.delete();
  }

  if (
    user.customClaims?.personId !== null &&
    user.customClaims?.personId !== undefined
  ) {
    const userDataDoc = firestore()
      .collection("UsersData")
      .doc(user.customClaims.personId);

    if ((await userDataDoc.get()).exists) {
      await userDataDoc.delete();
    }
  }

  const batch = firestore().batch();
  for (const doc of (
    await firestore()
      .collection("Classes")
      .where("Allowed", "array-contains", user.uid)
      .get()
  ).docs) {
    batch.update(doc.ref, { Allowed: FieldValue.arrayRemove(user.uid) });
  }

  for (const doc of (
    await firestore()
      .collection("Invitations")
      .where("GeneratedBy", "==", user.uid)
      .get()
  ).docs) {
    batch.delete(doc.ref);
  }

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

async function getManageUsersAdmins(): Promise<string[]> {
  const users = (await auth().listUsers()).users;

  return users
    .filter((user) => {
      return (
        user.customClaims?.manageUsers || user.customClaims?.manageAllowedUsers
      );
    })
    .map((user) => user.uid);
}
