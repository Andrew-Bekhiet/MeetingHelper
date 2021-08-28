import { adminPassword } from "./adminPassword";
import { runWith } from "firebase-functions";
import { firestore, storage } from "firebase-admin";
import * as download from "download";

export const dumpImages = runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).https.onCall(async (data) => {
  if (data.AdminPassword !== adminPassword) return null;
  const classId: String = data.classId;
  const persons: Array<String> = data.persons;
  const _linkExpiry = new Date();
  _linkExpiry.setHours(_linkExpiry.getHours() + 1);
  if (classId) {
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
          await storage()
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
