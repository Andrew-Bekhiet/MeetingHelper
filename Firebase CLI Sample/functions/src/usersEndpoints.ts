import { https } from "firebase-functions";

import { auth, firestore, database, storage, messaging } from "firebase-admin";
import {
  Timestamp,
  FieldValue,
  DocumentReference,
} from "@google-cloud/firestore";
import { HttpsError } from "firebase-functions/lib/providers/https";
import * as download from "download";

import { assertNotEmpty, getFCMTokensForUser } from "./common";
import { adminPassword } from "./adminPassword";

export const registerWithLink = https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new https.HttpsError("unauthenticated", "");
  }
  const currentUser = await auth().getUser(context.auth.uid);
  if (currentUser.customClaims.approved) {
    throw new https.HttpsError("aborted", "User already approved");
  }
  assertNotEmpty("link", data.link, typeof "");
  if ((data.link as string).startsWith("https://meetinghelper.page.link")) {
    const deeplink = (
      await require("node-fetch")(data.link, { redirect: "manual" })
    ).headers.get("location");
    const id = deeplink.replace(
      "https://meetinghelper.com/register?InvitationId=",
      ""
    );
    const doc = await firestore().collection("Invitations").doc(id).get();
    if (!doc.exists) throw new HttpsError("not-found", "Invitation not found");
    if (
      (doc.data().ExpiryDate as Timestamp).toMillis() -
        new Date().getMilliseconds() <=
      0
    )
      throw new HttpsError("failed-precondition", "Invitation expired");
    if (doc.data().Link !== data.link)
      throw new HttpsError("failed-precondition", "");
    if (doc.data().UsedBy) throw new HttpsError("failed-precondition", "");
    const batch = firestore().batch();
    batch.update(doc.ref, { UsedBy: context.auth.uid });

    const newPermissions = doc.data().Permissions;
    if (
      (await auth().getUser(doc.data().GeneratedBy)).customClaims[
        "manageAllowedUsers"
      ] === true
    ) {
      delete newPermissions.manageUsers;
      batch.update(firestore().collection("Users").doc(currentUser.uid), {
        allowedUsers: FieldValue.arrayUnion(doc.data().GeneratedBy),
      });
    }

    delete newPermissions.password;
    delete newPermissions.lastTanawol;
    delete newPermissions.lastConfession;
    newPermissions.approved = true;
    await auth().setCustomUserClaims(
      currentUser.uid,
      Object.assign(currentUser.customClaims, newPermissions)
    );
    await database()
      .ref()
      .child("Users/" + currentUser.uid + "/forceRefresh")
      .set(true);
    batch.set(firestore().doc("Users/" + currentUser.uid), {
      Name: currentUser.displayName,
    });
    await batch.commit();
    return "OK";
  }

  throw new https.HttpsError("invalid-argument", "Invalid registeration link");
});

export const registerAccount = https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new https.HttpsError("unauthenticated", "");
  } else if (!(await auth().getUser(context.auth.uid)).customClaims.approved) {
    throw new https.HttpsError("unauthenticated", "Must be approved user");
  }
  assertNotEmpty("name", data.name, typeof "");
  assertNotEmpty("password", data.password, typeof "");
  assertNotEmpty("lastConfession", data.lastConfession, typeof 0);
  assertNotEmpty("lastTanawol", data.lastTanawol, typeof 0);
  assertNotEmpty("fcmToken", data.fcmToken, typeof "");

  const currentUser = await auth().getUser(context.auth.uid);
  const newCustomClaims = currentUser.customClaims;

  newCustomClaims["password"] = data.password;
  newCustomClaims["lastConfession"] = data.lastConfession;
  newCustomClaims["lastTanawol"] = data.lastTanawol;
  try {
    if (
      currentUser.customClaims.approved &&
      (currentUser.customClaims.manageUsers ||
        currentUser.customClaims.manageAllowedUsers)
    ) {
      await messaging().subscribeToTopic(data.fcmToken, "ManagingUsers");
    }
    if (
      currentUser.customClaims.approved &&
      currentUser.customClaims.approveLocations
    ) {
      await messaging().subscribeToTopic(data.fcmToken, "ApproveLocations");
    }
  } catch (e) {
    throw new https.HttpsError("not-found", "FCM Token not found");
  }

  await auth().updateUser(currentUser.uid, { displayName: data.name });
  await firestore()
    .doc("Users/" + currentUser.uid)
    .update({ Name: data.name });
  await database()
    .ref("Users/" + currentUser.uid + "/FCM_Tokens/" + data.fcmtoken)
    .set("token");
  await auth().setCustomUserClaims(currentUser.uid, newCustomClaims);
  await database()
    .ref()
    .child("Users/" + currentUser.uid + "/forceRefresh")
    .set(true);
  return "OK";
});

export const registerFCMToken = https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new https.HttpsError("unauthenticated", "");
  }
  assertNotEmpty("token", data.token, typeof "");
  await database()
    .ref("Users/" + context.auth.uid + "/FCM_Tokens/" + data.token)
    .set("token");
  const currentUserClaims = (await auth().getUser(context.auth.uid))
    .customClaims;
  if (
    currentUserClaims.approved &&
    (currentUserClaims.manageUsers || currentUserClaims.manageAllowedUsers) &&
    (await getFCMTokensForUser(context.auth.uid))
  ) {
    await messaging().subscribeToTopic(
      await getFCMTokensForUser(context.auth.uid),
      "ManagingUsers"
    );
  }
  if (
    currentUserClaims.approved &&
    currentUserClaims.approveLocations &&
    (await getFCMTokensForUser(context.auth.uid))
  ) {
    await messaging().subscribeToTopic(
      await getFCMTokensForUser(context.auth.uid),
      "ApproveLocations"
    );
  }
  return "OK";
});

export const updateUserSpiritData = https.onCall(async (data, context) => {
  if (context.auth || data.adminPassword === adminPassword) {
    assertNotEmpty("lastTanawol", data.lastTanawol, typeof 0);
    assertNotEmpty("lastConfession", data.lastConfession, typeof 0);
    await auth().setCustomUserClaims(
      context.auth.uid,
      Object.assign((await auth().getUser(context.auth.uid)).customClaims, {
        lastConfession: data.lastConfession,
        lastTanawol: data.lastTanawol,
      })
    );
    await database()
      .ref()
      .child("Users/" + context.auth.uid + "/forceRefresh")
      .set(true);
    return "OK";
  }
  throw new https.HttpsError("unauthenticated", "");
});

export const sendMessageToUsers = https.onCall(async (data, context) => {
  let from: string;
  if (context.auth === undefined) {
    if (data.adminPassword === adminPassword) {
      from = "";
    } else {
      throw new https.HttpsError("unauthenticated", "");
    }
  } else if ((await auth().getUser(context.auth.uid)).customClaims.approved) {
    from = context.auth.uid;
  } else {
    throw new https.HttpsError("unauthenticated", "");
  }
  assertNotEmpty("users", data.users, typeof []);
  assertNotEmpty("title", data.title, typeof "");
  assertNotEmpty("content", data.content, typeof "");
  assertNotEmpty("attachement", data.attachement, typeof "");
  let usersToSend: string[] = await Promise.all(
    data.users.map(
      async (user: any, i: any, ary: any) => await getFCMTokensForUser(user)
    )
  );
  usersToSend = usersToSend
    .reduce((accumulator, value) => accumulator.concat(value), [])
    .filter((v) => v !== null && v !== undefined);
  console.log("usersToSend[0]:" + usersToSend[0]);
  console.log("usersToSend" + usersToSend);
  await messaging().sendToDevice(
    usersToSend,
    {
      notification: {
        title: data.title,
        body: data.body,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: data.title,
        content: data.content,
        attachement: data.attachement,
        time: String(Date.now()),
        sentFrom: from,
      },
    },
    {
      priority: "high",
      timeToLive: 7 * 24 * 60 * 60,
      restrictedPackageName: "com.AndroidQuartz.meetinghelper",
    }
  );
  return "OK";
});

export const changeUserName = https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    (currentUser.customClaims.manageUsers ||
      (currentUser.customClaims.manageAllowedUsers &&
        ((
          await firestore().collection("Users").doc(data.affectedUser).get()
        ).data().allowedUsers as Array<string>).includes(currentUser.uid)))
  ) {
    assertNotEmpty("newName", data.newName, typeof "");
    if (data.affectedUser && typeof data.affectedUser === typeof "") {
      await auth().updateUser(data.affectedUser, { displayName: data.newName });
      await firestore()
        .doc("Users/" + data.affectedUser)
        .update({ Name: data.newName });
      await firestore()
        .doc(
          "UsersData/" +
            (await auth().getUser(data.affectedUser)).customClaims.personId
        )
        .update({ Name: data.newName });
      return "OK";
    } else {
      await auth().updateUser(context.auth.uid, { displayName: data.newName });
      await firestore()
        .doc("Users/" + context.auth.uid)
        .update({ Name: data.newName });
      await firestore()
        .doc("UsersData/" + currentUser.customClaims.personId)
        .update({ Name: data.newName });
      return "OK";
    }
  } else if (currentUser.customClaims.approved) {
    assertNotEmpty("newName", data.newName, typeof "");
    await auth().updateUser(context.auth.uid, { displayName: data.newName });
    await firestore()
      .doc("Users/" + context.auth.uid)
      .update({ Name: data.newName });
    await firestore()
      .doc("UsersData/" + currentUser.customClaims.personId)
      .update({ Name: data.newName });
    return "OK";
  }
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const changePassword = https.onCall(async (data, context) => {
  //ChangePassword
  try {
    if (context.auth === undefined) {
      if (data.adminPassword !== adminPassword) {
        throw new https.HttpsError("unauthenticated", "unauthenticated");
      }
    } else if (
      !(await auth().getUser(context.auth.uid)).customClaims.approved
    ) {
      throw new https.HttpsError("unauthenticated", "Must be approved user");
    }
    const currentUser = await auth().getUser(context.auth.uid);
    const newCustomClaims = currentUser.customClaims;

    assertNotEmpty("newPassword", data.newPassword, typeof "");

    if (
      data.oldPassword ||
      (currentUser.customClaims.password === null && data.oldPassword === null)
    ) {
      const crypto = require("sha3");
      const s265 = new crypto.SHA3(256);
      const s512 = new crypto.SHA3(512);
      s512.update(data.oldPassword + "o$!hP64J^7c");
      s265.update(
        s512.digest("base64") + "fKLpdlk1px5ZwvF^YuIb9252C08@aQ4qDRZz5h2"
      );
      const digest = s265.digest("base64");
      if (
        currentUser.customClaims.password &&
        digest !== currentUser.customClaims.password
      ) {
        throw new https.HttpsError(
          "permission-denied",
          "Old Password is incorrect"
        );
      }
    } else {
      throw new https.HttpsError("permission-denied", "Old Password is empty");
    }
    newCustomClaims["password"] = data.newPassword;
    await auth().setCustomUserClaims(context.auth.uid, newCustomClaims);
    await database()
      .ref()
      .child("Users/" + context.auth.uid + "/forceRefresh")
      .set(true);
    return "OK";
  } catch (err) {
    console.log(err);
    throw new https.HttpsError("internal", "");
  }
});

export const deleteImage = https.onCall(async (context) => {
  await download((await auth().getUser(context.auth.uid)).photoURL, "/tmp/", {
    filename: "user.jpg",
  });
  return storage()
    .bucket()
    .upload("/tmp/user.jpg", {
      contentType: "image/jpeg",
      destination: "UsersPhotos/" + context.auth.uid,
      gzip: true,
    });
});

export const recoverDoc = https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.manageDeleted ||
    (context.auth === undefined && data.adminPassword === adminPassword)
  ) {
    console.log(data);
    if (
      !data.deletedPath ||
      !(data.deletedPath as string).startsWith("Deleted") ||
      !(data.deletedPath as string).match(
        RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/((Classes)|(Persons)).+")
      )
    )
      throw new https.HttpsError("invalid-argument", "Invalid 'deletedPath'");

    console.log("1");

    const documentToRecover = await firestore().doc(data.deletedPath).get();

    if (!documentToRecover.exists)
      throw new https.HttpsError("invalid-argument", "Invalid 'deletedPath'");

    console.log("2");
    if (!currentUser.customClaims.superAccess) {
      if (
        documentToRecover.ref.path.startsWith("Deleted/Classes") &&
        !(documentToRecover.data().Allowed as Array<string>).includes(
          currentUser.uid
        )
      )
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to restore the specified document"
        );
      else if (
        !((
          await (documentToRecover.data().ClassId as DocumentReference).get()
        ).data().Allowed as Array<string>).includes(currentUser.uid)
      ) {
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to restore the specified document"
        );
      }
    }
    console.log("3");

    const documentToWrite = firestore().doc(
      (data.deletedPath as string).replace(
        RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"),
        ""
      )
    );
    console.log("4");

    if (!data.nested) {
      console.log("5");
      await documentToWrite.set(documentToRecover.data(), { merge: true });
      if (!data.keepBackup) await firestore().doc(data.deletedPath).delete();
    } else {
      console.log("6");
      const doc = (data.deletedPath as string).replace(
        RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"),
        ""
      );
      let batch = firestore().batch();
      let count = 1;
      batch.set(documentToWrite, documentToRecover.data(), { merge: true });
      if (!data.keepBackup) {
        batch.delete(firestore().doc(data.deletedPath));
        count++;
      }
      console.log("7");

      if (doc.startsWith("Classes")) {
        for (const item of (
          await firestore()
            .collectionGroup("Persons")
            .where("ClassId", "==", firestore().doc(doc))
            .get()
        ).docs.filter((d) => d.ref.path.startsWith("Deleted"))) {
          if (count % 500 === 0) {
            await batch.commit();
            batch = firestore().batch();
          }
          batch.set(
            firestore().doc(
              item.ref.path.replace(RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"), "")
            ),
            item.data(),
            { merge: true }
          );
          count++;
          if (!data.keepBackup) {
            batch.delete(item.ref);
            count++;
          }
        }
      }
      await batch.commit();
    }
    console.log("8");
    return "OK";
  }
  if (context.auth)
    throw new https.HttpsError(
      "permission-denied",
      "Must be approved user with 'manageDeleted' permission"
    );
  else throw new https.HttpsError("unauthenticated", "unauthenticated");
});
