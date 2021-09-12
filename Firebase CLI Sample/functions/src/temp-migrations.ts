import { auth, firestore } from "firebase-admin";
import { https } from "firebase-functions";
import { adminPassword } from "./adminPassword";

export const migrateFromV6 = https.onCall(async (data) => {
  if (data.AdminPassword !== adminPassword)
    throw new https.HttpsError("unauthenticated", "unauthenticated");

  console.log("Migrating Users claims...");

  const { users } = await auth().listUsers();
  const promises = [];

  for (const user of users) {
    const newClaims: Record<string, any> = {
      password: null, //Empty password
      manageUsers: false, //Can manage Users' names, reset passwords and permissions
      manageAllowedUsers: false, //Can manage specific Users' names, reset passwords and permissions
      manageDeleted: false, //Can read deleted items and restore them
      superAccess: false, //Can read everything
      write: true, //Can write avalibale data
      secretary: false, //Can write servants history
      changeHistory: false,
      export: user.customClaims?.exportClasses
        ? user.customClaims!.exportClasses!
        : true, //Can Export individual Classes to Excel sheet
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
      personId: firestore().collection("UsersData").doc().id,
      ...user.customClaims,
    };
    delete newClaims.exportClasses;
    delete newClaims.approveLocations;

    promises.push(auth().setCustomUserClaims(user.uid, newClaims));
  }
  await Promise.all(promises);

  console.log("Migrating Persons data...");

  let batch = firestore().batch();
  let batchCount = 0;

  const classes: Record<string, firestore.QueryDocumentSnapshot> = (
    await firestore().collection("Classes").get()
  ).docs.reduce<Record<string, firestore.QueryDocumentSnapshot>>((map, c) => {
    map[c.id] = c;
    return map;
  }, {});

  const persons = (await firestore().collection("Persons").get()).docs;

  for (const person of persons) {
    if (!person.data().ClassId) {
      console.warn("Skipped " + person.ref.id + "because it has null ClassId");
      continue;
    }

    if (batchCount !== 0 && batchCount % 500 == 0) {
      console.log(await batch.commit());
      batch = firestore().batch();
    }
    console.log("Updating: " + person.id);
    console.log(
      "Class Data: " +
        classes[
          (person.data().ClassId as firestore.DocumentReference).id
        ]?.data()
    );

    batch.update(person.ref, {
      IsShammas: false,
      Gender: classes[
        (person.data().ClassId as firestore.DocumentReference).id
      ]?.data().Gender
        ? classes[
            (person.data().ClassId as firestore.DocumentReference).id
          ].data().Gender
        : false,
      ShammasLevel: null,
      StudyYear: classes[
        (person.data().ClassId as firestore.DocumentReference).id
      ]?.data().StudyYear
        ? classes[
            (person.data().ClassId as firestore.DocumentReference).id
          ].data().StudyYear
        : null,
      Services: [],
    });
    batchCount++;
  }
  console.log(await batch.commit());
  /* 
  console.log("Migrating History data...");

  batch = firestore().batch();

  const meeting = (await firestore().collectionGroup("Meeting").get()).docs;
  const kodas = (await firestore().collectionGroup("Kodas").get()).docs;

  for (const record of [...meeting, ...kodas]) {
    if (record.data()?.studyYear) {
      console.warn(
        "Skipped " + record.ref.id + "because it already has StudyYear"
      );
      continue;
    }
    if (!record.data().ClassId) {
      console.warn("Skipped " + record.ref.id + "because its ClassId is null");
      continue;
    }

    if (batchCount !== 0 && batchCount % 500 == 0) {
      console.log(await batch.commit());
      batch = firestore().batch();
    }
    console.log("Updating: " + record.id);
    console.log("Class Data: " + classes[record.data().ClassId.id].data());

    batch.update(record.ref, {
      StudyYear: classes[record.data()?.ClassId?.id]?.data()?.StudyYear
        ? classes[record.data()?.ClassId?.id]?.data()?.StudyYear
        : null,
    });
    batchCount++;
  }
  console.log(await batch.commit()); */
});
