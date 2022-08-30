import * as download from "download";
import { firestore, storage } from "firebase-admin";
import { runWith } from "firebase-functions";
import { adminPassword, projectId } from "./adminPassword";

export const dumpImages = runWith({
  memory: "512MB",
  timeoutSeconds: 540,
}).https.onCall(async (data) => {
  if (data.AdminPassword !== adminPassword) return null;
  const serviceId: string = data.serviceId;
  const classId: string = data.classId;
  const persons: Array<string> = data.persons;

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
        "/tmp/"
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
        "/tmp/"
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
        "/tmp/"
      );
    }
  }
  return null;
});
