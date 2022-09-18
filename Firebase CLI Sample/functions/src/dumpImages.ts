import * as archiver from "archiver";
import * as download from "download";
import { firestore, storage } from "firebase-admin";
import { runWith } from "firebase-functions";
import * as fs from "fs";
import { adminPassword, projectId } from "./environment";

export const dumpImages = runWith({
  memory: "8GB",
  timeoutSeconds: 540,
}).https.onCall(async (data) => {
  if (data.AdminPassword !== adminPassword) return null;

  const serviceId: string = data.serviceId;
  const classId: string = data.classId;
  const persons: Array<string> = data.persons;

  const dumpId =
    ((serviceId ?? classId) != null ? serviceId ?? classId : "dump") +
    "-" +
    new Date().toISOString().replace(/:/g, "-");

  const _linkExpiry = new Date();
  _linkExpiry.setHours(_linkExpiry.getHours() + 1);
  if (serviceId) {
    const ids = await firestore()
      .collection("Persons")
      .where(
        "Services",
        "array-contains",
        firestore().collection("Services").doc(serviceId.toString())
      )
      .get();
    for (const item of ids.docs) {
      if (!item.data()["HasPhoto"]) continue;
      console.log("Downloading " + item.id + ", Name: " + item.data()["Name"]);
      await download(
        (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + item.id)
            .getSignedUrl({ action: "read", expires: _linkExpiry })
        )[0],
        "/tmp/downloads/" + dumpId,
        { filename: item.id + ".jpg" }
      );
    }
  } else if (classId) {
    const ids = await firestore()
      .collection("Persons")
      .where(
        "ClassId",
        "==",
        firestore().collection("Classes").doc(classId.toString())
      )
      .get();
    for (const item of ids.docs) {
      if (!item.data()["HasPhoto"]) continue;
      console.log("Downloading " + item.id + ", Name: " + item.data()["Name"]);
      await download(
        (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + item.id)
            .getSignedUrl({ action: "read", expires: _linkExpiry })
        )[0],
        "/tmp/downloads/" + dumpId,
        { filename: item.id + ".jpg" }
      );
    }
  } else if (persons) {
    for (const item of persons) {
      console.log("Downloading " + item);
      await download(
        (
          await storage()
            .bucket("gs://" + projectId + ".appspot.com")
            .file("PersonsPhotos/" + item)
            .getSignedUrl({ action: "read", expires: _linkExpiry })
        )[0],
        "/tmp/downloads/" + dumpId,
        { filename: item + ".jpg" }
      );
    }
  }

  const fileName = dumpId + ".zip";
  const zipFilePath = "/tmp/" + fileName;
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
