import * as p from "./adminPassword";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as download from "download";

export const dumpImages = functions
  .runWith({ memory: "512MB", timeoutSeconds: 540 })
  .https.onCall(async (data) => {
    if (data.adminPassword !== p.adminPassword) return null;
    const classId: String = data.classId;
    const persons: Array<String> = data.persons;
    const _linkExpiry = new Date();
    _linkExpiry.setHours(_linkExpiry.getHours() + 1);
    if (classId) {
      const ids = await admin
        .firestore()
        .collection("Persons")
        .where(
          "ClassId",
          "==",
          admin.firestore().collection("Classes").doc(classId.toString())
        )
        .get();
      for (const item of ids.docs) {
        if (!item.data()["HasPhoto"]) continue;
        console.log(
          "Downloading " + item.id + ", Name: " + item.data()["Name"]
        );
        await download(
          (
            await admin
              .storage()
              .bucket()
              .file("PersonsPhotos/" + item.id)
              .getSignedUrl({ action: "read", expires: _linkExpiry })
          )[0],
          "/tmp/"
        );
      }
    } else if (persons) {
      for (const item of persons) {
        console.log("Downloading " + item);
        await download(
          (
            await admin
              .storage()
              .bucket()
              .file("PersonsPhotos/" + item)
              .getSignedUrl({ action: "read", expires: _linkExpiry })
          )[0],
          "/tmp/"
        );
      }
    }
    return null;
  });
