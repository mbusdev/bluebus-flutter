<img width="2000" height="546" alt="github_header" src="https://github.com/user-attachments/assets/e13b6768-53cf-4f8b-ab09-de9aa86805fe" />

# Quickstart (Recommended)
## Create an API key for Google Maps 
**Keep your API key secret!** Your Google Maps API key is just for your local build of Maizebus (we'll use a different one when publishing to the app store). Our GitHub repository is configured to ignore `android/local.properties` and `ios/Flutter/gmap.xcconfig` so you're safe to commit as usual.

You have two options for getting your API key: either use a Maps Demo Key or get an API key through Google Cloud. The Maps Demo key doesn't require a credit card but is newer and might have stricter usage limits. Google Cloud requires you to have a credit card on file, but our usage stays in the free tier (we're using the "Maps SDK", which has [unlimited free usage](https://developers.google.com/maps/billing-and-pricing/pricing#map-loads-pricing)). I would recommend getting your API key from Google Cloud since it's more stable.

1. Option A: Use a Maps Demo Key (no credit card required)
   1. Visit the [Maps Demo Key page](https://mapsplatform.google.com/maps-demo-key/?utm_experiment=13103221)
   2. Click "Try for free" and sign in with your Google Account
   3. Agree to the terms, and you should see your Maps Demo Key!
2. Option B: Create an API key through Google Cloud
   1. Open the [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/overview). Create an account if you don't already have one
   2. In the toolbar you should see the Project Picker (right next to "Google Cloud"). Click it and create a new project. Call it whatever you like (such as "Local-Maizebus-Testing")
   3. In the sidebar, click "APIs & Services" and enable "Maps SDK for Android" and "Maps SDK for iOS"
   4. Now click on "Keys & Credentials" in the sidebar
   5. Click on the "Maps Platform API Key" under "API Keys", then click "Show key"

## Run automatic setup
1. Make sure Flutter is installed on your computer (see [this guide](https://docs.flutter.dev/install) for how to do this)
2. Open a terminal (Mac) or WSL terminal (Windows) in the project folder. Run `./setup.sh` to start the setup process
3. Paste your Google Maps API key into the setup script when prompted. The setup script will add your API key to the project
4. Launch an emulator and click the green Run button in VSCode to build and run the project! Alternatively you can run `flutter run` in your terminal

**Note:** `setup.sh` disables Firebase by default and creates dummy configuration files. Most frontend developers probably won't work on the notification system, so we're saving you all the pain of having to get a Firebase API key and configure flutterfire. If you'd like to configure Firebase properly, see the section below.


# Manual Setup

## Google Maps Setup (iOS)

1. **Create the API key config file:**
   - Create a file at `ios/Flutter/gmap.xcconfig`
   - Add your key:
     ```
     GMapApiKey=YOUR_IOS_GOOGLE_MAPS_API_KEY
     ```

## Google Maps Setup (Android)

1. **Create the API key config file:**
   - Create or edit the file at `android/local.properties`
   - Add your key:
     ```
     GOOGLE_MAPS_API_KEY="_yourkeyhere_"
     ```

## **(WIP)** Firebase Setup (used for push notifications)

1. Create a Firebase project
2. Follow <https://firebase.google.com/docs/flutter/setup>
3. (iOS) Do this <https://firebase.google.com/docs/cloud-messaging/get-started?platform=flutter#upload-authentication-key>

## Running the App (IOS)

1. **Launch the iOS Simulator:**
     ```
     open -a Simulator
     ```

2. **Run the App**
   ```
   flutter pub get
   flutter run
   ```

## Running the App With Backend (iOS)

### 1. Set Up the Backend

```sh
git clone git@github.com:mbusdev/mbus-backend-dev.git
cd mbus-backend-dev
git checkout graph-data-endpoint
```

- Set up your MBus API key as required by the backend instructions.
- Start the local backend server (refer to backend README for details).

---

### 2. Launch the iOS Simulator

```sh
open -a Simulator
```

---

### 3. Run the App with the Local Backend

```sh
flutter run --dart-define=BACKEND_URL=http://localhost:3000/mbus/api/v3
```

---

## Running the App With Backend (Android Simulator)

The process is similar to iOS, but instead of defining the backend url with localhost, use `10.0.2.2`.
