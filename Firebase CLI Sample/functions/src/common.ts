import { https, Change } from "firebase-functions";
import { database } from "firebase-admin";

export async function getFCMTokensForUser(
  uid: string
): Promise<string[] | string> {
  const token = (
    await database()
      .ref("Users/" + uid + "/FCM_Tokens")
      .once("value")
  ).val();
  if (token === null || token === undefined) return [];
  console.log(token);
  console.log(Object.getOwnPropertyNames(token));
  return Object.getOwnPropertyNames(token);
}

export function assertNotEmpty(
  varName: string,
  variable: string,
  typeDef: string
) {
  if (
    variable === null ||
    variable === undefined ||
    typeof variable !== typeDef
  )
    throw new https.HttpsError(
      "invalid-argument",
      varName + " cannot be null or undefined and must be " + typeDef
    );
}

export function getChangeType(
  change: Change<FirebaseFirestore.DocumentSnapshot>
): "create" | "update" | "delete" {
  const before: boolean = change.before.exists;
  const after: boolean = change.after.exists;

  if (before === false && after === true) {
    return "create";
  } else if (before === true && after === true) {
    return "update";
  } else if (before === true && after === false) {
    return "delete";
  } else {
    throw new Error(
      `Unkown firestore event! before: '${before}', after: '${after}'`
    );
  }
}
