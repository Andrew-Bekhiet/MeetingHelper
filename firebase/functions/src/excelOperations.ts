import { https, runWith } from "firebase-functions/v1";

import { Timestamp } from "@google-cloud/firestore";
import { auth, firestore, storage } from "firebase-admin";

import download from "download";
import { readFile, utils, writeFile } from "xlsx";

import { DateTime } from "luxon";
import { assertNotEmpty } from "./common";
import { projectId, supabaseClient } from "./environment";

export const exportToExcel = runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).https.onCall(async (data, context) => {
  if (context.auth === undefined) {
    throw new https.HttpsError("unauthenticated", "");
  }

  const currentUser = await auth().getUser(context.auth.uid);
  if (
    !(currentUser.customClaims?.approved && currentUser.customClaims?.export)
  ) {
    throw new https.HttpsError(
      "permission-denied",
      "Must be approved user with 'Export' permission"
    );
  }

  const userDocData = (
    await firestore()
      .collection("UsersData")
      .doc(currentUser.customClaims.personId)
      .get()
  ).data();

  let _class:
    | FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>
    | undefined;
  let _service:
    | FirebaseFirestore.DocumentSnapshot<FirebaseFirestore.DocumentData>
    | undefined;
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
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to export the required class"
        );
    }
  } else if (data?.onlyService) {
    assertNotEmpty("onlyService", data?.onlyService, typeof "");

    _service = await firestore()
      .collection("Services")
      .doc(data?.onlyService)
      .get();
    if (!currentUser.customClaims.superAccess) {
      if (
        !_service.exists ||
        !userDocData?.AdminServices?.includes(_service.ref)
      )
        throw new https.HttpsError(
          "permission-denied",
          "User doesn't have permission to export the required service"
        );
    }
  }

  console.log(
    "Starting export operation from user: " +
      context.auth.uid +
      " for " +
      (data?.onlyClass
        ? "class: " + data?.onlyClass
        : data?.onlyService
        ? "service: " + data?.onlyService
        : "all data avaliable for the user")
  );

  const { incompletePersonsData, services, classes } = await exportData({
    data,
    service: _service,
    class$: _class,
    currentUser,
    userDocData,
  });

  const persons = Object.fromEntries(
    await Promise.all(
      Object.entries(incompletePersonsData).map(async (p) => {
        const areas = (
          await supabaseClient?.rpc("person_areas_from_id", {
            person_id: p[0],
            hasura_session: `{"x-hasura-role":"admin"}${String("")}`,
          })
        )?.data;

        p[1]["Area"] = areas?.[0]?.name ?? "";
        return p;
      }, {})
    )
  );

  const book = utils.book_new();
  book.Workbook = {
    ...(book.Workbook ?? {}),
    Views: [{ RTL: true }, ...(book.Workbook?.Views ?? [])],
  };

  const servicesValues = Object.values(services);
  const classesValues = Object.values(classes);
  const personsValues = Object.values(persons);

  const servicesSheet = utils.json_to_sheet(servicesValues);
  const classesSheet = utils.json_to_sheet(classesValues);
  const personsSheet = utils.json_to_sheet(personsValues);

  //Adjust column widths
  if (servicesValues.length > 0) {
    servicesSheet["!cols"] = Object.keys(servicesValues[0]).map(
      (propertyName) => {
        const maxCharWidth =
          servicesValues.reduce(
            (max, current) =>
              Math.max(max, current[propertyName]?.length ?? -1),
            propertyName.length
          ) || undefined;

        return {
          DBF: {
            name: propertyName,
          },
          wch: maxCharWidth,
        };
      }
    );
  }

  if (classesValues.length > 0) {
    classesSheet["!cols"] = Object.keys(classesValues[0]).map(
      (propertyName) => {
        const maxCharWidth =
          classesValues.reduce(
            (max, current) =>
              Math.max(max, current[propertyName]?.length ?? -1),
            propertyName.length
          ) || undefined;

        return {
          DBF: {
            name: propertyName,
          },
          wch: maxCharWidth,
        };
      }
    );
  }

  if (personsValues.length > 0) {
    personsSheet["!cols"] = Object.keys(personsValues[0]).map(
      (propertyName) => {
        const maxCharWidth =
          personsValues.reduce(
            (max, current) =>
              Math.max(
                max,
                (typeof current[propertyName] === "string" ||
                typeof current[propertyName] === "number"
                  ? current[propertyName].toString()
                  : current[propertyName]?.toISOString().split("T")[0]
                )?.length ?? -1
              ),
            propertyName.length
          ) || undefined;

        return {
          DBF: {
            name: propertyName,
          },
          wch: maxCharWidth,
        };
      }
    );
  }

  utils.book_append_sheet(book, servicesSheet, "Services");
  utils.book_append_sheet(book, classesSheet, "Classes");
  utils.book_append_sheet(book, personsSheet, "Persons");

  await writeFile(book, "/tmp/Export.xlsx");
  const file = (
    await storage()
      .bucket("gs://" + projectId + ".appspot.com")
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
  if (!context.auth) throw new https.HttpsError("unauthenticated", "");

  const currentUser = await auth().getUser(context.auth.uid);
  if (!currentUser.customClaims?.approved || !currentUser.customClaims?.write) {
    throw new https.HttpsError(
      "permission-denied",
      "Must be approved user with 'write' permission"
    );
  }

  assertNotEmpty("fileId", data?.fileId, typeof "");
  if (!(data.fileId as string).endsWith(".xlsx"))
    throw new https.HttpsError("invalid-argument", "Must be xlsx file");

  const file = storage()
    .bucket("gs://" + projectId + ".appspot.com")
    .file("Imports/" + data.fileId);
  if (!(await file.exists()))
    throw new https.HttpsError("not-found", "File doesnot exist");
  if (
    (await file.getMetadata())[0]["metadata"]?.["createdBy"] !==
    context.auth.uid
  )
    throw new https.HttpsError("permission-denied", "");

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
      map[obj.data().Name] = obj.id ? obj.id : "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const studyYears = (
    await firestore().collection("StudyYears").get()
  ).docs.reduce((map, obj) => {
    map[obj.data().Name] = obj.id ? obj.id : "(غير معروف)";
    return map;
  }, {} as Record<string, any>);
  const schools = (await firestore().collection("Schools").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ? obj.id : "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const churches = (await firestore().collection("Churches").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ? obj.id : "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );
  const cfathers = (await firestore().collection("Fathers").get()).docs.reduce(
    (map, obj) => {
      map[obj.data().Name] = obj.id ? obj.id : "(غير معروف)";
      return map;
    },
    {} as Record<string, any>
  );

  const { classes, persons } = importExcelSheet({
    currentUser,
    filePath: "/tmp/import.xlsx",
    users,
    studyYears,
    schools,
    churches,
    cfathers,
  });

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
        item["data"] as Record<string, any>,
        { merge: true }
      );
    } else {
      batch.create(
        firestore().collection("Classes").doc(),
        item["data"] as Record<string, any>
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
        item["data"] as Record<string, any>,
        { merge: true }
      );
    } else {
      batch.create(
        firestore().collection("Persons").doc(),
        item["data"] as Record<string, any>
      );
    }
    batchCount++;
  }

  await batch.commit();
  return "OK";
});

export async function exportData({
  data,
  service,
  class$,
  currentUser,
  userDocData,
}: {
  data: any;
  service:
    | firestore.DocumentSnapshot<firestore.DocumentData, firestore.DocumentData>
    | undefined;
  class$:
    | firestore.DocumentSnapshot<firestore.DocumentData, firestore.DocumentData>
    | undefined;

  currentUser: auth.UserRecord;
  userDocData: firestore.DocumentData | undefined;
}) {
  const _service = service;
  const _class = class$;

  const users = (await firestore().collection("Users").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data()?.Name ? obj.data().Name : "(غير معروف)";

      return map;
    },
    {} as Record<string, string>
  );

  const studyYears = (
    await firestore().collection("StudyYears").get()
  ).docs.reduce((map, obj) => {
    map[obj.id] = obj.data()?.Name ? obj.data().Name : "(غير معروف)";
    return map;
  }, {} as Record<string, string>);
  const schools = (await firestore().collection("Schools").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data()?.Name ? obj.data().Name : "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );
  const churches = (await firestore().collection("Churches").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data()?.Name ? obj.data().Name : "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );
  const cfathers = (await firestore().collection("Fathers").get()).docs.reduce(
    (map, obj) => {
      map[obj.id] = obj.data()?.Name ? obj.data().Name : "(غير معروف)";
      return map;
    },
    {} as Record<string, string>
  );

  let classes: Record<string, Record<string, any>> = {};
  let services: Record<string, Record<string, any>> = {};

  if (data?.onlyService) {
    const _serviceData = _service!.data() ? _service!.data()! : {};

    const rslt: Record<string, string | Date> = {};

    rslt["Name"] = _serviceData["Name"];
    rslt["ID"] = _service!.id;
    rslt["Study Years: From"] =
      studyYears[
        (
          _serviceData["StudyYearRange"]?.[
            "From"
          ] as firestore.DocumentReference
        )?.id
      ];
    rslt["Study Years: To"] =
      studyYears[
        (
          _serviceData["StudyYearRange"]?.["To"] as firestore.DocumentReference
        )?.id
      ];
    rslt["Validity: From"] = (
      _serviceData["Validity"]?.["From"] as firestore.Timestamp
    )?.toDate();
    rslt["Validity: To"] = (
      _serviceData["Validity"]?.["To"] as firestore.Timestamp
    )?.toDate();

    rslt["Last Edit"] = users[_serviceData["LastEdit"]]
      ? users[_serviceData["LastEdit"]]
      : "";
    rslt["Show In History"] = _serviceData["ShowInHistory"];

    services[_service!.id] = rslt;
  } else if (data?.onlyClass) {
    const _classData = _class!.data() ?? {};

    const rslt: Record<string, string> = {};
    rslt["Name"] = _classData["Name"];
    rslt["ID"] = _class!.id;
    rslt["Color"] = formatColor(_classData["Color"]);
    rslt["Study Year"] =
      studyYears[(_classData["StudyYear"] as firestore.DocumentReference)?.id];
    rslt["Class Gender"] =
      _classData["Gender"] === true
        ? "بنين"
        : _classData["Gender"] === false
        ? "بنات"
        : "(غير معروف)";
    rslt["Last Edit"] = users[_classData["LastEdit"]]
      ? users[_classData["LastEdit"]]
      : "";
    rslt["Allowed Users"] =
      (_classData["Allowed"] as string[])
        ?.map((u) => (users[u] ? users[u] : "(غير معروف)"))
        ?.reduce((arr, o) => arr + "," + o, "") ?? "";
    classes[_class!.id] = rslt;
  } else {
    classes = (
      currentUser.customClaims?.superAccess
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
      rslt["Color"] = formatColor(c.data()["Color"]);
      rslt["Study Year"] =
        studyYears[(c.data()["StudyYear"] as firestore.DocumentReference)?.id];
      rslt["Class Gender"] =
        c.data()["Gender"] === true
          ? "بنين"
          : c.data()["Gender"] === false
          ? "بنات"
          : "(غير معروف)";
      rslt["Last Edit"] = users[c.data()["LastEdit"]]
        ? users[c.data()["LastEdit"]]
        : "";
      rslt["Allowed Users"] =
        (c.data()["Allowed"] as string[])
          ?.map((u) => (users[u] ? users[u] : "(غير معروف)"))
          ?.reduce((arr, o) => arr + "," + o, "") ?? "";

      map[c.id] = rslt;
      return map;
    }, {});

    services = (
      currentUser.customClaims?.superAccess
        ? (await firestore().collection("Services").orderBy("Name").get()).docs
        : await Promise.all(
            (
              userDocData?.AdminServices as Array<firestore.DocumentReference>
            )?.map(async (r) => await r.get()) ?? []
          )
    )?.reduce<Record<string, Record<string, any>>>((map, s) => {
      if (!s.exists) return map;

      const rslt: Record<string, string | Date> = {};

      rslt["Name"] = s.data()?.Name;
      rslt["ID"] = s.id;
      rslt["Study Years: From"] =
        studyYears[
          (s.data()?.StudyYearRange?.From as firestore.DocumentReference)?.id
        ];
      rslt["Study Years: To"] =
        studyYears[
          (s.data()?.StudyYearRange?.To as firestore.DocumentReference)?.id
        ];
      rslt["Validity: From"] = (
        s.data()?.Validity?.From as firestore.Timestamp
      )?.toDate();
      rslt["Validity: To"] = (
        s.data()?.Validity?.To as firestore.Timestamp
      )?.toDate();

      rslt["Last Edit"] = users[s.data()?.LastEdit]
        ? users[s.data()?.LastEdit]
        : "";
      rslt["Show In History"] = s.data()?.ShowInHistory;

      map[s.id] = rslt;
      return map;
    }, {});
  }

  const incompletePersonsData = (
    data?.onlyService
      ? (
          await Promise.all(
            split(Object.keys(services), 10).map(
              async (chunk) =>
                await firestore()
                  .collection("Persons")
                  .where(
                    "Services",
                    "array-contains-any",
                    chunk.map((a) => firestore().collection("Services").doc(a))
                  )
                  .orderBy("Name")
                  .get()
            )
          )
        ).reduce((ary, current) => {
          ary.push(...current.docs);
          return ary;
        }, new Array<firestore.DocumentData>())
      : data?.onlyClass
      ? (
          await firestore()
            .collection("Persons")
            .where("ClassId", "==", _class!.ref)
            .orderBy("Name")
            .get()
        ).docs
      : currentUser.customClaims?.superAccess
      ? (await firestore().collection("Persons").orderBy("Name").get()).docs
      : (
          await Promise.all(
            split(Object.keys(classes), 10).map(
              async (chunk) =>
                await firestore()
                  .collection("Persons")
                  .where(
                    "ClassId",
                    "in",
                    chunk.map((a) => firestore().collection("Classes").doc(a))
                  )
                  .orderBy("Name")
                  .get()
            )
          )
        ).reduce((ary, current) => {
          ary.push(...current.docs);
          return ary;
        }, new Array<firestore.DocumentData>())
  ).reduce<Record<string, Record<string, string | number | Date>>>((map, p) => {
    const personData = p.data() as Record<string, any>;
    const rslt: Record<string, string | number | Date> = {};

    rslt["ClassId"] = (
      personData["ClassId"] as firestore.DocumentReference
    )?.id;
    rslt["Participant In Services"] =
      (personData["Services"] as Array<firestore.DocumentReference>)

        ?.map((s) =>
          services[s.id]?.Name ? services[s.id].Name : "(غير معروف)"
        )
        ?.join(",") ?? "";
    rslt["Services"] = JSON.stringify(
      (personData["Services"] as Array<firestore.DocumentReference>)?.map(
        (s) => s.id
      )
    );

    rslt["Area"] = ""; //Will be filled later
    rslt["ID"] = p.id;
    rslt["Class Name"] = classes[
      (personData["ClassId"] as firestore.DocumentReference)?.id
    ]?.Name
      ? classes[(personData["ClassId"] as firestore.DocumentReference)?.id]
          ?.Name
      : "(غير موجود)";
    rslt["Name"] = personData["Name"];

    rslt["Color"] = formatColor(personData["Color"]);
    rslt["Phone Number"] = personData["Phone"];
    rslt["Father Phone Number"] = personData["FatherPhone"];
    rslt["Mother Phone Number"] = personData["MotherPhone"];
    Object.assign(rslt, personData["Phones"]);

    rslt["Address"] = personData["Address"];
    rslt["Location"] = personData["Location"]
      ? `${(personData["Location"] as firestore.GeoPoint).longitude},${
          (personData["Location"] as firestore.GeoPoint).latitude
        }`
      : "";

    rslt["Birth Date"] = personData["BirthDateString"]
      ? DateTime.fromISO(personData["BirthDateString"]).toFormat("d/M/yyyy")
      : (personData["BirthDate"] as Timestamp)?.toDate()
      ? toNearestDay((personData["BirthDate"] as Timestamp)?.toDate())
      : "";

    rslt["Study Year"] = classes[
      (personData["ClassId"] as firestore.DocumentReference)?.id
    ]
      ? classes[(personData["ClassId"] as firestore.DocumentReference)?.id][
          "Study Year"
        ]
      : "(غير موجود)";

    rslt["Notes"] = personData["Notes"];
    rslt["School"] =
      schools[(personData["School"] as firestore.DocumentReference)?.id];
    rslt["Church"] =
      churches[(personData["Church"] as firestore.DocumentReference)?.id];
    rslt["Confession Father"] =
      cfathers[(personData["CFather"] as firestore.DocumentReference)?.id];

    rslt["Last Tanawol"] = (personData["LastTanawol"] as Timestamp)?.toDate()
      ? toNearestDay((personData["LastTanawol"] as Timestamp)?.toDate())
      : "";
    rslt["Last Confession"] = (
      personData["LastConfession"] as Timestamp
    )?.toDate()
      ? toNearestDay((personData["LastConfession"] as Timestamp)?.toDate())
      : "";
    rslt["Last Kodas"] = (personData["LastKodas"] as Timestamp)?.toDate()
      ? toNearestDay((personData["LastKodas"] as Timestamp)?.toDate())
      : "";
    rslt["Last Meeting"] = (personData["LastMeeting"] as Timestamp)?.toDate()
      ? (personData["LastMeeting"] as Timestamp)?.toDate()
      : "";
    rslt["Last Call"] = (personData["LastCall"] as Timestamp)?.toDate()
      ? (personData["LastCall"] as Timestamp)?.toDate()
      : "";
    rslt["Last Visit"] = (personData["LastVisit"] as Timestamp)?.toDate()
      ? (personData["LastVisit"] as Timestamp)?.toDate()
      : "";
    rslt["Last Edit"] = users[personData["LastEdit"]]
      ? users[personData["LastEdit"]]
      : "";

    map[p.id] = rslt;
    return map;
  }, {});
  return { incompletePersonsData, services, classes };
}

export function importExcelSheet({
  currentUser,
  filePath,
  users,
  studyYears,
  schools,
  churches,
  cfathers,
}: {
  currentUser: auth.UserRecord;
  filePath: string;
  users: Record<string, any>;
  studyYears: Record<string, any>;
  schools: Record<string, any>;
  churches: Record<string, any>;
  cfathers: Record<string, any>;
}) {
  const book = readFile(filePath, {
    cellDates: true,
    dateNF: "dd/MM/yyyy",
  });
  if (!book.Sheets["Classes"] && !book.Sheets["Persons"])
    throw new https.HttpsError(
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
          ?.map((u) => users[u]) ?? [currentUser.uid];
        if (!allowed.includes(currentUser.uid)) allowed.push(currentUser.uid);

        const rslt: Record<string, any> = {};
        rslt["Name"] = c["Name"];
        rslt["Color"] = parseColor(c["Color"]);
        if (!studyYears[c["Study Year"] as string])
          throw new https.HttpsError(
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
        rslt["LastEdit"] = users[c["Last Edit"] as string]
          ? users[c["Last Edit"] as string]
          : "";
        rslt["Allowed"] =
          currentUser.customClaims?.manageUsers ||
          currentUser.customClaims?.manageAllowedUsers
            ? allowed
            : [currentUser.uid];

        arry.push({ ID: c["ID"], data: rslt });
        return arry;
      },
      []
    );
  const persons = utils
    .sheet_to_json(book.Sheets["Persons"])
    .reduce<Array<Record<string, string | number | Record<string, any>>>>(
      (arry, currentPerson) => {
        const rslt: Record<string, any> = {};
        const person = currentPerson as Record<
          string,
          string | number | Date | Record<string, any>
        >;

        console.log("Importing Person:", person);
        console.dir(person, { depth: null });

        const classId = classes.find(
          (c) => c["Name"] === person["Class Name"]
        )?.ID;

        if (classId && typeof classId === "string") {
          rslt["ClassId"] = firestore().collection("Classes").doc(classId);
        } else {
          rslt["ClassId"] = null;
        }

        rslt["Name"] = person["Name"] ?? "{بلا اسم}";
        rslt["Phone"] = person["Phone Number"]?.toString() ?? null;
        rslt["FatherPhone"] = person["Father Phone Number"]?.toString() ?? null;
        rslt["MotherPhone"] = person["Mother Phone Number"]?.toString() ?? null;
        rslt["Phones"] = {};
        rslt["Services"] =
          person["Services"] !== null &&
          person["Services"] !== undefined &&
          (JSON.parse(person["Services"] as string) as Array<string>).length > 0
            ? (JSON.parse(person["Services"] as string) as Array<string>).map(
                (v) => firestore().collection("Services").doc(v)
              )
            : [];

        rslt["Address"] = person["Address"] ?? "";
        rslt["Color"] = parseColor(person["Color"]) ?? 0;
        if (person["Birth Date"] !== "" && person["Birth Date"]) {
          const birthDate: Date =
            typeof person["Birth Date"] in ["number", "string"]
              ? dateFromExcelSerial(person["Birth Date"] as number | string)
              : (person["Birth Date"] as Date);

          const birthDateTime = toNearestLuxonDay(
            DateTime.fromJSDate(birthDate)
          );

          rslt["BirthDateString"] = birthDateTime.toISODate();
          rslt[
            "BirthDateMonthDay"
          ] = `${birthDateTime.month}-${birthDateTime.day}`;
          rslt["BirthDateMonth"] = birthDateTime.month;
        } else {
          rslt["BirthDateString"] = null;
          rslt["BirthDateMonthDay"] = null;
          rslt["BirthDateMonth"] = null;
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

        rslt["Notes"] = person["Notes"] ?? "";
        rslt["Location"] = person["Location"]
          ? new firestore.GeoPoint(
              Number.parseFloat((person["Location"] as string).split(",")[1]),
              Number.parseFloat((person["Location"] as string).split(",")[0])
            )
          : null;
        rslt["School"] =
          schools[person["School"] as string] != null &&
          schools[person["School"] as string] != ""
            ? firestore()
                .collection("Schools")
                .doc(schools[person["School"] as string])
            : null;
        rslt["Church"] =
          churches[person["Church"] as string] != null &&
          churches[person["Church"] as string] != ""
            ? firestore()
                .collection("Churches")
                .doc(churches[person["Church"] as string])
            : null;
        rslt["CFather"] =
          cfathers[person["Confession Father"] as string] != null &&
          cfathers[person["Confession Father"] as string] != ""
            ? firestore()
                .collection("Fathers")
                .doc(cfathers[person["Confession Father"] as string])
            : null;

        setTimestampProp("LastTanawol", "Last Tanawol");
        setTimestampProp("LastConfession", "Last Confession");
        setTimestampProp("LastKodas", "Last Kodas");
        setTimestampProp("LastMeeting", "Last Meeting");
        setTimestampProp("LastCall", "Last Call");
        setTimestampProp("LastVisit", "Last Visit");
        rslt["LastEdit"] = users[person["Last Edit"] as string] ?? null;

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
        delete rslt["Phones"]["Services"];
        delete rslt["Phones"]["Participant In Services"];

        for (const key in rslt["Phones"]) {
          rslt["Phones"][key] = `${rslt["Phones"][key]}`;
        }

        arry.push({ ID: person["ID"], data: rslt });
        return arry;
      },
      []
    );
  return { classes, persons };
}

function formatColor<T>(c: T): T | string {
  return typeof c === "number" ? "#" + (c as number).toString(16) : c;
}

function parseColor(c: any): number | null {
  let result;
  const color = typeof c === "string" ? c : c?.toString();

  if (color?.startsWith("#")) {
    result = Number.parseInt(color.replace("#", ""), 16);
  } else {
    result = Number.parseInt(color, 10);
  }

  return Number.isNaN(result) ? null : result;
}

function toNearestDay(date: Date): Date {
  date.setUTCDate(date.getUTCDate() + (date.getUTCDate() >= 12 ? 1 : 0));
  date.setUTCHours(6);
  date.setUTCMinutes(0);
  date.setUTCSeconds(0);
  date.setUTCMilliseconds(0);
  return date;
}

function dateFromExcelSerial(param: number | string | Date): Date {
  if (typeof param === "number") {
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
  } else if (typeof param === "string") {
    return new Date(param).toString() == "Invalid Date"
      ? new Date(
          param.split("/")[2] +
            "-" +
            param.split("/")[1] +
            "-" +
            param.split("/")[0]
        )
      : new Date(param);
  } else {
    return param;
  }
}

function split<T>(arry: Array<T>, length: number): Array<Array<T>> {
  const chunks: Array<Array<T>> = [];

  for (let i = 0; i < arry.length; i++) {
    chunks.push(
      arry.splice(i, i + length > arry.length ? arry.length : i + length)
    );
  }
  return chunks;
}

function toNearestLuxonDay(dateTime: DateTime): DateTime {
  if (dateTime.hour > 12) {
    return dateTime.startOf("day").plus({ days: 1 });
  } else {
    return dateTime.startOf("day");
  }
}
