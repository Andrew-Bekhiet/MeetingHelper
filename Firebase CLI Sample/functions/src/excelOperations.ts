import { runWith } from "firebase-functions";
import { HttpsError } from "firebase-functions/lib/providers/https";

import { auth, firestore, storage } from "firebase-admin";
import { Timestamp } from "@google-cloud/firestore";

import { utils, writeFile, readFile } from "xlsx";
import * as download from "download";

import { assertNotEmpty } from "./common";

export const exportToExcel = runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new HttpsError("unauthenticated", "");
  }
  const currentUser = await auth().getUser(context.auth.uid);
  if (
    !(
      currentUser.customClaims?.approved &&
      currentUser.customClaims?.exportClasses
    )
  ) {
    throw new HttpsError(
      "permission-denied",
      'Must be approved user with "Export Classes" permission'
    );
  }

  let _class: FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>;
  console.log(currentUser);
  console.log(data);

  if (data?.onlyClass) {
    assertNotEmpty("onlyClass", data?.onlyClass, typeof "");
    _class = await firestore().collection("Classes").doc(data?.onlyClass).get();
    if (!currentUser.customClaims.superAccess) {
      if (
        !_class.exists ||
        !(_class.data()!.Allowed as string[]).includes(currentUser.uid)
      )
        throw new HttpsError(
          "permission-denied",
          "User doesn't have permission to export the required class"
        );
    }
  }

  console.log(
    "Starting export operation from user: " +
      context.auth.uid +
      " for " +
      (data?.onlyClass
        ? "class: " + data?.onlyClass
        : "all data avaliable for the user")
  );

  const users = (await firestore().collection("Users").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data().Name ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );

  const studyYears = (
    await firestore().collection("StudyYears").get()
  ).docs.reduce((map, obj) => {
    map[obj.id] = obj.data().Name ?? "(غير معروف)";
    return map;
  }, {} as Record<string, string>);
  const schools = (await firestore().collection("Schools").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data().Name ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );
  const churches = (await firestore().collection("Churches").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data().Name ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );
  const cfathers = (await firestore().collection("Fathers").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data().Name ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );

  let classes: Record<string, Record<string, any>> = {};
  if (data?.onlyClass) {
    const _classData = _class!.data() ?? {};

    const rslt: Record<string, string> = {};
    rslt["Name"] = _classData["Name"];
    rslt["ID"] = _class!.id;
    rslt["Color"] = _classData["Color"];
    rslt["Study Year"] =
      studyYears[(_classData["StudyYear"] as firestore.DocumentReference)?.id];
    rslt["Class Gender"] =
      _classData["Gender"] === true
        ? "بنين"
        : _classData["Gender"] === false
        ? "بنات"
        : "(غير معروف)";
    rslt["Last Edit"] = users[_classData["LastEdit"]] ?? "";
    rslt["Allowed Users"] =
      (_classData["Allowed"] as string[])
        ?.map((u) => users[u] ?? "(غير معروف)")
        ?.reduce((arr, o) => arr + "," + o) ?? "";
    classes[_class!.id] = rslt;
  } else {
    classes = (
      currentUser.customClaims.superAccess
        ? await firestore().collection("Classes").orderBy("Name").get()
        : await firestore()
            .collection("Classes")
            .where("Allowed", "array-contains", currentUser.uid)
            .orderBy("Name")
            .get()
    ).docs.reduce<Record<string, Record<string, any>>>((map, c) => {
      const rslt: Record<string, string> = {};
      rslt["ID"] = c.id;
      rslt["Name"] = c.data()["Name"];
      rslt["Color"] = c.data()["Color"];
      rslt["Study Year"] =
        studyYears[(c.data()["StudyYear"] as firestore.DocumentReference)?.id];
      rslt["Class Gender"] =
        c.data()["Gender"] === true
          ? "بنين"
          : c.data()["Gender"] === false
          ? "بنات"
          : "(غير معروف)";
      rslt["Last Edit"] = users[c.data()["LastEdit"]] ?? "";
      rslt["Allowed Users"] =
        (c.data()["Allowed"] as string[])
          ?.map((u) => users[u] ?? "(غير معروف)")
          ?.reduce((arr, o) => arr + "," + o) ?? "";

      map[c.id] = rslt;
      return map;
    }, {});
  }

  const persons = (
    data?.onlyClass
      ? await firestore()
          .collection("Persons")
          .where("ClassId", "==", _class!.ref)
          .orderBy("Name")
          .get()
      : currentUser.customClaims.superAccess
      ? await firestore().collection("Persons").orderBy("Name").get()
      : await firestore()
          .collection("Persons")
          .where(
            "ClassId",
            "in",
            Object.keys(classes).map((a) =>
              firestore().collection("Classes").doc(a)
            )
          )
          .orderBy("Name")
          .get()
  ).docs.reduce<Record<string, Record<string, any>>>((map, p) => {
    const rslt: Record<string, string | Date> = {};

    rslt["ClassId"] = (p.data()["ClassId"] as firestore.DocumentReference)?.id;
    rslt["ID"] = p.id;
    rslt["Class Name"] =
      classes[(p.data()["ClassId"] as firestore.DocumentReference)?.id]?.Name ??
      "(غير موجود)";
    rslt["Name"] = p.data()["Name"];
    rslt["Color"] = p.data()["Color"];
    rslt["Phone Number"] = p.data()["Phone"];
    rslt["Father Phone Number"] = p.data()["FatherPhone"];
    rslt["Mother Phone Number"] = p.data()["MotherPhone"];
    Object.assign(rslt, p.data()["Phones"]);

    rslt["Address"] = p.data()["Address"];
    rslt["Location"] = p.data()["Location"]
      ? `${(p.data()["Location"] as firestore.GeoPoint).longitude},${
          (p.data()["Location"] as firestore.GeoPoint).latitude
        }`
      : "";
    rslt["Birth Date"] = (p.data()["BirthDate"] as Timestamp)?.toDate() ?? "";
    rslt["Study Year"] = classes[
      (p.data()["ClassId"] as firestore.DocumentReference)?.id
    ]
      ? classes[(p.data()["ClassId"] as firestore.DocumentReference)?.id][
          "Study Year"
        ]
      : "(غير موجود)";

    rslt["Notes"] = p.data()["Notes"];
    rslt["School"] =
      schools[(p.data()["School"] as firestore.DocumentReference)?.id];
    rslt["Church"] =
      churches[(p.data()["Church"] as firestore.DocumentReference)?.id];
    rslt["Confession Father"] =
      cfathers[(p.data()["CFather"] as firestore.DocumentReference)?.id];

    rslt["Last Tanawol"] =
      (p.data()["LastTanawol"] as Timestamp)?.toDate() ?? "";
    rslt["Last Confession"] =
      (p.data()["LastConfession"] as Timestamp)?.toDate() ?? "";
    rslt["Last Kodas"] = (p.data()["LastKodas"] as Timestamp)?.toDate() ?? "";
    rslt["Last Meeting"] =
      (p.data()["LastMeeting"] as Timestamp)?.toDate() ?? "";
    rslt["Last Call"] = (p.data()["LastCall"] as Timestamp)?.toDate() ?? "";
    rslt["Last Visit"] = (p.data()["LastVisit"] as Timestamp)?.toDate() ?? "";
    rslt["Last Edit"] = users[p.data()["LastEdit"]] ?? "";

    map[p.id] = rslt;
    return map;
  }, {});

  const book = utils.book_new();
  utils.book_append_sheet(
    book,
    utils.json_to_sheet(Object.values(classes)),
    "Classes"
  );
  utils.book_append_sheet(
    book,
    utils.json_to_sheet(Object.values(persons)),
    "Persons"
  );
  await writeFile(book, "/tmp/Export.xlsx");
  const file = (
    await storage()
      .bucket()
      .upload("/tmp/Export.xlsx", {
        destination: "Exports/Export-" + new Date().toISOString() + ".xlsx",
        gzip: true,
      })
  )[0];
  await file.setMetadata({ metadata: { createdBy: currentUser.uid } });
  return file.id;
});

export const importFromExcel = runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).https.onCall(async (data, context) => {
  if (!context.auth) throw new HttpsError("unauthenticated", "");

  const currentUser = await auth().getUser(context.auth.uid);
  if (!currentUser.customClaims?.approved || !currentUser.customClaims?.write) {
    throw new HttpsError(
      "permission-denied",
      'Must be approved user with "write" permission'
    );
  }

  assertNotEmpty("fileId", data?.fileId, typeof "");
  if (!(data.fileId as string).endsWith(".xlsx"))
    throw new HttpsError("invalid-argument", "Must be xlsx file");

  const file = storage()
    .bucket()
    .file("Imports/" + data.fileId);
  if (!(await file.exists()))
    throw new HttpsError("not-found", "File doesnot exist");
  if (
    (await file.getMetadata())[0]["metadata"]["createdBy"] !== context.auth.uid
  )
    throw new HttpsError("permission-denied", "");

  const _linkExpiry = new Date();
  _linkExpiry.setHours(_linkExpiry.getHours() + 1);
  await download(
    (
      await file.getSignedUrl({ action: "read", expires: _linkExpiry })
    )[0],
    "/tmp/",
    { filename: "import.xlsx" }
  );

  console.log(
    "Starting import operation from user: " +
      context.auth.uid +
      " for file " +
      data.fileId
  );

  const users = (await firestore().collection("Users").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const studyYears = (
    await firestore().collection("StudyYears").get()
  ).docs.reduce((map, obj) => {
    map[obj.data().Name] = obj.id ?? "(غير معروف)";
    return map;
  }, {} as Record<string, any>);
  const schools = (await firestore().collection("Schools").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const churches = (await firestore().collection("Churches").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const cfathers = (await firestore().collection("Fathers").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ?? "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );

  const book = readFile("/tmp/import.xlsx");
  if (!book.Sheets["Classes"] || !book.Sheets["Persons"])
    throw new HttpsError(
      "invalid-argument",
      "Workbook doesn't contain the required sheets"
    );
  const classes = utils
    .sheet_to_json(book.Sheets["Classes"])
    .reduce<Array<Record<string, string | Record<string, any>>>>(
      (arry, current) => {
        const c = current as Record<string, string | Record<string, any>>;

        const allowed = (c["Allowed Users"] as string)
          ?.split(",")
          .map((u) => users[u]) ?? [context.auth!.uid];
        if (!allowed.includes(context.auth!.uid))
          allowed.push(context.auth!.uid);

        const rslt: Record<string, any> = {};
        rslt["Name"] = c["Name"];
        rslt["Color"] = c["Color"];
        if (!studyYears[c["Study Year"] as string])
          throw new HttpsError(
            "invalid-argument",
            "Class " + c["Name"] + " doesnot have valid Study Year"
          );
        rslt["StudyYear"] = firestore()
          .collection("StudyYears")
          .doc(studyYears[c["Study Year"] as string]);
        rslt["Gender"] =
          c["Class Gender"] === "بنين"
            ? true
            : c["Class Gender"] === "بنات"
            ? false
            : null;
        rslt["LastEdit"] = users[c["Last Edit"] as string] ?? "";
        rslt["Allowed"] =
          currentUser.customClaims?.manageUsers ||
          currentUser.customClaims?.manageAllowedUsers
            ? allowed
            : [context.auth!.uid];

        arry.push({ ID: c["ID"], data: rslt });
        return arry;
      },
      []
    );
  const persons = utils
    .sheet_to_json(book.Sheets["Persons"])
    .reduce<Array<Record<string, string | Record<string, any>>>>(
      (arry, currentPerson) => {
        const rslt: Record<string, any> = {};
        const person: Record<string, any> = {};

        rslt["ClassId"] = firestore()
          .collection("Classes")
          .doc(person["ClassId"]);
        rslt["Name"] = person["Name"];
        rslt["Phone"] = person["Phone Number"];
        rslt["FatherPhone"] = person["Father Phone Number"];
        rslt["MotherPhone"] = person["Mother Phone Number"];
        rslt["Phones"] = {};

        rslt["Address"] = person["Address"];
        rslt["Color"] = person["Color"];
        if (person["Birth Date"] !== "" && person["Birth Date"]) {
          const _birthDay = dateFromExcelSerial(person["Birth Date"] as number);
          rslt["BirthDate"] = Timestamp.fromDate(_birthDay);
          _birthDay.setFullYear(1970);
          rslt["BirthDay"] = Timestamp.fromDate(_birthDay);
        } else {
          rslt["BirthDate"] = null;
          rslt["BirthDay"] = null;
        }

        function setTimestampProp(propName: string, mapPropName: string) {
          if (person[mapPropName] !== "" && person[mapPropName]) {
            rslt[propName] = Timestamp.fromDate(
              dateFromExcelSerial(person[mapPropName] as number)
            );
          } else {
            rslt[propName] = null;
          }
        }

        rslt["Notes"] = person["Notes"];
        rslt["Location"] = person["Location"]
          ? new firestore.GeoPoint(
              Number.parseFloat((person["Location"] as string).split(",")[1]),
              Number.parseFloat((person["Location"] as string).split(",")[0])
            )
          : null;
        rslt["School"] = firestore()
          .collection("Schools")
          .doc(schools[person["School"]] ?? "null");
        rslt["Church"] = firestore()
          .collection("Churches")
          .doc(churches[person["Church"]] ?? "null");
        rslt["CFather"] = firestore()
          .collection("Fathers")
          .doc(cfathers[person["Confession Father"]] ?? "null");

        setTimestampProp("LastTanawol", "Last Tanawol");
        setTimestampProp("LastConfession", "Last Confession");
        setTimestampProp("LastKodas", "Last Kodas");
        setTimestampProp("LastMeeting", "Last Meeting");
        setTimestampProp("LastCall", "Last Call");
        setTimestampProp("LastVisit", "Last Visit");
        rslt["LastEdit"] = users[person["Last Edit"]];

        //Remove all known fields and keep others as phone numbers
        Object.assign(rslt["Phones"], person);
        delete rslt["Phones"]["ID"];
        delete rslt["Phones"]["ClassId"];
        delete rslt["Phones"]["Class Name"];
        delete rslt["Phones"]["Name"];
        delete rslt["Phones"]["Phone Number"];
        delete rslt["Phones"]["Father Phone Number"];
        delete rslt["Phones"]["Mother Phone Number"];
        delete rslt["Phones"]["Phones"];
        delete rslt["Phones"]["Color"];
        delete rslt["Phones"]["Address"];
        delete rslt["Phones"]["Birth Date"];
        delete rslt["Phones"]["Notes"];
        delete rslt["Phones"]["Location"];
        delete rslt["Phones"]["School"];
        delete rslt["Phones"]["Church"];
        delete rslt["Phones"]["Confession Father"];
        delete rslt["Phones"]["Study Year"];
        delete rslt["Phones"]["Last Tanawol"];
        delete rslt["Phones"]["Last Confession"];
        delete rslt["Phones"]["Last Kodas"];
        delete rslt["Phones"]["Last Meeting"];
        delete rslt["Phones"]["Last Call"];
        delete rslt["Phones"]["Last Visit"];
        delete rslt["Phones"]["Last Edit"];

        for (const key in rslt["Phones"]) {
          rslt["Phones"][key] = `${rslt["Phones"][key]}`;
        }

        arry.push({ ID: person["ID"], data: rslt });
        return arry;
      },
      []
    );

  let batch = firestore().batch();
  let batchCount = 0;
  for (const item of classes) {
    if (batchCount % 500 === 0) {
      await batch.commit();
      batch = firestore().batch();
    }
    if (item["ID"] && item["ID"] !== "" && typeof item["ID"] === typeof "") {
      batch.set(
        firestore()
          .collection("Classes")
          .doc(item["ID"] as string),
        item["data"] as Object,
        { merge: true }
      );
    } else {
      batch.create(
        firestore().collection("Classes").doc(),
        item["data"] as Object
      );
    }
    batchCount++;
  }

  for (const item of persons) {
    if (batchCount % 500 === 0) {
      await batch.commit();
      batch = firestore().batch();
    }
    if (item["ID"] && item["ID"] !== "" && typeof item["ID"] === typeof "") {
      batch.set(
        firestore()
          .collection("Persons")
          .doc(item["ID"] as string),
        item["data"] as Object,
        { merge: true }
      );
    } else {
      batch.create(
        firestore().collection("Persons").doc(),
        item["data"] as Object
      );
    }
    batchCount++;
  }

  await batch.commit();
  return "OK";
});

function dateFromExcelSerial(param: number): Date {
  let date = param;
  if (date > 59) --date;
  return new Date(
    1970,
    1,
    date - 25568,
    0,
    0,
    Math.round(
      Math.ceil(date < 1.0 ? date : date % Math.floor(date)) * 24 * 60 * 60
    )
  );
}
