import { https } from "firebase-functions";
import { SHA3 } from "sha3";
import * as nf from "node-fetch";
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
  if (currentUser.customClaims?.approved) {
    throw new https.HttpsError("aborted", "User already approved");
  }
  assertNotEmpty("link", data.link, typeof "");
  if ((data.link as string).startsWith("https://meetinghelper.page.link")) {
    const deeplink = (
      await nf.default(data.link, { redirect: "manual" })
    ).headers.get("location")!;
    const id = deeplink.replace(
      "https://meetinghelper.com/register?InvitationId=",
      ""
    );
    const doc = await firestore().collection("Invitations").doc(id).get();
    if (!doc.exists) throw new HttpsError("not-found", "Invitation not found");
    if (
      (doc.data()!.ExpiryDate as Timestamp).toMillis() -
        new Date().getMilliseconds() <=
      0
    )
      throw new HttpsError("failed-precondition", "Invitation expired");
    if (doc.data()!.Link !== data.link)
      throw new HttpsError("failed-precondition", "");
    if (doc.data()!.UsedBy) throw new HttpsError("failed-precondition", "");
    const batch = firestore().batch();
    batch.update(doc.ref, { UsedBy: context.auth.uid });

    const newPermissions: Record<string, any> = doc.data()?.Permissions
      ? doc.data()?.Permissions
      : {};

    if (
      newPermissions.personId &&
      (
        await firestore()
          .collection("UsersData")
          .doc(newPermissions.personId)
          .get()
      ).data()?.UID
    )
      throw new HttpsError("failed-precondition", "personId");

    if (
      (await auth().getUser(doc.data()!.GeneratedBy)).customClaims
        ?.manageAllowedUsers === true
    ) {
      delete newPermissions.manageUsers;
      batch.update(
        firestore()
          .collection("UsersData")
          .doc(currentUser.customClaims!.personId),
        {
          AllowedUsers: FieldValue.arrayUnion(doc.data()!.GeneratedBy),
        }
      );
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
    batch.set(
      firestore().doc("Users/" + currentUser.uid),
      {
        Name: currentUser.displayName,
      },
      { merge: true }
    );
    await firestore()
      .doc("UsersData/" + currentUser.customClaims!.personId)
      .update({
        Name: currentUser.displayName,
        Permissions: {
          ManageUsers: newPermissions.manageUsers,
          ManageAllowedUsers: newPermissions.manageAllowedUsers,
          ManageDeleted: newPermissions.manageDeleted,
          SuperAccess: newPermissions.superAccess,
          Write: newPermissions.write,
          Secretary: newPermissions.secretary,
          ChangeHistory: newPermissions.changeHistory,
          Export: newPermissions.export,
          BirthdayNotify: newPermissions.birthdayNotify,
          ConfessionsNotify: newPermissions.confessionsNotify,
          TanawolNotify: newPermissions.tanawolNotify,
          KodasNotify: newPermissions.kodasNotify,
          MeetingNotify: newPermissions.meetingNotify,
          VisitNotify: newPermissions.visitNotify,
          Approved: newPermissions.approved,
        },
      });
    await batch.commit();
    return "OK";
  }

  throw new https.HttpsError("invalid-argument", "Invalid registeration link");
});

export const registerAccount = https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new https.HttpsError("unauthenticated", "");
  } else if (!(await auth().getUser(context.auth.uid)).customClaims!.approved) {
    throw new https.HttpsError("unauthenticated", "Must be approved user");
  }
  assertNotEmpty("name", data.name, typeof "");
  assertNotEmpty("password", data.password, typeof "");
  assertNotEmpty("lastConfession", data.lastConfession, typeof 0);
  assertNotEmpty("lastTanawol", data.lastTanawol, typeof 0);
  assertNotEmpty("fcmToken", data.fcmToken, typeof "");

  const currentUser = await auth().getUser(context.auth.uid);
  const newCustomClaims: Record<string, any> = currentUser.customClaims
    ? currentUser.customClaims
    : {};

  newCustomClaims["password"] = data.password;
  newCustomClaims["lastConfession"] = data.lastConfession;
  newCustomClaims["lastTanawol"] = data.lastTanawol;
  try {
    if (
      currentUser.customClaims?.approved &&
      (currentUser.customClaims?.manageUsers ||
        currentUser.customClaims?.manageAllowedUsers)
    ) {
      await messaging().subscribeToTopic(data.fcmToken, "ManagingUsers");
    }
  } catch (e) {
    throw new https.HttpsError("not-found", "FCM Token not found");
  }

  await auth().updateUser(currentUser.uid, { displayName: data.name });
  await firestore()
    .doc("Users/" + currentUser.uid)
    .set({ Name: data.name }, { merge: true });
  await firestore()
    .doc("UsersData/" + currentUser.customClaims!.personId)
    .update({
      Name: data.name,
      LastTanawol: Timestamp.fromMillis(data.lastTanawol),
      LastConfession: Timestamp.fromMillis(data.lastConfession),
    });
  await database()
    .ref("Users/" + currentUser.uid + "/FCM_Tokens/" + data.fcmToken)
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
    currentUserClaims?.approved &&
    (currentUserClaims?.manageUsers || currentUserClaims?.manageAllowedUsers) &&
    (await getFCMTokensForUser(context.auth.uid))
  ) {
    await messaging().subscribeToTopic(
      await getFCMTokensForUser(context.auth.uid),
      "ManagingUsers"
    );
  }
  return "OK";
});

export const updateUserSpiritData = https.onCall(async (data, context) => {
  if (!context.auth) throw new https.HttpsError("unauthenticated", "");
  assertNotEmpty("lastTanawol", data.lastTanawol, typeof 0);
  assertNotEmpty("lastConfession", data.lastConfession, typeof 0);
  const user = await auth().getUser(context.auth.uid);
  await auth().setCustomUserClaims(
    context.auth.uid,
    Object.assign(user.customClaims, {
      lastConfession: data.lastConfession,
      lastTanawol: data.lastTanawol,
    })
  );
  await firestore()
    .doc("UsersData/" + user.customClaims!.personId)
    .update({
      LastTanawol: Timestamp.fromMillis(data.lastTanawol),
      LastConfession: Timestamp.fromMillis(data.lastConfession),
    });
  await database()
    .ref()
    .child("Users/" + context.auth.uid + "/forceRefresh")
    .set(true);
  return "OK";
});

export const sendMessageToUsers = https.onCall(async (data, context) => {
  let from: string;
  if (context.auth === undefined) {
    if (data.AdminPassword === adminPassword) {
      from = "";
    } else {
      throw new https.HttpsError("unauthenticated", "");
    }
  } else if ((await auth().getUser(context.auth.uid)).customClaims!.approved) {
    from = context.auth.uid;
  } else {
    throw new https.HttpsError("unauthenticated", "");
  }
  if (
    data.users === null ||
    data.users === undefined ||
    (typeof data.users !== typeof [] && data.users !== "all")
  ) {
    throw new https.HttpsError(
      "invalid-argument",
      "users cannot be null or undefined and must be " + typeof []
    );
  }
  assertNotEmpty("title", data.title, typeof "");
  assertNotEmpty("content", data.content, typeof "");
  assertNotEmpty("attachement", data.attachement, typeof "");

  let usersToSend: string[] = [];
  if (typeof data.users === typeof []) {
    usersToSend = await Promise.all(
      data.users.map(async (user: any) => await getFCMTokensForUser(user))
    );
    usersToSend = usersToSend
      .reduce<string[]>((accumulator, value) => accumulator.concat(value), [])
      .filter((v) => v !== null && v !== undefined);
  } else if (data.users === "all") {
    usersToSend = await Promise.all(
      ((await auth().listUsers()).users as any).map(
        async (user: any) => await getFCMTokensForUser(user.uid)
      )
    );
    usersToSend = usersToSend
      .reduce<string[]>((accumulator, value) => accumulator.concat(value), [])
      .filter((v) => v !== null && v !== undefined);
  } else {
    throw new https.HttpsError("invalid-argument", "users");
  }
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
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");

  const currentUser = await auth().getUser(context.auth.uid);
  const personId = (await auth().getUser(data.affectedUser)).customClaims!
    .personId;
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (await firestore().collection("UsersData").doc(personId).get()).data()
            ?.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
  ) {
    assertNotEmpty("newName", data.newName, typeof "");
    if (data.affectedUser && typeof data.affectedUser === typeof "") {
      await auth().updateUser(data.affectedUser, { displayName: data.newName });
      await firestore()
        .doc("Users/" + data.affectedUser)
        .update({ Name: data.newName });
      await firestore()
        .doc("UsersData/" + personId)
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
  } else if (currentUser.customClaims?.approved) {
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
      if (data.AdminPassword !== adminPassword) {
        throw new https.HttpsError("unauthenticated", "unauthenticated");
      }
    } else if (
      !(await auth().getUser(context.auth.uid)).customClaims?.approved
    ) {
      throw new https.HttpsError("unauthenticated", "Must be approved user");
    }
    const currentUser = await auth().getUser(context.auth!.uid);
    const newCustomClaims: Record<string, any> = currentUser.customClaims
      ? currentUser.customClaims
      : {};

    assertNotEmpty("newPassword", data.newPassword, typeof "");

    if (
      data.oldPassword ||
      (currentUser.customClaims?.password === null && data.oldPassword === null)
    ) {
      const s265 = new SHA3(256);
      const s512 = new SHA3(512);
      s512.update(data.oldPassword + "o$!hP64J^7c");
      s265.update(
        s512.digest("base64") + "fKLpdlk1px5ZwvF^YuIb9252C08@aQ4qDRZz5h2"
      );
      const digest = s265.digest("base64");
      if (
        currentUser.customClaims?.password &&
        digest !== currentUser.customClaims?.password
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
    await auth().setCustomUserClaims(context.auth!.uid, newCustomClaims);
    await database()
      .ref()
      .child("Users/" + context.auth!.uid + "/forceRefresh")
      .set(true);
    return "OK";
  } catch (err) {
    console.log(err);
    throw new https.HttpsError("internal", "");
  }
});

export const deleteImage = https.onCall(async (context) => {
  await download((await auth().getUser(context.auth!.uid)).photoURL!, "/tmp/", {
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
  const currentUser = await auth().getUser(context.auth!.uid);
  if (
    currentUser.customClaims?.manageDeleted ||
    (context.auth === undefined && data.AdminPassword === adminPassword)
  ) {
    console.log(data);
    if (
      !data.deletedPath ||
      !(data.deletedPath as string).startsWith("Deleted") ||
      !(data.deletedPath as string).match(
        RegExp(
          "Deleted/\\d{4}-\\d{2}-\\d{2}/((Classes)|(Services)|(Persons)).+"
        )
      )
    )
      throw new https.HttpsError("invalid-argument", "Invalid 'deletedPath'");

    const documentToRecover = await firestore().doc(data.deletedPath).get();

    if (!documentToRecover.exists)
      throw new https.HttpsError("invalid-argument", "Invalid 'deletedPath'");

    if (!currentUser.customClaims?.superAccess) {
      if (
        documentToRecover.ref.path.startsWith("Deleted/Classes") &&
        !(documentToRecover.data()!.Allowed as Array<string>).includes(
          currentUser.uid
        )
      )
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to restore the specified document"
        );
      else if (
        !(
          (
            await (documentToRecover.data()!.ClassId as DocumentReference).get()
          ).data()!.Allowed as Array<string>
        ).includes(currentUser.uid)
      ) {
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to restore the specified document"
        );
      }
    }
    if (
      !currentUser.customClaims?.manageUsers &&
      !currentUser.customClaims?.manageAllowedUsers &&
      documentToRecover.ref.parent.id == "Services"
    ) {
      throw new HttpsError(
        "permission-denied",
        "To recover a service the calling user must have 'manageUsers' permission"
      );
    }

    const documentToWrite = firestore().doc(
      (data.deletedPath as string).replace(
        RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"),
        ""
      )
    );

    if (!data.nested) {
      await documentToWrite.set(documentToRecover.data()!, { merge: true });
      if (
        await storage()
          .bucket()
          .file(
            (data.deletedPath as string)
              .replace("/Classes/", "/ClassesPhotos/")
              .replace("/Persons/", "/PersonsPhotos/")
          )
          .exists()
      )
        await storage()
          .bucket()
          .file(
            (data.deletedPath as string)
              .replace("/Classes/", "/ClassesPhotos/")
              .replace("/Persons/", "/PersonsPhotos/")
          )
          .move(
            (data.deletedPath as string)
              .replace(RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"), "")
              .replace("/Classes/", "/ClassesPhotos/")
              .replace("/Persons/", "/PersonsPhotos/")
          );
      if (!data.keepBackup) await firestore().doc(data.deletedPath).delete();
    } else {
      const doc = (data.deletedPath as string).replace(
        RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"),
        ""
      );
      let batch = firestore().batch();
      let count = 1;
      batch.set(documentToWrite, documentToRecover.data()!, { merge: true });
      if (!data.keepBackup) {
        batch.delete(firestore().doc(data.deletedPath));
        count++;
      }

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
      if (await storage().bucket().file(data.deletedPath).exists())
        await storage()
          .bucket()
          .file(data.deletedPath)
          .move(
            (data.deletedPath as string).replace(
              RegExp("Deleted/\\d{4}-\\d{2}-\\d{2}/"),
              ""
            )
          );
    }
    return "OK";
  }
  if (context.auth)
    throw new https.HttpsError(
      "permission-denied",
      "Must be approved user with 'manageDeleted' permission"
    );
  else throw new https.HttpsError("unauthenticated", "unauthenticated");
});
