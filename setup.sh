#!/bin/bash
set -Eeuo pipefail

BLACK="\e[30m";
RED="\033[31m";
GREEN="\033[32m";
YELLOW="\033[33m";
BLUE="\033[34m";
MAGENTA="\033[35m";
CYAN="\033[36m";
WHITE="\033[37m";
RESET="\033[0m";

if flutter --version; then
    echo "Found Flutter installation!"
else
    echo "Error: Could not find Flutter"
    exit 1
fi

flutter doctor

echo "Please paste in your Google Maps API key: "

while read -r -t 0.01 -n 10000 _discard; do :; done # Eat all the old input entered before the following read command
read gmaps_apikey

touch ios/Flutter/gmap.xcconfig
sed -E 's/^GMapApiKey=([A-Za-z0-9]+)//' ios/Flutter/gmap.xcconfig # Remove all old API keys from gmap.xcconfig
echo "GMapApiKey=$gmaps_apikey" > ios/Flutter/gmap.xcconfig # Add API key to gmap.xcconfig
touch android/local.properties
grep -v '^GOOGLE_MAPS_API_KEY=' android/local.properties > android/local.properties.tmp || true # Remove all old API keys from local.properties
mv android/local.properties.tmp android/local.properties
printf "\nGOOGLE_MAPS_API_KEY=$gmaps_apikey" >> android/local.properties # Add API key to local.properties

flutter pub get

if [ ! -f lib/firebase_options.dart ]; then
touch lib/firebase_options.dart
> lib/firebase_options.dart # Clear the file
cat > lib/firebase_options.dart << 'EOF'
// Dummy Firebase config file. WILL NOT CONNECT TO FIREBASE OR RECEIVE NOTIFICATIONS
// To set the app up to use Firebase notifications, follow this tutorial: https://firebase.google.com/docs/flutter/setup
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// If you're seeing a compile error here, you're making a release build with the
// dummy Firebase config. Set up the real one: https://firebase.google.com/docs/flutter/setup
// ignore: unused_element
const _noReleaseWithDummyFirebase = 1 ~/ (bool.fromEnvironment('dart.vm.product') ? 0 : 1);


/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    throw UnsupportedError("Firebase hasn't been configured for this project! Please delete firebase_options.dart and follow the tutorial at https://firebase.google.com/docs/flutter/setup");
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'dummy-api-key',
    appId: 'dummy-app-id',
    messagingSenderId: 'dummy-sender-id',
    projectId: 'dummy-project-id',
    storageBucket: 'dummy-project-id.appspot.com',
  );
}
EOF
else
    printf "${YELLOW}Note: lib/firebase_options.dart already exists and was not overwritten $RESET\n"
    printf "    If you'd like to replace firebase_options.dart with the dummy version,\n"
    printf "    remove it and run this script again\n"
fi

if [ ! -f android/app/google-services.json ]; then
cat > android/app/google-services.json << 'EOF'
{
"project_info": {
    "project_number": "000000000000",
    "project_id": "dummy-project-id",
    "storage_bucket": "dummy-project-id.appspot.com"
},
"client": [
    {
    "client_info": {
        "mobilesdk_app_id": "1:000000000000:android:0000000000000000000000",
        "android_client_info": {
        "package_name": "com.ishankumar.maizebus"
        }
    },
    "oauth_client": [],
    "api_key": [{ "current_key": "dummy-api-key" }],
    "services": { "appinvite_service": { "other_platform_oauth_client": [] } }
    }
],
"configuration_version": "1"
}
EOF
else
    printf "${YELLOW}Note: android/app/google-services.json already exists and was not overwritten$RESET\n"
    printf "    If you'd like to replace google-services.json with the dummy version,\n"
    printf "    remove it and run this script again\n"
fi

# npm i -g firebase-tools # Install Firebase tools


# dart pub global activate flutterfire_cli

