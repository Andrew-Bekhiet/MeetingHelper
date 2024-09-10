import { auth, firestore, storage } from "firebase-admin";
import { projectId } from "./environment";

export async function restoreDeletedPhotos() {
  const deleted = await storage()
    .bucket("gs://" + projectId + ".appspot.com")
    .getFiles({ prefix: "Deleted" });

  const promises = [];

  for (const item of deleted[0]) {
    console.log("Iterating on:" + item.name);
    const path = item.name.split("/").slice(2).join("/");

    promises.push(
      firestore()
        .doc(
          path.split("/")[0].replace("Photos", "") + "/" + path.split("/")[1]
        )
        .get()
        .then(async (v) => {
          if (v.exists) {
            console.log(item.name + " exists with the Name: " + v.data()?.Name);

            await item.move(path);

            console.log(item.name + " was moved to " + path);

            if (!v.data()?.HasPhoto) {
              v.ref.set({ HasPhoto: true }, { merge: true });

              console.log(item.name + " was updated to have a photo");
            }
          } else {
            console.log(item.name + " doesn't exist");
          }
        })
    );

    await Promise.all(promises);
    console.log("done");
  }
}

export async function migrateToV8Beta() {
  const { users } = await auth().listUsers();
  const promises = [];

  for (const user of users) {
    promises.push(
      auth().setCustomUserClaims(user.uid, {
        ...user.customClaims,
        recordHistory: user.customClaims?.write === true,
      })
    );
  }

  await Promise.all(promises);
}
