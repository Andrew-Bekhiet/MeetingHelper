import * as functions from "firebase-functions";

import { auth, firestore, database, messaging } from "firebase-admin";

import { assertNotEmpty, getFCMTokensForUser } from "./common";
import { adminPassword } from "./adminPassword";
import { Timestamp } from "@google-cloud/firestore";

export const getUsers = functions.https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    if (data.adminPassword === adminPassword) {
      return (await auth().listUsers()).users.map((user, _i, _ary) => {
        const customClaims = user.customClaims;
        return Object.assign(customClaims, {
          uid: user.uid,
          name: user.displayName,
          email: user.email,
          phone: user.phoneNumber,
          photoUrl: user.photoURL,
        });
      });
    } else {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "unauthenticated"
      );
    }
  }
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    currentUser.customClaims.manageUsers
  ) {
    return (await auth().listUsers()).users
      .filter((user, _i, _arry) => {
        return !user.disabled;
      })
      .map((user, _i, _ary) => {
        const customClaims = user.customClaims;
        delete customClaims.password;
        return Object.assign(customClaims, {
          uid: user.uid,
          name: user.displayName,
          email: user.email,
          phone: user.phoneNumber,
          photoUrl: user.photoURL,
        });
      });
  } else if (
    currentUser.customClaims.approved &&
    currentUser.customClaims.manageAllowedUsers
  ) {
    const allowedUsers = (
      await firestore()
        .collection("Users")
        .where("allowedUsers", "array-contains", currentUser.uid)
        .get()
    ).docs.map((u) => u.id);
    return (await auth().listUsers()).users
      .filter((user) => !user.disabled && allowedUsers.includes(user.uid))
      .map((user, _i, _ary) => {
        const customClaims = user.customClaims;
        delete customClaims.password;
        return Object.assign(customClaims, {
          uid: user.uid,
          name: user.displayName,
          email: user.email,
          phone: user.phoneNumber,
          photoUrl: user.photoURL,
        });
      });
  }
  throw new functions.https.HttpsError(
    "unauthenticated",
    "Must be an approved user with 'manageUsers' or 'manageAllowedUsers' permissions"
  );
});

export const approveUser = functions.https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    currentUser.customClaims.manageUsers
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    const user = await auth().getUser(data.affectedUser);
    const newClaims = user.customClaims;
    newClaims.approved = true;
    await auth().setCustomUserClaims(user.uid, newClaims);
    await database()
      .ref()
      .child("Users/" + user.uid + "/forceRefresh")
      .set(true);
    if (user.displayName === null) {
      await firestore()
        .doc("Users/" + user.uid)
        .set({ Name: user.phoneNumber });
      return "OK";
    }
    await firestore()
      .doc("Users/" + user.uid)
      .set({ Name: user.displayName });
    await firestore()
      .doc("UsersData/" + user.customClaims.personId)
      .update({ "Permissions.Approved": true });
    return "OK";
  }
  throw new functions.https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const unApproveUser = functions.https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    (currentUser.customClaims.manageUsers ||
      (currentUser.customClaims.manageAllowedUsers &&
        ((
          await firestore().collection("Users").doc(data.affectedUser).get()
        ).data().allowedUsers as Array<string>).includes(currentUser.uid)))
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    const user = await auth().getUser(data.affectedUser);
    await auth().setCustomUserClaims(user.uid, {
      password: null, //Empty password
      manageUsers: false, //Can manage Users' names, reset passwords and permissions
      manageAllowedUsers: false, //Can manage specific Users' names, reset passwords and permissions
      manageDeleted: false,
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
    });
    await firestore()
      .doc("Users/" + data.affectedUser)
      .delete();
    await firestore()
      .doc("UsersData/" + user.customClaims.personId)
      .update({ "Permissions.Approved": false });
    return "OK";
  }
  throw new functions.https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const deleteUser = functions.https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    (currentUser.customClaims.manageUsers ||
      (currentUser.customClaims.manageAllowedUsers &&
        ((
          await firestore().collection("Users").doc(data.affectedUser).get()
        ).data().allowedUsers as Array<string>).includes(currentUser.uid)))
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    await auth().getUser(data.affectedUser);
    await auth().deleteUser(data.affectedUser);
    await firestore()
      .doc("Users/" + data.affectedUser)
      .delete();
    return "OK";
  }
  throw new functions.https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const resetPassword = functions.https.onCall(async (data, context) => {
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims.approved &&
    (currentUser.customClaims.manageUsers ||
      (currentUser.customClaims.manageAllowedUsers &&
        ((
          await firestore().collection("Users").doc(data.affectedUser).get()
        ).data().allowedUsers as Array<string>).includes(currentUser.uid)))
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    const user = await auth().getUser(data.affectedUser);
    const newClaims = user.customClaims;
    newClaims.password = null;
    await auth().setCustomUserClaims(user.uid, newClaims);
    await database()
      .ref()
      .child("Users/" + user.uid + "/forceRefresh")
      .set(true);
    return "OK";
  }
  throw new functions.https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const updatePermissions = functions.https.onCall(
  async (data, context) => {
    const currentUser = await auth().getUser(context.auth.uid);
    if (
      currentUser.customClaims.approved &&
      (currentUser.customClaims.manageUsers ||
        (currentUser.customClaims.manageAllowedUsers &&
          !data.permissions.manageUsers &&
          (
            await firestore()
              .collection("Users")
              .where("allowedUsers", "array-contains", currentUser.uid)
              .get()
          ).docs
            .map((u) => u.id)
            .includes(data.affectedUser)))
    ) {
      if (data.permissions.approved !== undefined)
        assertNotEmpty(
          "permissions.approved",
          data.permissions.approved,
          typeof true
        );
      if (data.permissions.manageUsers !== undefined)
        assertNotEmpty(
          "permissions.manageUsers",
          data.permissions.manageUsers,
          typeof true
        );
      if (data.permissions.manageDeleted !== undefined)
        assertNotEmpty(
          "permissions.manageDeleted",
          data.permissions.manageDeleted,
          typeof true
        );
      if (data.permissions.manageAllowedUsers !== undefined)
        assertNotEmpty(
          "permissions.manageAllowedUsers",
          data.permissions.manageAllowedUsers,
          typeof true
        );
      if (data.permissions.superAccess !== undefined)
        assertNotEmpty(
          "permissions.superAccess",
          data.permissions.superAccess,
          typeof true
        );
      if (data.permissions.write !== undefined)
        assertNotEmpty(
          "permissions.write",
          data.permissions.write,
          typeof true
        );
      if (data.permissions.secretary !== undefined)
        assertNotEmpty(
          "permissions.secretary",
          data.permissions.secretary,
          typeof true
        );
      if (data.permissions.approveLocations !== undefined)
        assertNotEmpty(
          "permissions.approveLocations",
          data.permissions.approveLocations,
          typeof true
        );
      if (data.permissions.birthdayNotify !== undefined)
        assertNotEmpty(
          "permissions.birthdayNotify",
          data.permissions.birthdayNotify,
          typeof true
        );
      if (data.permissions.confessionsNotify !== undefined)
        assertNotEmpty(
          "permissions.confessionsNotify",
          data.permissions.confessionsNotify,
          typeof true
        );
      if (data.permissions.tanawolNotify !== undefined)
        assertNotEmpty(
          "permissions.tanawolNotify",
          data.permissions.tanawolNotify,
          typeof true
        );
      const user = await auth().getUser(data.affectedUser);

      const newPermissions = {};
      const oldPermissions = user.customClaims;

      console.log(oldPermissions);
      console.log(newPermissions);

      newPermissions["approved"] = oldPermissions.approved;
      newPermissions["birthdayNotify"] =
        data.permissions.birthdayNotify ?? oldPermissions.birthdayNotify;
      newPermissions["confessionsNotify"] =
        data.permissions.confessionsNotify ?? oldPermissions.confessionsNotify;
      newPermissions["exportClasses"] =
        data.permissions.exportClasses ?? oldPermissions.exportClasses;
      newPermissions["kodasNotify"] =
        data.permissions.kodasNotify ?? oldPermissions.kodasNotify;
      newPermissions["manageAllowedUsers"] =
        data.permissions.manageAllowedUsers ??
        oldPermissions.manageAllowedUsers;
      newPermissions["manageDeleted"] =
        data.permissions.manageDeleted ?? oldPermissions.manageDeleted;
      newPermissions["manageUsers"] =
        data.permissions.manageUsers ?? oldPermissions.manageUsers;
      newPermissions["meetingNotify"] =
        data.permissions.meetingNotify ?? oldPermissions.meetingNotify;
      newPermissions["secretary"] =
        data.permissions.secretary ?? oldPermissions.secretary;
      newPermissions["superAccess"] =
        data.permissions.superAccess ?? oldPermissions.superAccess;
      newPermissions["tanawolNotify"] =
        data.permissions.tanawolNotify ?? oldPermissions.tanawolNotify;
      newPermissions["write"] = data.permissions.write ?? oldPermissions.write;

      try {
        const tokens = await getFCMTokensForUser(data.affectedUser);
        if (
          oldPermissions.manageUsers !== newPermissions["manageUsers"] &&
          tokens !== null &&
          tokens !== [] &&
          tokens !== undefined &&
          tokens !== ""
        ) {
          if (newPermissions["manageUsers"]) {
            await messaging().subscribeToTopic(tokens, "ManagingUsers");
          } else if (newPermissions["manageUsers"] === false) {
            await messaging().unsubscribeFromTopic(tokens, "ManagingUsers");
          } else if (
            oldPermissions.manageAllowedUsers !==
              newPermissions["manageAllowedUsers"] &&
            tokens !== null &&
            tokens !== [] &&
            tokens !== undefined &&
            tokens !== ""
          ) {
            if (newPermissions["manageAllowedUsers"]) {
              await messaging().subscribeToTopic(tokens, "ManagingUsers");
            } else if (newPermissions["manageAllowedUsers"] === false) {
              await messaging().unsubscribeFromTopic(tokens, "ManagingUsers");
            }
          }
        }
      } catch (e) {}
      console.log(
        Object.assign(
          {
            password: oldPermissions.password,
            personId: oldPermissions.personId,
            lastTanawol: oldPermissions.lastTanawol,
            lastConfession: oldPermissions.lastConfession,
          },
          newPermissions
        )
      );
      await auth().setCustomUserClaims(
        data.affectedUser,
        Object.assign(
          {
            password: oldPermissions.password,
            personId: oldPermissions.personId,
            lastTanawol: oldPermissions.lastTanawol,
            lastConfession: oldPermissions.lastConfession,
          },
          newPermissions
        )
      );

      console.log("ss");
      console.log(oldPermissions);
      console.log(newPermissions);

      await firestore()
        .doc("UsersData/" + user.customClaims.personId)
        .update({
          LastTanawol:
            Object.assign(oldPermissions, newPermissions).lastTanawol !==
              null &&
            Object.assign(oldPermissions, newPermissions).lastTanawol !==
              undefined
              ? Timestamp.fromMillis(
                  Object.assign(oldPermissions, newPermissions).lastTanawol
                )
              : null,
          LastConfession:
            Object.assign(oldPermissions, newPermissions).lastConfession !==
              null &&
            Object.assign(oldPermissions, newPermissions).lastConfession !==
              undefined
              ? Timestamp.fromMillis(
                  Object.assign(oldPermissions, newPermissions).lastConfession
                )
              : null,
          Permissions: toCamel(newPermissions),
        });
      await database()
        .ref()
        .child("Users/" + data.affectedUser + "/forceRefresh")
        .set(true);
      return "OK";
    }
    throw new functions.https.HttpsError(
      "permission-denied",
      "Must be an approved user with 'manageUsers' permission"
    );
  }
);

export const migrateHistory = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (data) => {
    if (data.adminPassword === adminPassword) {
      let pendingChanges = firestore().batch();

      let batchCount = 0;

      let snapshot = await firestore().collectionGroup("Meeting").get();
      for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
        if (batchCount % 500 === 0) {
          await pendingChanges.commit();
          pendingChanges = firestore().batch();
        }
        if (
          snapshot.docs[i].ref.parent.parent.parent.id === "ServantsHistory"
        ) {
          pendingChanges.update(snapshot.docs[i].ref, {
            ID: snapshot.docs[i].id,
          });
          console.log("done: " + snapshot.docs[i].id);
        }
      }

      snapshot = await firestore().collectionGroup("Kodas").get();
      for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
        if (batchCount % 500 === 0) {
          await pendingChanges.commit();
          pendingChanges = firestore().batch();
        }
        if (
          snapshot.docs[i].ref.parent.parent.parent.id === "ServantsHistory"
        ) {
          pendingChanges.update(snapshot.docs[i].ref, {
            ID: snapshot.docs[i].id,
          });
          console.log("done: " + snapshot.docs[i].id);
        }
      }

      snapshot = await firestore().collectionGroup("Tanawol").get();
      for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
        if (batchCount % 500 === 0) {
          await pendingChanges.commit();
          pendingChanges = firestore().batch();
        }
        if (
          snapshot.docs[i].ref.parent.parent.parent.id === "ServantsHistory"
        ) {
          pendingChanges.update(snapshot.docs[i].ref, {
            ID: snapshot.docs[i].id,
          });
          console.log("done: " + snapshot.docs[i].id);
        }
      }
      return await pendingChanges.commit();
    }

    return null;
  });

export const tempUpdateUserData = functions.https.onCall(async (data) => {
  if (data.adminPassword === adminPassword) {
    const user = await auth().getUser(data.affectedUser);

    const newPermissions = data.permissions;
    const oldPermissions = user.customClaims;

    newPermissions["approved"] =
      data.permissions.approved ?? user.customClaims.approved;
    newPermissions["birthdayNotify"] =
      data.permissions.birthdayNotify ?? user.customClaims.birthdayNotify;
    newPermissions["confessionsNotify"] =
      data.permissions.confessionsNotify ?? user.customClaims.confessionsNotify;
    newPermissions["exportClasses"] =
      data.permissions.exportClasses ?? user.customClaims.exportClasses;
    newPermissions["kodasNotify"] =
      data.permissions.kodasNotify ?? user.customClaims.kodasNotify;
    newPermissions["manageAllowedUsers"] =
      data.permissions.manageAllowedUsers ??
      user.customClaims.manageAllowedUsers;
    newPermissions["manageDeleted"] =
      data.permissions.manageDeleted ?? user.customClaims.manageDeleted;
    newPermissions["manageUsers"] =
      data.permissions.manageUsers ?? user.customClaims.manageUsers;
    newPermissions["meetingNotify"] =
      data.permissions.meetingNotify ?? user.customClaims.meetingNotify;
    newPermissions["secretary"] =
      data.permissions.secretary ?? user.customClaims.secretary;
    newPermissions["superAccess"] =
      data.permissions.superAccess ?? user.customClaims.superAccess;
    newPermissions["tanawolNotify"] =
      data.permissions.tanawolNotify ?? user.customClaims.tanawolNotify;
    newPermissions["write"] = data.permissions.write ?? user.customClaims.write;

    try {
      const tokens = await getFCMTokensForUser(data.affectedUser);
      if (
        oldPermissions.manageUsers !== newPermissions["manageUsers"] &&
        tokens !== null &&
        tokens !== [] &&
        tokens !== undefined &&
        tokens !== ""
      ) {
        if (newPermissions["manageUsers"]) {
          await messaging().subscribeToTopic(tokens, "ManagingUsers");
        } else if (newPermissions["manageUsers"] === false) {
          await messaging().unsubscribeFromTopic(tokens, "ManagingUsers");
        } else if (
          oldPermissions.manageAllowedUsers !==
            newPermissions["manageAllowedUsers"] &&
          tokens !== null &&
          tokens !== [] &&
          tokens !== undefined &&
          tokens !== ""
        ) {
          if (newPermissions["manageAllowedUsers"]) {
            await messaging().subscribeToTopic(tokens, "ManagingUsers");
          } else if (newPermissions["manageAllowedUsers"] === false) {
            await messaging().unsubscribeFromTopic(tokens, "ManagingUsers");
          }
        }
      }
    } catch (e) {}
    await auth().setCustomUserClaims(data.affectedUser, newPermissions);

    delete newPermissions["password"];
    delete newPermissions["lastConfession"];
    delete newPermissions["lastTanawol"];
    delete newPermissions["personId"];

    await firestore()
      .doc("UsersData/" + user.customClaims.personId)
      .update({
        LastTanawol:
          Object.assign(oldPermissions, newPermissions).lastTanawol !== null &&
          Object.assign(oldPermissions, newPermissions).lastTanawol !==
            undefined
            ? Timestamp.fromMillis(
                Object.assign(oldPermissions, newPermissions).lastTanawol
              )
            : null,
        LastConfession:
          Object.assign(oldPermissions, newPermissions).lastConfession !==
            null &&
          Object.assign(oldPermissions, newPermissions).lastConfession !==
            undefined
            ? Timestamp.fromMillis(
                Object.assign(oldPermissions, newPermissions).lastConfession
              )
            : null,
        Permissions: toCamel(newPermissions),
      });
    await database()
      .ref()
      .child("Users/" + data.affectedUser + "/forceRefresh")
      .set(true);
    return "OK";
  }
  throw new functions.https.HttpsError("unauthenticated", "");
});

function toCamel(o) {
  let newO, origKey, newKey, value;
  if (o instanceof Array) {
    return o.map(function (invalue) {
      if (typeof invalue === "object") {
        return toCamel(invalue);
      }
      return invalue;
    });
  } else {
    newO = {};
    for (origKey in o) {
      if (o.hasOwnProperty(origKey)) {
        newKey = (
          origKey.charAt(0).toUpperCase() + origKey.slice(1) || origKey
        ).toString();
        value = o[origKey];
        if (
          value instanceof Array ||
          (value !== null && value.constructor === Object)
        ) {
          value = toCamel(value);
        }
        newO[newKey] = value;
      }
    }
  }
  return newO;
}
