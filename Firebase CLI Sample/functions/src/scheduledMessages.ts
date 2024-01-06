import { auth, messaging } from "firebase-admin";
// import { region } from "firebase-functions";
import { pubsub } from "firebase-functions";
import { getFCMTokensForUser } from "./common";
import { firebase_dynamic_links_prefix } from "./environment";

// const pubsub = region("europe-west1").pubsub;

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
        restrictedPackageName: "com.AndroidQuartz.etraf",
      },
      notification: {
        title: "Happy New Year! 🎉🎇🎆",
        body: "أسرة البرنامج تتمنى لكم سنة جديدة سعيدة 🎇",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: "Happy New Year! 🎉🎇🎆",
        content:
          "كُلُّ مَا أُرِيدُهُ يَا رَبِّ ، هُوَ أَنْ أَبْدَأَ مَعَكَ مِنْ جَدِيدٍ أُرِيدُ أَنْ إنْسِيّ مَا هُوَ وَرَاء ، وَامْتَدّ إلَيّ قُدَّام ( فَيُلَبِّي ۱۳ : ۳) . أُرِيدُ أَنْ أَبْدَأَ مَعَك بِدَايَة جَدِيدَة ، كَمَا بَدَأَت بِنِعْمَتِك مَعَ نُوحٍ ، بَعْدَ أَنْ أَزَلْت الْمَاضِي الْقَدِيم كُلُّه ، وَغُسِلَت الْأَرْضِ مِنْ أدناسها . . . هَذَا الْمَاضِيَ الْقَدِيم كُلُّه ، أَنَا مُتَنازِل عَنْه . يَكْفِي الْيَوْم شَرِّه (متی 6 : 34) . أَمَّا الْعَامُّ الْجَدِيد ، فَأُرِيدُ أَنْ أَبْدَاه بِالرَّجَاء . ( البابا شنودة الثالث)",
        attachement:
          firebase_dynamic_links_prefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FAM-JKLXY_vHy6n6dUGhmkryqL839BxvmOGykw_SI9libFSvjuWwTMYtgSWmK-fKUcp7S3j3ye3khtMgJQF4FIAabfErO8N8WsS5YPjHfOU3tZFoogoXGYlpwZwCN13L4SvKJiltRTh_ajrKhSv3nu5HcfdAK%3Dw1032-h689-no%3Fauthuser%3D0",
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
        restrictedPackageName: "com.AndroidQuartz.etraf",
      },
      notification: {
        title: "Merry Christmas! 🎅🎄🎉",
        body: "أسرة البرنامج تتمنى لكم عيد ميلاد سعيد 🎅🎄🎉",
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        type: "Message",
        title: "Merry Christmas! 🎅🎄🎉",
        content:
          "بينما كان يُرى طفل رضيع مقمطاً فى أحضان العذراء" +
          " التى ولدته؛ كان يملأ الخليقة كلها كإله وكجليس مع الآب الذى ولده؛" +
          "\n لأن اللاهوت غير خاضع للكم والقياس ولا تحده أى حدود؛" +
          " فهو صانع الدهور؛ الواحد" +
          " مع الآب فى الازلية و خالق الجميع \nالقديس كيرلس الكبير",
        attachement:
          firebase_dynamic_links_prefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FAM-JKLVdRHoLrkCZmk83mp69ynZtVd7ZnpI29Y3k9djvoEi93NSI5olJTr14gH0YUcnE7A4AVK_CkHKk13jNJLDXUOH1m_vIP6UEaJWB3ztwdRnA6-hagTwbTTR2lClv9O094YYg4OBxPxrZnYDea-fBAo4L%3Dw1032-h688-no%3Fauthuser%3D0",
        time: String(Date.now()),
        sentFrom: "",
      },
    });
    return "OK";
  });

export const sendHappyRiseMessage = pubsub
  .schedule("0 0 24 4 *")
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
        restrictedPackageName: "com.AndroidQuartz.etraf",
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
          firebase_dynamic_links_prefix +
          "/viewImage?url=https%3A%2F%2Flh3.googleusercontent.com%2Fpw%2FAM-JKLVdRHoLrkCZmk83mp69ynZtVd7ZnpI29Y3k9djvoEi93NSI5olJTr14gH0YUcnE7A4AVK_CkHKk13jNJLDXUOH1m_vIP6UEaJWB3ztwdRnA6-hagTwbTTR2lClv9O094YYg4OBxPxrZnYDea-fBAo4L%3Dw1032-h688-no%3Fauthuser%3D0",
        time: String(Date.now()),
        sentFrom: "",
      },
    });
    return "OK";
  });
