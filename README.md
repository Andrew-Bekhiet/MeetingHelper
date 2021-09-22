## Clone the repo or download the code

## Create new Firebase project:

- Go to https://console.firebase.google.com/
- Click "Add Project"
- Choose a project name
- Click continue
- Click continue
- Select a Google Analytics account
- Click "Create Project"
- Click continue

## Add Android Application:

- Go to Project settings
- Click on Android icon
- Enter the package name (com.AndroidQuartz.meetinghelper)
- Add app nickname (MeetingHelper - Android)
- Don't download the google-services.json file now (will be downloaded later)
- Click Next
- Click Next
- Click Continue to console

## Enable Firebase services:

### 1. Firebase Auth:

- Go to Authentication
- Click Get Started
- Click on Google
- Enable Google sign in
- Enter the project public-facing name: (خدمة مدارس الأحد)
- Choose support email for the project
- Click Save

### 2. Firestore Database:

- Go to Firestore Database
- Click Create database
- Click next
- Choose the project Firestore location: (europe-west6) or any other region that is close to your location
- Click Enable

### 3. Realtime Database:

- Go to Realtime Database
- Click Create database
- Choose the database location: Belgium (europe-west1) or any other region that is close to your location
- Click Next
- Click Enable

### 4. Storage:

- At this point Firebase Storage should be automatically enabled

### 5. Remote Config:

- Go to Remote Config
- Click Create configuration
- Add a key and name it "LoadApp" and give it a default value of false
- Click Add new -> Conditional Value -> Create new condition
- Name it "Android version check"
- Choose from "Applies if..." -> App
- Select the android app
- Click "and"
- Select "Version"
- Select operator: >=
- Select versions
- Enter "6.0.0" in search additional options
- Click "Create value 6.0.0
- Click "Create condition"
- In the value field under the "Android version check" condition, type true
- Click Save
- Click add parameter
- Name the parameter "DownloadLink" and leave it empty for now
  > This would be used if a new version is available
- Click save
- Click add parameter
- Name the parameter "LatestVersion" and give it a value of "6.0.0"
- Click save
- Click Publish Changes
- Click Publish Changes

### 6. Dynamic Links:

- Go to Dynamic Links
- Click Get Started
- Enter domain name ("meetinghelperkeraza" for example) and from the dropdown menu choose the domain name ("meetinghelperkeraza.page.link")
- Click Finish
- Click on the 3 vertical dots next to "New dynamic link" and choose Allolist URL pattern
- Add each of the following Regexs:
  - ^https://meetinghelper\.com/view.+\?.+Id\=.+$
  - ^https:\/\/meetinghelper\.com\/viewQuery\?collection\=((Services)|(Classes)|(Persons))\&fieldPath\=[^\&]+\&operator\=((%3D)|(%21%3D)|(%3E)|(%3C))\&queryValue(\=(((true)|(false))|((S|D|T|I)[^\&]+)))?\&order\=((true)|(false))\&orderBy\=[^\&]+\&descending\=(true|false)$
  - ^https://play\.google\.com/.\*id=com\.AndroidQuartz\.meetinghelper$
  - ^https://meetinghelper\.com/viewUser\?UID\=.+$
  - ^https://meetinghelper\.com/register\?InvitationId\=.+$
- Click Done
- Go to https://console.cloud.google.com/apis/credentials
- Click on Create Credentails and choose API Key
- Copy the key and click Restirct Key
- Rename the key to Firebase Dynamic Links API Key
- Choose restirct key under API Restirctions
- Search for and choose Firebase Dynamic Links API
- Click Save

### 7. Firebase Functions:

#### To use Firebase Functions (which is an essential part in the project) you would have to enable billing in the project

### 8. Google Maps API:

- Go to https://console.cloud.google.com/google/maps-apis/new
- Choose and Enable Maps SDK for Android
- Go to https://console.cloud.google.com/apis/credentials
- Click on Create Credentails and choose API Key
- Copy the key and click Restirct Key
- Rename the key to GMaps Android API Key
- Choose restirct key under API Restirctions
- Search for and choose Maps SDK for Android
- Click Save
- Create file in `android\app\src\main\res\values\` and name it `strings.xml`
- Paste in the following snippet replacing Your-Key with the API key:

```
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="gmaps_api_key">Your-Key</string>
</resources>
```

### 9. Sentry:

- Go to sentry.io and create an account
- Create new project, choose flutter and give it a name (for example "meetinghelper-keraza")
- Copy the dsn and save it for later use

### 10. Deploying the project:

- Edit `Firebase CLI Sample\functions\src\adminPassword.ts` and change adminPassword
- Edit firebase_dynamick_links_key to the key you created and copied from the project credentails
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

### 11. Flutter part:

- Create file in `lib\utils` and name it `encryption_keys.dart`
- Paste the following snippet and implement some passowrd encryption Algorithm:

```
class Encryption {
  static String encPswd(String q) {
    //TODO: Encrypt and return encrypted password
  }
}

```

- Create file in the root directory and name it `secrets.dart`
- Paste the following snippet replacing Your-Sentry-DSN with actual DSN:

```
const sentryDSN = 'Your-Sentry-DSN';
```

- Create file in the root directory and name it `.env`
- Paste in the following code:

```
kUseFirebaseEmulators=false
```

### 10. Android part:

#### Signatures:

##### Creating keys:

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

##### Creating keys configurations:

- Go to `android\` and create two files `debugKey.properties` and `releaseKey.properties`
- Paste the following in debugKey.properties replacing Debug-Password with your password:

```
storePassword=Debug-Password
keyPassword=Debug-Password
keyAlias=debug
storeFile=dKey.keystore
```

- Paste the following in releaseKey.properties replacing Release-Password with your password:

```
storePassword=Release-Password
keyPassword=Release-Password
keyAlias=release
storeFile=rKey.keystore
```

##### Restirecting API using signatures:

- Using the Terminal go to `android\app`
- Run the following command `keytool -list -v -keystore dKey.keystore -alias debug`
- Copy the SHA1 and SHA256 hashes
- Run the following command `keytool -list -v -keystore rKey.keystore -alias release`
- Copy the SHA1 and SHA256 hashes
- Go to https://console.cloud.google.com/apis/credentials
- Open the GMaps API Key and under applications restirections choose android apps
- Click on add an item
- Enter the package name and SHA1 hash for the debug key
- Click Done
- Click on add an item
- Enter the package name and SHA1 hash for the release key
- Click Done
- Click Save
- Repeat these steps on the Android Key (auto created by Firebase)

#### Google services:

- Go to https://console.firebase.google.com/
- Choose the project
- Go to project settings
- Under Android apps and under SHA certificate fingerprints click Add fingerprint
- Add each of SHA1 and SHA256 of each of the debug and release keys
- Download `google-services.json` and copy it to `android/app`
