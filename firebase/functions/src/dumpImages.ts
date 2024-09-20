import archiver from "archiver";
import { auth, firestore, storage } from "firebase-admin";
import { runWith } from "firebase-functions";
import { HttpsError } from "firebase-functions/v1/https";
import fs from "fs";
import { projectId } from "./environment";

export const dumpImages = runWith({
  memory: "8GB",
  timeoutSeconds: 540,
}).https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "unauthenticated");
  }

  const currentUser = await auth().getUser(context.auth.uid);
  if (currentUser.customClaims?.dumpImages !== true) {
    throw new HttpsError("permission-denied", "permission-denied");
  }

  try {
    const serviceId: string = data.serviceId;
    const classId: string = data.classId;
    const persons: Array<string> = data.persons;

    const dumpId =
      ((serviceId ?? classId) != null ? serviceId ?? classId : "dump") +
      "-" +
      new Date().toISOString().replace(/:|\./g, "");

    const _linkExpiry = new Date();
    _linkExpiry.setHours(_linkExpiry.getHours() + 1);

    fs.mkdirSync(`/tmp/downloads/${dumpId}`, { recursive: true });

    if (serviceId) {
      if (currentUser.customClaims?.superAccess !== true) {
        const serviceRef = firestore().collection("Services").doc(serviceId);
        const adminServices = (
          await firestore()
            .doc(`UsersData/${currentUser.customClaims!.personId}`)
            .get()
        ).data()?.AdminServices;

        if (!adminServices.includes(serviceRef)) {
          throw new HttpsError(
            "permission-denied",
            "User doesn't have permission to export the required service"
          );
        }
      }

      const ids = await firestore()
        .collection("Persons")
        .where(
          "Services",
          "array-contains",
          firestore().collection("Services").doc(serviceId.toString())
        )
        .get();
      for (const item of ids.docs) {
        const file = storage()
          .bucket("gs://" + projectId + ".appspot.com")
          .file("PersonsPhotos/" + item.id);

        if (!(await file.exists())[0]) continue;

        const name = item.data()["Name"];

        console.log("Downloading " + item.id + ", Name: " + name);

        await file.download({
          destination: `/tmp/downloads/${dumpId}/${item.id}.jpg`,
        });
      }
    } else if (classId) {
      if (currentUser.customClaims?.superAccess !== true) {
        const classRef = firestore().collection("Classes").doc(classId);

        if (
          !(await classRef.get()).data()?.Allowed.includes(context.auth.uid)
        ) {
          throw new HttpsError(
            "permission-denied",
            "User doesn't have permission to export the required class"
          );
        }
      }

      const ids = await firestore()
        .collection("Persons")
        .where(
          "ClassId",
          "==",
          firestore().collection("Classes").doc(classId.toString())
        )
        .get();
      for (const item of ids.docs) {
        const file = storage()
          .bucket("gs://" + projectId + ".appspot.com")
          .file("PersonsPhotos/" + item.id);

        if (!(await file.exists())[0]) continue;

        const name = item.data()["Name"];

        console.log("Downloading " + item.id + ", Name: " + name);

        await file.download(
          {
            destination: `/tmp/downloads/${dumpId}/${item.id}.jpg`,
          },
          (e) => {
            console.dir(e);
          }
        );
      }
    } else if (persons) {
      if (currentUser.customClaims?.superAccess !== true) {
        throw new HttpsError(
          "permission-denied",
          "User doesn't have permission to export the required persons"
        );
      }

      for (const item of persons) {
        const file = storage()
          .bucket("gs://" + projectId + ".appspot.com")
          .file("PersonsPhotos/" + item);

        if (!(await file.exists())[0]) continue;

        console.log("Downloading " + item);
        await file.download({
          destination: `/tmp/downloads/${dumpId}/${item}.jpg`,
        });
      }
    }

    const fileName = `${dumpId}.zip`;
    const zipFilePath = `/tmp/${fileName}`;
    await zipDirectory("/tmp/downloads/" + dumpId, zipFilePath);

    console.log("uploading ...");
    await storage()
      .bucket("gs://" + projectId + ".appspot.com")
      .upload(zipFilePath, {
        destination: "ImagesDumps/" + fileName,
        gzip: true,
        contentType: "application/zip",
      });

    console.log("getting url ...");

    return (
      await storage()
        .bucket("gs://" + projectId + ".appspot.com")
        .file("ImagesDumps/" + fileName)
        .getSignedUrl({ action: "read", expires: _linkExpiry })
    )[0];
  } catch (error) {
    console.error(error);
    throw error;
  }
});

export async function zipDirectory(
  sourceDir: string,
  outPath: string
): Promise<void> {
  const archive = archiver("zip", { zlib: { level: 9 } });
  const output = fs.createWriteStream(outPath);

  output.on("close", function () {
    console.log(archive.pointer() + " total bytes");
    console.log(
      "archiver has been finalized and the output file descriptor has closed."
    );
  });

  output.on("end", function () {
    console.log("Data has been drained");
  });

  // good practice to catch warnings (ie stat failures and other non-blocking errors)
  archive.on("warning", function (err) {
    if (err.code === "ENOENT") {
      // log warning
    } else {
      // throw error
      throw err;
    }
  });

  // good practice to catch this error explicitly
  archive.on("error", function (err) {
    throw err;
  });

  // pipe archive data to the file
  archive.pipe(output);
  archive.directory(sourceDir, false);
  archive.on("error", (err) => {
    throw err;
  });

  return await archive.finalize();
}
