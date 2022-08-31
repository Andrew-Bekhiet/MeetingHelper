# Meeting Helper: Installing

## Clone the repo or download the code

## Create new Firebase project

- Go to <https://console.firebase.google.com/>
- Click "Add Project"
- Choose a project name
- Click continue
- Click continue
- Select a Google Analytics account
- Click "Create Project"
- Click continue

## Add Android Application

- Go to Project settings
- Click on Android icon
- Enter the package name (com.AndroidQuartz.meetinghelper)
- Add app nickname (MeetingHelper - Android)
- Don't download the google-services.json file now (will be downloaded later)
- Click Next
- Click Next
- Click Continue to console

## Enable Firebase services

### 1. Firebase Auth

- Go to Authentication
- Click Get Started
- Click on Google
- Enable Google sign in
- Enter the project public-facing name: (خدمة مدارس الأحد)
- Choose support email for the project
- Click Save

### 2. Firestore Database

- Go to Firestore Database
- Click Create database
- Click next
- Choose the project Firestore location: (europe-west6) or any other region that is close to your location
- Click Enable

### 3. Realtime Database

- Go to Realtime Database
- Click Create database
- Choose the database location: Belgium (europe-west1) or any other region that is close to your location
- Click Next
- Click Enable
- Add the following data to the database:

```jsonc
{
  "config": {
    "updates": {
      "latest_version": "8.2.5", //Fill in app latest version
      "deprecated_from": "7.1.9",
      "download_link": "", //Fill in download link
      "release_notes": "" //Fill in release notes link
    }
  }
}
```

### 4. Storage

- At this point Firebase Storage should be automatically enabled

#### Firestore backup bucket

- Go to <https://console.cloud.google.com/storage/browser>
- Create a new bucket with name "{projectId}-firestore-backup" (example: meetinghelper-cf3db-firestore-backup)
- Give 'Cloud Datastore Import Export Admin' permission to app engine defualt account
- Give 'Owner' or 'Storage Admin' permission for the same service account for the created bucket
   > For more info see [this](https://firebase.google.com/docs/firestore/solutions/schedule-export#configure_access_permissions)

### 5. Dynamic Links

- Go to Dynamic Links
- Click Get Started
- Enter domain name ("meetinghelperkeraza" for example) and from the dropdown menu choose the domain name ("meetinghelperkeraza.page.link")
- Click Finish
- Click on the 3 vertical dots next to "New dynamic link" and choose Allolist URL pattern
- Add each of the following Regexs:
  - ^https://meetinghelper\.com/view.+\?.+Id\=.+$
  - ^https://meetinghelper\.com/viewQuery\?collection\=((Services)|(Classes)|(Persons))\&fieldPath\=[^\&]+\&operator\=[^\&]\&queryValue(\=(((true)|(false))|((S|D|T|I)[^\&]+)))?\&order\=((true)|(false))\&orderBy\=[^\&]+\&descending\=(true|false)$
  - ^https://play\.google\.com/.\*id=com\.AndroidQuartz\.meetinghelper$
  - ^https://meetinghelper\.com/viewUser\?UID\=.+$
  - ^https://meetinghelper\.com/register\?InvitationId\=.+$
- Click Done
- Go to <https://console.cloud.google.com/apis/credentials>
- Click on Create Credentails and choose API Key
- Copy the key and click Restirct Key
- Rename the key to Firebase Dynamic Links API Key
- Choose restirct key under API Restirctions
- Search for and choose Firebase Dynamic Links API
- Click Save

### 6. Firebase Functions

#### To use Firebase Functions (which is an essential part in the project) you would have to enable billing in the project

### 8. Google Maps API

- Go to <https://console.cloud.google.com/google/maps-apis/new>
- Choose and Enable Maps SDK for Android
- Go to <https://console.cloud.google.com/apis/credentials>
- Click on Create Credentails and choose API Key
- Copy the key and click Restirct Key
- Rename the key to GMaps Android API Key
- Choose restirct key under API Restirctions
- Search for and choose Maps SDK for Android
- Click Save
- Create file in `android\app\src\main\res\values\` and name it `strings.xml`
- Paste in the following snippet replacing Your-Key with the API key:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="gmaps_api_key">Your-Key</string>
</resources>
```

### 10. Sentry

- Go to sentry.io and create an account
- Create new project, choose flutter and give it a name (for example "meetinghelper-keraza")
- Copy the dsn and save it for later use

### 11. Deploying the project

#### Password Encryption

- Create file `Firebase CLI Sample\functions\src\passwordEncryption.ts`
- Paste the following snippet and implement some passowrd encryption Algorithm:

```ts
export function encryptPassword(rawPassword: string): string {
  //TODO: implement password encryption algorithm, same as front-end
  return rawPassword.split("").reverse().join("");
}
```

#### Environment variables

- Create file `Firebase CLI Sample\functions\.env` and add environment variables

```env
FB_DYNAMIC_LINKS_KEY=<the key you created and copied from the project credentails>
FB_DYNAMIC_LINKS_PREFIX=<https://meetinghelper.page.link>
ADMIN_PASSWORD=p^s$word
PACKAGE_NAME=com.AndroidQuartz.meetinghelper
```

- Fill the values that are surrounded by <> without <>
- Edit the ADMIN_PASSWORD to a strong one
- Edit PACKAGE_NAME if package name is different

#### Setting CORS policy

- Install gsutil from the link <https://cloud.google.com/storage/docs/gsutil_install>
- Create a new file with name: `cors.json` with the following code replacing `projectId` with your actual projectId:

```json
[
  {
    "origin": [
      "https://projectId.firebaseapp.com",
      "https://projectId.web.app"
    ],
    "responseHeader": ["Content-Type"],
    "method": ["GET", "HEAD"],
    "maxAgeSeconds": 3600
  }
]
```

- Run the command `gsutil cors set cors.json gs://projectId.appspot.com` replacing projectId with your actual projectId

#### Deploying rtdb, firestore, fuctions, and storage

- Install Firebase tools using `npm install -g firebase-tools`
- Using the terminal go to the `Firebase CLI Sample` directory
- Run the command: `firebase init`
- Select: Realtime Database, Firestore, Functions and Storage
- Choose an ccount or login if prompted
- Choose Use an existing project
- Choose the project you created earlier
- Choose NOT to overwrite current configuration
- When prompted for functions choose TypeScript
- Choose no: Do you want to use ESLint to catch probable bugs and enforce style?
- After the command finishes run `firebase deploy`

### 12. Flutter part

- Create file in `lib\utils` and name it `encryption_keys.dart`
- Paste the following snippet and implement some passowrd encryption Algorithm:

```dart
class Encryption {
  static String encryptPassword(String rawPassword) {
    //TODO: implement password encryption algorithm, same as back-end
    return rawPassword.split('').reversed.join();
  }
}

```

- Create file in the root directory and name it `secrets.dart`
- Paste the following snippet replacing Your-Sentry-DSN with actual DSN:

```dart
const sentryDSN = 'Your-Sentry-DSN';
```

- Create file in the root directory and name it `.env`
- Paste in the following code:

```env
kUseFirebaseEmulators=false
```

### 13. Android part

#### Signatures

##### Creating keys

- Using Terminal go to `android\app`
- Run the following command `keytool -genkey -v -keystore dKey.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias debug`
- Enter the debug keystore password and save it for later use
- Enter your info
- Run the command `keytool -importkeystore -srckeystore dKey.jks -destkeystore dKey.jks -deststoretype pkcs12` then enter the password
- Run the following command `keytool -genkey -v -keystore rKey.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias release`
- Enter the release keystore password and save it for later use
- Enter your info
- Run the command `keytool -importkeystore -srckeystore rKey.jks -destkeystore rKey.jks -deststoretype pkcs12` then enter the password
- Rename `dKey.jks` to `dKey.keystore` and `rKey.jks` to `rKey.keystore`

##### Creating keys configurations

- Go to `android\` and create two files `debugKey.properties` and `releaseKey.properties`
- Paste the following in debugKey.properties replacing Debug-Password with your password:

```properties
storePassword=Debug-Password
keyPassword=Debug-Password
keyAlias=debug
storeFile=dKey.keystore
```

- Paste the following in releaseKey.properties replacing Release-Password with your password:

```properties
storePassword=Release-Password
keyPassword=Release-Password
keyAlias=release
storeFile=rKey.keystore
```

##### Restirecting API using signatures

- Using the Terminal go to `android\app`
- Run the following command `keytool -list -v -keystore dKey.keystore -alias debug`
- Copy the SHA1 and SHA256 hashes
- Run the following command `keytool -list -v -keystore rKey.keystore -alias release`
- Copy the SHA1 and SHA256 hashes
- Go to <https://console.cloud.google.com/apis/credentials>
- Open the GMaps API Key and under applications restirections choose android apps
- Click on add an item
- Enter the package name and SHA1 hash for the debug key
- Click Done
- Click on add an item
- Enter the package name and SHA1 hash for the release key
- Click Done
- Click Save
- Repeat these steps on the Android Key (auto created by Firebase)

#### Firebase App Check (optional)

> **Note: Firebase App Check is still in Beta support in Flutter**:

- Go to Firebase App Check -> Apps
- You should find the Android app, click on it
- Expand Play Integrity, check the app signatures and accept the TOS then click save
- Expand Safety Net, check the app signatures and accept the TOS then click save
- Now you can go to APIs tab and enforce the APIs you want

#### Google services

- Go to <https://console.firebase.google.com/>
- Choose the project
- Go to project settings
- Under Android apps and under SHA certificate fingerprints click Add fingerprint
- Add each of SHA1 and SHA256 of each of the debug and release keys
- Download `google-services.json` and copy it to `android/app`
