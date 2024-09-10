import { auth, messaging } from "firebase-admin";
import { pubsub } from "firebase-functions";
import { getFCMTokensForUser } from "./common";
import { firebaseDynamicLinksPrefix, packageName } from "./environment";

function getRiseDay(year?: number | undefined) {
  year ??= new Date().getFullYear();

  const a = year % 4;
  const b = year % 7;
  const c = year % 19;
  const d = (19 * c + 15) % 30;
  const e = (2 * a + 4 * b - d + 34) % 7;

  return new Date(
    year,
    Math.trunc((d + e + 114) / 31),
    Math.abs((d + e + 114) % 31) + 14
  );
}

// Gets computed only on deployment
const riseDay = getRiseDay();

export const sendNewYearMessage = pubsub
  .schedule("0 0 1 1 *")
  .timeZone("Africa/Cairo")
  .onRun(async () => {
    let usersToSend: string[] = [];

    usersToSend = await Promise.all(
      ((await auth().listUsers()).users as any).map(
        async (user: any) => await getFCMTokensForUser(user.uid)
      )
    );
    usersToSend = usersToSend
      .reduce<string[]>((accumulator, value) => accumulator.concat(value), [])
      .filter((v) => v !== null && v !== undefined);

    await messaging().sendEachForMulticast({
      tokens: usersToSend,
      android: {
        priority: "high",
        ttl: 7 * 24 * 60 * 60,
        restrictedPackageName: packageName,
      },
      notification: {
        title: "أسرة البرنامج تتمنى لكم سنة جديدة سعيدة 🎇",
        body: `أهنئكم ببدايه سنة جديدة. وأحب أن أقول لكم:
نريد أن تكون هذه السنة الجديدة، جديدة فى كل شئ.
جديدة فى الحياة، فى الأسلوب، فى السيرة، فى الطباع...
يشعر فيها كل منا، أن حياته قد تغيرت حقًا إلى أفضل. وكما قال الرسول "الأشياء العتيقة قد مضت. هوذا الكل قد صار جديدًا" (2كو5: 17).
نحن نريد أن نستغل هذا العام الجديد، لنعمل فيه عملًا لأجل الرب، ويعمل الرب فيه عملًا لأجلنا. ونقول فيه: 
كفى يارب علينا السنوات القديمة التى أكلها الجراد.
نريد أن نبدأ معك عهدًا جديدًا وحياه جديدة، نفرح بك وبسكناك فى قلوبنا، وتجدد مثل النسر شبابنا. فيهتف كل منا: إمنحنى بهجه خلاصك... قلبًا نقيًا أخلق فيّ يا الله. وروحًا مستقيمًا جدد فى أحشائى (مز50).

#البابا_شنوده_الثالث`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: "Happy New Year! 🎉🎇🎆",
        content: `أهنئكم ببدايه سنة جديدة. وأحب أن أقول لكم:
نريد أن تكون هذه السنة الجديدة، جديدة فى كل شئ.
جديدة فى الحياة، فى الأسلوب، فى السيرة، فى الطباع...
يشعر فيها كل منا، أن حياته قد تغيرت حقًا إلى أفضل. وكما قال الرسول "الأشياء العتيقة قد مضت. هوذا الكل قد صار جديدًا" (2كو5: 17).
نحن نريد أن نستغل هذا العام الجديد، لنعمل فيه عملًا لأجل الرب، ويعمل الرب فيه عملًا لأجلنا. ونقول فيه: 
كفى يارب علينا السنوات القديمة التى أكلها الجراد.
نريد أن نبدأ معك عهدًا جديدًا وحياه جديدة، نفرح بك وبسكناك فى قلوبنا، وتجدد مثل النسر شبابنا. فيهتف كل منا: إمنحنى بهجه خلاصك... قلبًا نقيًا أخلق فيّ يا الله. وروحًا مستقيمًا جدد فى أحشائى (مز50).

#البابا_شنوده_الثالث`,
        attachement:
          firebaseDynamicLinksPrefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FAL9nZEU1DeEE95ZnzsCRQwa3PomgPxbwwagYlAn3D7tvljE_IEaj6hVlYRLSATrmx3a-cI5ESaGCtn5CI00Q4NprAbAYaT5ujbKyfhM-ZkmJ-vfpiGa3XhGjf1LYp8UNwCMc54Qed3QIsLi0bXkvUxTunjh_%3Ds932-no",
        attachment:
          "https://lh3.googleusercontent.com/pw/AL9nZEU1DeEE95ZnzsCRQwa3PomgPxbwwagYlAn3D7tvljE_IEaj6hVlYRLSATrmx3a-cI5ESaGCtn5CI00Q4NprAbAYaT5ujbKyfhM-ZkmJ-vfpiGa3XhGjf1LYp8UNwCMc54Qed3QIsLi0bXkvUxTunjh_=s932-no",
        time: String(Date.now()),
        sentFrom: "",
      },
    });
    return "OK";
  });

export const sendMerryChristmasMessage = pubsub
  .schedule("0 0 7 1 *")
  .timeZone("Africa/Cairo")
  .onRun(async () => {
    let usersToSend: string[] = [];

    usersToSend = await Promise.all(
      ((await auth().listUsers()).users as any).map(
        async (user: any) => await getFCMTokensForUser(user.uid)
      )
    );
    usersToSend = usersToSend
      .reduce<string[]>((accumulator, value) => accumulator.concat(value), [])
      .filter((v) => v !== null && v !== undefined);

    await messaging().sendEachForMulticast({
      tokens: usersToSend,
      android: {
        priority: "high",
        ttl: 7 * 24 * 60 * 60,
        restrictedPackageName: packageName,
      },
      notification: {
        title: "أسرة البرنامج تتمنى لكم عيد ميلاد سعيد 🎅🎄🎉",
        body: `الله الذي حل في بطن العذراء لكي يأخذ منها جسدًا يريد أن يحل في أحشائك ليملأك حبًا
البابا شنودة الثالث

كل سنة وأنتم في ملئ النعمة والبركة
أبونا ملاك`,
        imageUrl:
          "https://lh3.googleusercontent.com/pw/ABLVV85jLjSC_gRlwhGCwIbO6OvvLGspmLUQxyOx2lXF0QORDoXE0IWr-_WsbbsyRNHgoO1oO7sdJfx0R8_RuiT7B5bzj5pXC4x3nZ6N0_ddvjiMtGjDUC1hs44zVSiSCqcSvoJsIsAch14Xnhdi0p9Nb-K3=w1607-h953-s-no?authuser=0",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: "Merry Christmas! 🎅🎄🎉",
        content: `الله الذي حل في بطن العذراء لكي يأخذ منها جسدًا يريد أن يحل في أحشائك ليملأك حبًا
البابا شنودة الثالث

كل سنة وأنتم في ملئ النعمة والبركة
أبونا ملاك`,
        attachement:
          firebaseDynamicLinksPrefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FABLVV85jLjSC_gRlwhGCwIbO6OvvLGspmLUQxyOx2lXF0QORDoXE0IWr-_WsbbsyRNHgoO1oO7sdJfx0R8_RuiT7B5bzj5pXC4x3nZ6N0_ddvjiMtGjDUC1hs44zVSiSCqcSvoJsIsAch14Xnhdi0p9Nb-K3%3Dw1607-h953-s-no%3Fauthuser%3D0",
        attachment:
          "https://lh3.googleusercontent.com/pw/ABLVV85jLjSC_gRlwhGCwIbO6OvvLGspmLUQxyOx2lXF0QORDoXE0IWr-_WsbbsyRNHgoO1oO7sdJfx0R8_RuiT7B5bzj5pXC4x3nZ6N0_ddvjiMtGjDUC1hs44zVSiSCqcSvoJsIsAch14Xnhdi0p9Nb-K3=w1607-h953-s-no?authuser=0",
        time: String(Date.now()),
        sentFrom: "",
      },
    });
    return "OK";
  });

export const sendHappyRiseMessage = pubsub
  .schedule(`0 0 ${riseDay.getMonth() + 1} ${riseDay.getDate()} *`)
  .timeZone("Africa/Cairo")
  .onRun(async () => {
    let usersToSend: string[] = [];

    usersToSend = await Promise.all(
      ((await auth().listUsers()).users as any).map(
        async (user: any) => await getFCMTokensForUser(user.uid)
      )
    );
    usersToSend = usersToSend
      .reduce<string[]>((accumulator, value) => accumulator.concat(value), [])
      .filter((v) => v !== null && v !== undefined);

    await messaging().sendEachForMulticast({
      tokens: usersToSend,
      android: {
        priority: "high",
        ttl: 7 * 24 * 60 * 60,
        restrictedPackageName: packageName,
      },
      notification: {
        title: "Ⲭⲣⲓⲥⲧⲟⲥ ⲁⲛⲉⲥⲧⲏ... Ⲁⲗⲏⲑⲱⲥ ⲁⲛⲉⲥⲧⲏ",
        body: "المسيح قام... بالحقيقة قام 🎉",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: "Ⲭⲣⲓⲥⲧⲟⲥ ⲁⲛⲉⲥⲧⲏ... Ⲁⲗⲏⲑⲱⲥ ⲁⲛⲉⲥⲧⲏ 🎉",
        content: "",
        attachement:
          firebaseDynamicLinksPrefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FAM-JKLVdRHoLrkCZmk83mp69ynZtVd7ZnpI29Y3k9djvoEi93NSI5olJTr14gH0YUcnE7A4AVK_CkHKk13jNJLDXUOH1m_vIP6UEaJWB3ztwdRnA6-hagTwbTTR2lClv9O094YYg4OBxPxrZnYDea-fBAo4L%3Dw1032-h688-no%3Fauthuser%3D0",
        time: String(Date.now()),
        sentFrom: "",
      },
    });
    return "OK";
  });
