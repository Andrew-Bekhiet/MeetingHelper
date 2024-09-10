import { FieldValue, Timestamp } from "@google-cloud/firestore";
import { auth, database, firestore } from "firebase-admin";
import { https as _https } from "firebase-functions";
import { assertNotEmpty } from "./common";

const https = _https;
const HttpsError = _https.HttpsError;

export const approveUser = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");

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
      throw new HttpsError("internal", "Internal error");
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
  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const unApproveUser = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");

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
      recordHistory: false, //Can record history
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
  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const deleteUser = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");
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
  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const resetPassword = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");
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
  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});

export const updatePermissions = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");
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
    if (data.permissions.recordHistory !== undefined)
      assertNotEmpty(
        "permissions.recordHistory",
        data.permissions.recordHistory,
        typeof true
      );
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
      throw new HttpsError("internal", "Internal error");
    }

    const newPermissions: Record<string, any> = {};
    const oldPermissions = user.customClaims ? user.customClaims : {};

    console.log(oldPermissions);
    console.log(newPermissions);

    newPermissions["approved"] = oldPermissions.approved;
    newPermissions["lastTanawol"] =
      data.permissions.lastTanawol ?? oldPermissions.lastTanawol;
    newPermissions["lastConfession"] =
      data.permissions.lastConfession ?? oldPermissions.lastConfession;
    newPermissions["birthdayNotify"] =
      data.permissions.birthdayNotify ?? oldPermissions.birthdayNotify;
    newPermissions["confessionsNotify"] =
      data.permissions.confessionsNotify ?? oldPermissions.confessionsNotify;
    newPermissions["export"] = data.permissions.export ?? oldPermissions.export;
    newPermissions["kodasNotify"] =
      data.permissions.kodasNotify ?? oldPermissions.kodasNotify;
    newPermissions["manageAllowedUsers"] =
      data.permissions.manageAllowedUsers ?? oldPermissions.manageAllowedUsers;
    newPermissions["manageDeleted"] =
      data.permissions.manageDeleted ?? oldPermissions.manageDeleted;
    newPermissions["manageUsers"] =
      data.permissions.manageUsers ?? oldPermissions.manageUsers;
    newPermissions["meetingNotify"] =
      data.permissions.meetingNotify ?? oldPermissions.meetingNotify;
    newPermissions["visitNotify"] =
      data.permissions.visitNotify ?? oldPermissions.visitNotify;
    newPermissions["recordHistory"] =
      data.permissions.recordHistory ?? oldPermissions.recordHistory;
    newPermissions["secretary"] =
      data.permissions.secretary ?? oldPermissions.secretary;
    newPermissions["changeHistory"] =
      data.permissions.changeHistory ?? oldPermissions.changeHistory;
    newPermissions["superAccess"] =
      data.permissions.superAccess ?? oldPermissions.superAccess;
    newPermissions["tanawolNotify"] =
      data.permissions.tanawolNotify ?? oldPermissions.tanawolNotify;
    newPermissions["write"] = data.permissions.write ?? oldPermissions.write;

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
  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
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

export const updateUser = https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "unauthenticated");

  if (typeof data.UID !== typeof "")
    throw new HttpsError("invalid-argument", "UID must be string");
  if (!data.Changes)
    throw new HttpsError("invalid-argument", "Changes must be non empty");

  const currentUser = await auth().getUser(context.auth.uid);
  if (
    currentUser.customClaims?.approved &&
    (currentUser.customClaims?.manageUsers ||
      (currentUser.customClaims?.manageAllowedUsers &&
        (
          (
            await firestore()
              .collection("UsersData")
              .doc((await auth().getUser(data.UID)).customClaims!.personId)
              .get()
          ).data()!.AllowedUsers as Array<string>
        ).includes(currentUser.uid)))
  ) {
    if (data.Changes.Name && typeof data.Changes.Name != typeof "")
      throw new HttpsError("invalid-argument", "Changes.Name must be string");
    if (data.Changes.LastTanawol && typeof data.Changes.LastTanawol != typeof 0)
      throw new HttpsError(
        "invalid-argument",
        "Changes.LastTanawol must be number"
      );
    if (
      data.Changes.LastConfessoin &&
      typeof data.Changes.LastConfessoin != typeof 0
    )
      throw new HttpsError(
        "invalid-argument",
        "Changes.LastConfessoin must be number"
      );
    if (
      data.Changes.Permissions &&
      typeof data.Changes.Permissions != typeof Array<string>()
    )
      throw new HttpsError(
        "invalid-argument",
        "Changes.Permissions must be Array<string>"
      );
    if (
      data.Changes.ChildrenUsers &&
      typeof data.Changes.ChildrenUsers != typeof Array<string>()
    )
      throw new HttpsError(
        "invalid-argument",
        "Changes.ChildrenUsers must be Array<string>"
      );
    if (
      data.Changes.AdminServices &&
      typeof data.Changes.AdminServices != typeof Array<string>()
    )
      throw new HttpsError(
        "invalid-argument",
        "Changes.AdminServices must be Array<string>"
      );

    const changes = {
      Name: data.Changes.Name as string | null,
      LastTanawol: data.Changes.LastTanawol as number | null,
      LastConfession: data.Changes.LastConfession as number | null,
      Permissions: data.Changes.Permissions
        ? new Set(data.Changes.Permissions as Array<string>)
        : null,
      ChildrenUsers: data.Changes.ChildrenUsers as string[] | null,
      AdminServices: data.Changes.AdminServices
        ? (data.Changes.AdminServices as Array<string>).map((v) =>
            firestore().doc(v)
          )
        : null,
    };

    await firestore().runTransaction(async (tr) => {
      const affectedUser = await auth().getUser(data.UID);
      if (!affectedUser.customClaims?.personId) {
        console.error("User " + data.UID + " doesn't have personId");
        console.log(affectedUser);
        throw new HttpsError("internal", "Internal error");
      }

      let childrenUsers: firestore.QueryDocumentSnapshot<firestore.DocumentData>[];
      let oldChildren: {
        UID: string | null;
        ref: firestore.DocumentReference<firestore.DocumentData>;
      }[];

      let oldAdminServices: firestore.DocumentReference<firestore.DocumentData>[];

      const currentUserData = await tr.get(
        firestore()
          .collection("UsersData")
          .doc(currentUser.customClaims!.personId)
      );

      if (changes.AdminServices) {
        oldAdminServices = currentUserData.data()![
          "AdminServices"
        ] as Array<firestore.DocumentReference>;
      }

      if (changes.ChildrenUsers) {
        childrenUsers = (
          await Promise.all(
            changes.ChildrenUsers.map(async (v) => {
              const query = await tr.get(
                firestore().collection("UsersData").where("UID", "==", v)
              );

              if (
                query.empty ||
                query.size > 1 ||
                !(
                  currentUser.customClaims?.manageUsers ||
                  (currentUser.customClaims?.manageAllowedUsers &&
                    (
                      query.docs[0].data()["AllowedUsers"] as Array<string>
                    ).includes(currentUser.uid))
                )
              )
                return null;
              return query.docs[0];
            })
          )
        ).filter<firestore.QueryDocumentSnapshot>(
          (v): v is firestore.QueryDocumentSnapshot => v != null
        );

        oldChildren = (
          await tr.get(
            firestore()
              .collection("UsersData")
              .where("AllowedUsers", "array-contains", affectedUser.uid)
          )
        ).docs
          .map((v) => {
            return { UID: v.data()?.["UID"] as string | null, ref: v.ref };
          })
          .filter((v) => v.UID != null);
      }

      if (changes.Name) {
        await auth().updateUser(affectedUser.uid, {
          displayName: changes.Name,
        });
        tr.update(firestore().doc("Users/" + affectedUser.uid), {
          Name: changes.Name,
        });
        tr.update(
          firestore().doc("UsersData/" + affectedUser.customClaims?.personId),
          { Name: changes.Name }
        );
      }

      if (
        changes.Permissions ||
        changes.LastConfession ||
        changes.LastTanawol
      ) {
        const newPermissions: Record<string, any> = {};
        const oldPermissions = affectedUser.customClaims
          ? affectedUser.customClaims
          : {};

        newPermissions["approved"] = oldPermissions.approved;
        newPermissions["lastTanawol"] =
          changes.LastTanawol ?? oldPermissions.lastTanawol;
        newPermissions["lastConfession"] =
          changes.LastConfession ?? oldPermissions.lastConfession;
        newPermissions["birthdayNotify"] =
          changes.Permissions?.has("birthdayNotify") ??
          oldPermissions.birthdayNotify;
        newPermissions["confessionsNotify"] =
          changes.Permissions?.has("confessionsNotify") ??
          oldPermissions.confessionsNotify;
        newPermissions["export"] =
          changes.Permissions?.has("export") ?? oldPermissions.export;
        newPermissions["kodasNotify"] =
          changes.Permissions?.has("kodasNotify") ?? oldPermissions.kodasNotify;
        newPermissions["manageAllowedUsers"] =
          changes.Permissions?.has("manageAllowedUsers") ??
          oldPermissions.manageAllowedUsers;
        newPermissions["manageDeleted"] =
          changes.Permissions?.has("manageDeleted") ??
          oldPermissions.manageDeleted;
        newPermissions["manageUsers"] =
          changes.Permissions?.has("manageUsers") ?? oldPermissions.manageUsers;
        newPermissions["meetingNotify"] =
          changes.Permissions?.has("meetingNotify") ??
          oldPermissions.meetingNotify;
        newPermissions["visitNotify"] =
          changes.Permissions?.has("visitNotify") ?? oldPermissions.visitNotify;
        newPermissions["recordHistory"] =
          changes.Permissions?.has("recordHistory") ??
          oldPermissions.recordHistory;
        newPermissions["secretary"] =
          changes.Permissions?.has("secretary") ?? oldPermissions.secretary;
        newPermissions["changeHistory"] =
          changes.Permissions?.has("changeHistory") ??
          oldPermissions.changeHistory;
        newPermissions["superAccess"] =
          changes.Permissions?.has("superAccess") ?? oldPermissions.superAccess;
        newPermissions["tanawolNotify"] =
          changes.Permissions?.has("tanawolNotify") ??
          oldPermissions.tanawolNotify;
        newPermissions["write"] =
          changes.Permissions?.has("write") ?? oldPermissions.write;

        await auth().setCustomUserClaims(
          affectedUser.uid,
          Object.assign(
            {
              password: oldPermissions.password,
              personId: oldPermissions.personId,
              lastTanawol: newPermissions.lastTanawol,
              lastConfession: newPermissions.lastConfession,
            },
            newPermissions
          )
        );

        tr.set(
          firestore().doc("UsersData/" + affectedUser.customClaims!.personId),
          {
            LastTanawol: Timestamp.fromMillis(newPermissions.lastTanawol),
            LastConfession: Timestamp.fromMillis(newPermissions.lastConfession),
            Permissions: toCamel(newPermissions),
          },
          { merge: true }
        );
        await database()
          .ref()
          .child("Users/" + affectedUser.uid + "/forceRefresh")
          .set(true);
      }

      if (changes.ChildrenUsers) {
        for (const item of oldChildren!) {
          if (
            !changes.ChildrenUsers!.includes(item.UID!) &&
            (currentUser.customClaims?.manageUsers ||
              (currentUser.customClaims?.manageAllowedUsers &&
                (
                  currentUserData.data()!["AllowedUsers"] as Array<string>
                ).includes(item.UID!)))
          ) {
            tr.update(item.ref, {
              AllowedUsers: FieldValue.arrayRemove(affectedUser.uid),
            });
          }
        }

        for (const item of childrenUsers!) {
          const find = oldChildren!.filter(
            (v) => v.UID == item.data()?.["UID"]
          );

          if (find.length == 0) {
            tr.update(item.ref, {
              AllowedUsers: FieldValue.arrayUnion(affectedUser.uid),
            });
          }
        }
      }

      if (changes.AdminServices) {
        const isEqual =
          changes.AdminServices.length === oldAdminServices!.length &&
          changes.AdminServices.every(
            (item, i) => oldAdminServices[i] === item
          );

        if (!isEqual) {
          tr.update(
            firestore()
              .collection("UsersData")
              .doc(affectedUser.customClaims!.personId),
            { AdminServices: changes.AdminServices }
          );
        }
      }
    });

    return "OK";
  }

  throw new HttpsError(
    "permission-denied",
    "Must be an approved user with 'manageUsers' permission"
  );
});
