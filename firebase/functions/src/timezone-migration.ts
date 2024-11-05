import { firestore } from "firebase-admin";
import { Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";

function split<T>(arry: Array<T>, length: number): Array<Array<T>> {
  const chunks: Array<Array<T>> = [];

  for (let i = 0; i < arry.length; i++) {
    chunks.push(
      arry.splice(i, i + length > arry.length ? arry.length : i + length)
    );
  }
  return chunks;
}

export async function migrateDates() {
  const persons = await firestore()
    .collection("Persons")
    .where("BirthDate", "!=", null)
    .get();

  const updates = persons.docs.map((p) => {
    const birthDate = p.data()["BirthDate"]!.toDate()!;
    const birthDay = p.data()["BirthDay"]!.toDate()!;

    console.log("Scheduled update for ", p.id);
    console.dir({
      Name: p.data().Name,
      BirthDate: birthDate,
      BirthDay: birthDay,
    });

    return p.ref.update({
      BirthDate: toNearestDay(birthDate),
      BirthDay: toNearestDay(birthDay),
    });
  });

  // Split into batches of 500 then issue all updates in parallel
  const batches = split(
    updates.filter((u) => u != null && u != undefined),
    500
  );
  for (const batch of batches) {
    await Promise.all(batch);
  }

  console.log("Done");

  return "OK";
}

export async function migrateDates3() {
  const persons = await firestore()
    .collection("Persons")
    .where("BirthDate", "!=", null)
    .get();

  const updates = persons.docs.map((p) => {
    let birthDate: DateTime = DateTime.fromMillis(
      (p.data()["BirthDate"]! as Timestamp).toMillis()!
    ).setZone("Africa/Cairo");

    if (birthDate.hour > 12) {
      birthDate = birthDate.startOf("day").plus({ days: 1 });
    } else {
      birthDate = birthDate.startOf("day");
    }

    console.log("Scheduled update for ", p.id);
    console.dir({
      Name: p.data().Name,
      BirthDateString: birthDate.toISODate(),
      BirthDateMonthDay: `${birthDate.month}-${birthDate.day}`,
      BirthDateMonth: birthDate.month,
    });

    return p.ref.update({
      BirthDateString: birthDate.toISODate(),
      BirthDateMonthDay: `${birthDate.month}-${birthDate.day}`,
      BirthDateMonth: birthDate.month,
    });
  });

  // Split into batches of 500 then issue all updates in parallel
  const batches = split(
    updates.filter((u) => u != null && u != undefined),
    500
  );
  for (const batch of batches) {
    await Promise.all(batch);
  }

  console.log("Done");

  return "OK";
}

function toNearestDay(date: Date): Date {
  date.setUTCDate(date.getUTCDate() + (date.getUTCHours() >= 12 ? 1 : 0));
  date.setUTCHours(6);
  date.setUTCMinutes(0);
  date.setUTCSeconds(0);
  date.setUTCMilliseconds(0);
  return date;
}
