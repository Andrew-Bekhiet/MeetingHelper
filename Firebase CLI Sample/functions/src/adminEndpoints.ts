import { https } from "firebase-functions";

import { auth, firestore, database, messaging } from "firebase-admin";

import { assertNotEmpty, getFCMTokensForUser } from "./common";
import { adminPassword } from "./adminPassword";
import { Timestamp } from "@google-cloud/firestore";

export const getUsers = https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    if (data.AdminPassword === adminPassword) {
      return (await auth().listUsers()).users.map((user) => {
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
      throw new https.HttpsError("unauthenticated", "unauthenticated");
    }
  }
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    currentUser.customClaims?.manageUsers
  ) {
    return (await auth().listUsers()).users
      .filter((user) => {
        return !user.disabled;
      })
      .map((user) => {
        const customClaims = user.customClaims ? user.customClaims : {};
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
    currentUser.customClaims?.approved &&
    currentUser.customClaims?.manageAllowedUsers
  ) {
    const allowedUsers = (
      await firestore()
        .collection("UsersData")
        .where("AllowedUsers", "array-contains", currentUser.uid)
        .get()
    ).docs.map((u) => u.id);
    return (await auth().listUsers()).users
      .filter((user) => !user.disabled && allowedUsers.includes(user.uid))
      .map((user) => {
        const customClaims = user.customClaims ? user.customClaims : {};
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
  throw new https.HttpsError(
    "unauthenticated",
    "Must be an approved user with 'manageUsers' or 'manageAllowedUsers' permissions"
  );
});

export const approveUser = https.onCall(async (data, context) => {
  if (!context.auth)
    throw new https.HttpsError("unauthenticated", "unauthenticated");

  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    currentUser.customClaims?.manageUsers
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    const user = await auth().getUser(data.affectedUser);
    if (!user.customClaims?.personId) {
      console.error("User " + data.affectedUser + " doesn't have personId");
      console.log(user);
      throw new https.HttpsError("internal", "Internal error");
    }
    const newClaims = user.customClaims ? user.customClaims : {};
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
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const unApproveUser = https.onCall(async (data, context) => {
  if (!context.auth)
    throw new https.HttpsError("unauthenticated", "unauthenticated");

  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (
            await firestore()
              .collection("UsersData")
              .doc(
                (
                  await auth().getUser(data.affectedUser)
                ).customClaims!.personId
              )
              .get()
          ).data()!.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
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
    });
    await firestore()
      .doc("Users/" + data.affectedUser)
      .delete();
    await firestore()
      .doc("UsersData/" + user.customClaims!.personId)
      .update({ "Permissions.Approved": false });
    return "OK";
  }
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const deleteUser = https.onCall(async (data, context) => {
  if (!context.auth)
    throw new https.HttpsError("unauthenticated", "unauthenticated");
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (
            await firestore()
              .collection("UsersData")
              .doc(
                (
                  await auth().getUser(data.affectedUser)
                ).customClaims!.personId
              )
              .get()
          ).data()!.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    await auth().getUser(data.affectedUser);
    await auth().deleteUser(data.affectedUser);
    return "OK";
  }
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const resetPassword = https.onCall(async (data, context) => {
  if (!context.auth)
    throw new https.HttpsError("unauthenticated", "unauthenticated");
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (
            await firestore()
              .collection("UsersData")
              .doc(
                (
                  await auth().getUser(data.affectedUser)
                ).customClaims!.personId
              )
              .get()
          ).data()!.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
  ) {
    assertNotEmpty("affectedUser", data.affectedUser, typeof "");
    const user = await auth().getUser(data.affectedUser);
    const newClaims = user.customClaims ? user.customClaims : {};
    newClaims.password = null;
    await auth().setCustomUserClaims(user.uid, newClaims);
    await database()
      .ref()
      .child("Users/" + user.uid + "/forceRefresh")
      .set(true);
    return "OK";
  }
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const updatePermissions = https.onCall(async (data, context) => {
  if (!context.auth)
    throw new https.HttpsError("unauthenticated", "unauthenticated");
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (
            await firestore()
              .collection("UsersData")
              .doc(
                (
                  await auth().getUser(data.affectedUser)
                ).customClaims!.personId
              )
              .get()
          ).data()!.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
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
      assertNotEmpty("permissions.write", data.permissions.write, typeof true);
    if (data.permissions.secretary !== undefined)
      assertNotEmpty(
        "permissions.secretary",
        data.permissions.secretary,
        typeof true
      );
    if (data.permissions.changeHistory !== undefined)
      assertNotEmpty(
        "permissions.changeHistory",
        data.permissions.changeHistory,
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

    if (!user.customClaims?.personId) {
      console.error("User " + data.affectedUser + " doesn't have personId");
      console.log(user);
      throw new https.HttpsError("internal", "Internal error");
    }

    const newPermissions: Record<string, any> = {};
    const oldPermissions = user.customClaims ? user.customClaims : {};

    console.log(oldPermissions);
    console.log(newPermissions);

    newPermissions["approved"] = oldPermissions.approved;
    newPermissions["lastTanawol"] =
      data.permissions.lastTanawol !== null &&
      data.permissions.lastTanawol !== undefined
        ? data.permissions.lastTanawol
        : oldPermissions.lastTanawol;
    newPermissions["lastConfession"] =
      data.permissions.lastConfession !== null &&
      data.permissions.lastConfession !== undefined
        ? data.permissions.lastConfession
        : oldPermissions.lastConfession;
    newPermissions["birthdayNotify"] =
      data.permissions.birthdayNotify !== null &&
      data.permissions.birthdayNotify !== undefined
        ? data.permissions.birthdayNotify
        : oldPermissions.birthdayNotify;
    newPermissions["confessionsNotify"] =
      data.permissions.confessionsNotify !== null &&
      data.permissions.confessionsNotify !== undefined
        ? data.permissions.confessionsNotify
        : oldPermissions.confessionsNotify;
    newPermissions["export"] =
      data.permissions.export !== null && data.permissions.export !== undefined
        ? data.permissions.export
        : oldPermissions.export;
    newPermissions["kodasNotify"] =
      data.permissions.kodasNotify !== null &&
      data.permissions.kodasNotify !== undefined
        ? data.permissions.kodasNotify
        : oldPermissions.kodasNotify;
    newPermissions["manageAllowedUsers"] =
      data.permissions.manageAllowedUsers !== null &&
      data.permissions.manageAllowedUsers !== undefined
        ? data.permissions.manageAllowedUsers
        : oldPermissions.manageAllowedUsers;
    newPermissions["manageDeleted"] =
      data.permissions.manageDeleted !== null &&
      data.permissions.manageDeleted !== undefined
        ? data.permissions.manageDeleted
        : oldPermissions.manageDeleted;
    newPermissions["manageUsers"] =
      data.permissions.manageUsers !== null &&
      data.permissions.manageUsers !== undefined
        ? data.permissions.manageUsers
        : oldPermissions.manageUsers;
    newPermissions["meetingNotify"] =
      data.permissions.meetingNotify !== null &&
      data.permissions.meetingNotify !== undefined
        ? data.permissions.meetingNotify
        : oldPermissions.meetingNotify;
    newPermissions["visitNotify"] =
      data.permissions.visitNotify !== null &&
      data.permissions.visitNotify !== undefined
        ? data.permissions.visitNotify
        : oldPermissions.visitNotify;
    newPermissions["secretary"] =
      data.permissions.secretary !== null &&
      data.permissions.secretary !== undefined
        ? data.permissions.secretary
        : oldPermissions.secretary;
    newPermissions["changeHistory"] =
      data.permissions.changeHistory !== null &&
      data.permissions.changeHistory !== undefined
        ? data.permissions.changeHistory
        : oldPermissions.changeHistory;
    newPermissions["superAccess"] =
      data.permissions.superAccess !== null &&
      data.permissions.superAccess !== undefined
        ? data.permissions.superAccess
        : oldPermissions.superAccess;
    newPermissions["tanawolNotify"] =
      data.permissions.tanawolNotify !== null &&
      data.permissions.tanawolNotify !== undefined
        ? data.permissions.tanawolNotify
        : oldPermissions.tanawolNotify;
    newPermissions["write"] =
      data.permissions.write !== null && data.permissions.write !== undefined
        ? data.permissions.write
        : oldPermissions.write;

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
    } catch (e) {
      console.error(e);
    }
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
      .doc("UsersData/" + user.customClaims!.personId)
      .set(
        {
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
        },
        { merge: true }
      );
    await database()
      .ref()
      .child("Users/" + data.affectedUser + "/forceRefresh")
      .set(true);
    return "OK";
  }
  throw new https.HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

/* export const migrateHistory = functions
  .runWith({ timeoutSeconds: 540, memory: "512MB" })
  .https.onCall(async (data) => {
    if (data.AdminPassword === AdminPassword) {
      let pendingChanges = firestore().batch();

      let batchCount = 0;

      let snapshot: firestore.QuerySnapshot<firestore.DocumentData>;
      for (const collection of ["Meeting", "Kodas", "Tanawol"]) {
        snapshot = await firestore().collectionGroup(collection).get();
        for (let i = 0, l = snapshot.docs.length; i < l; i++, batchCount++) {
          if (batchCount % 500 === 0) {
            await pendingChanges.commit();
            pendingChanges = firestore().batch();
          }
          if (
            !snapshot.docs[i].ref.path.startsWith("ServantsHistory") ||
            snapshot.docs[i].id.length > "FqlutH4eP2uQEygZ3hHg".length
          )
            continue;
          console.log(snapshot.docs[i].ref.id);
          pendingChanges.delete(snapshot.docs[i].ref);
          pendingChanges.set(
            snapshot.docs[i].ref.parent.doc(
              (
                await firestore()
                  .collection("UsersData")
                  .doc(snapshot.docs[i].ref.id)
                  .get()
              ).data()["UID"]
            ),
            snapshot.docs[i].data()
          );
          console.log("done: " + snapshot.docs[i].ref.path);
        }
      }

      return await pendingChanges.commit();
    }

    return null;
  }); */

export const tempUpdateUserData = https.onCall(async (data) => {
  if (data.AdminPassword === adminPassword) {
    const user = await auth().getUser(data.affectedUser);

    const newPermissions = data.permissions;
    const oldPermissions = user.customClaims ? user.customClaims : {};

    newPermissions["approved"] =
      data.permissions.approved ?? user.customClaims?.approved ?? false;
    newPermissions["birthdayNotify"] =
      data.permissions.birthdayNotify ??
      user.customClaims?.birthdayNotify ??
      false;
    newPermissions["confessionsNotify"] =
      data.permissions.confessionsNotify ??
      user.customClaims?.confessionsNotify ??
      false;
    newPermissions["export"] =
      data.permissions.export ?? user.customClaims?.export ?? false;
    newPermissions["kodasNotify"] =
      data.permissions.kodasNotify ?? user.customClaims?.kodasNotify ?? false;
    newPermissions["manageAllowedUsers"] =
      data.permissions.manageAllowedUsers ??
      user.customClaims?.manageAllowedUsers ??
      false;
    newPermissions["manageDeleted"] =
      data.permissions.manageDeleted ??
      user.customClaims?.manageDeleted ??
      false;
    newPermissions["manageUsers"] =
      data.permissions.manageUsers ?? user.customClaims?.manageUsers ?? false;
    newPermissions["meetingNotify"] =
      data.permissions.meetingNotify ??
      user.customClaims?.meetingNotify ??
      false;
    newPermissions["visitNotify"] =
      data.permissions.visitNotify ?? user.customClaims?.visitNotify ?? false;
    newPermissions["secretary"] =
      data.permissions.secretary ?? user.customClaims?.secretary ?? false;
    newPermissions["superAccess"] =
      data.permissions.superAccess ?? user.customClaims?.superAccess ?? false;
    newPermissions["tanawolNotify"] =
      data.permissions.tanawolNotify ??
      user.customClaims?.tanawolNotify ??
      false;
    newPermissions["write"] =
      data.permissions.write ?? user.customClaims?.write ?? false;

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
    } catch (e) {
      console.log(e);
    }
    await auth().setCustomUserClaims(data.affectedUser, newPermissions);

    delete newPermissions["password"];
    delete newPermissions["lastConfession"];
    delete newPermissions["lastTanawol"];
    delete newPermissions["personId"];

    await firestore()
      .doc("UsersData/" + user.customClaims!.personId)
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
  throw new https.HttpsError("unauthenticated", "");
});

function toCamel(o: any): any {
  let origKey, newKey, value;
  if (o instanceof Array) {
    return o.map((invalue) => {
      if (typeof invalue === "object") {
        return toCamel(invalue);
      }
      return invalue;
    });
  } else {
    const newO: Record<string, any> = {};
    for (origKey in o) {
      if (Object.prototype.hasOwnProperty.call(o, origKey)) {
        newKey = (
          origKey.charAt(0).toUpperCase() + origKey.slice(1) || origKey
        ).toString();
        value = o[origKey];
        if (
          value instanceof Array ||
          (value !== null &&
            value !== undefined &&
            value.constructor === Object)
        ) {
          value = toCamel(value);
        }
        if (value !== undefined) newO[newKey] = value;
      }
    }
    return newO;
  }
}
