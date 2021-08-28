import { initializeApp } from "firebase-admin";
import { config } from "dotenv";

initializeApp();
config();

export * from "./doBackupFirestoreData";
export * from "./dumpImages";
export * from "./excelOperations";
export * from "./firestore-triggers";
export * from "./auth-triggers";

export * from "./adminEndpoints";
export * from "./usersEndpoints";

/*
exports.recognizeFace = functions.https.onCall(async (data, context) => {
    const persons = (await admin.firestore().collection('Persons').get()).docs;

    const file = admin.storage().bucket().file(data.facePath);
    if (!(await file.exists())) throw new functions.https.HttpsError('invalid-argument', "facePath doesn't exist");

    const faces: faceapi.LabeledFaceDescriptors[] = [];
    for (const person of persons) {
        await admin.storage().bucket().file('PersonsPhotos/' + person.id).download({ destination: '/tmp/' + person.id + '.jpg' });
        faces.push(
            new faceapi.LabeledFaceDescriptors(person.data()['Name'],
                [
                    (await faceapi
                        .detectSingleFace((await faceapi.fetchImage('/tmp/' + person.id + '.jpg')))
                        .withFaceLandmarks()
                        .withFaceDescriptor()).descriptor,
                ]
            )
        );
        console.log('recognized ' + person.data()['Name']);
    }

    await file.download({ destination: '/tmp/face.jpg' });
    const requiredFace = await faceapi
        .detectSingleFace(await faceapi.fetchImage('/tmp/face.jpg'))
        .withFaceLandmarks()
        .withFaceDescriptor()

    if (!requiredFace) {
        throw new functions.https.HttpsError('failed-precondition', 'Input contains no faces');
    }

    const faceMatcher = new faceapi.FaceMatcher(faces)

    const bestMatch = faceMatcher.matchDescriptor(requiredFace.descriptor)
    console.log(bestMatch.tostring())
});
*/

// function isEqual(array: string | any[], array2: string | any[]) {
//     // if the other array is a falsy value, return
//     if (!array || !array2)
//         return false;

//     // compare lengths - can save a lot of time
//     if (array2.length !== array.length)
//         return false;

//     for (let i = 0, l = array2.length; i < l; i++) {
//         if (!array2.includes(array[i])) {
//             // Warning - two different object instances will never be equal: {x:20} !=={x:20}
//             return false;
//         }
//     }
//     return true;
// }
