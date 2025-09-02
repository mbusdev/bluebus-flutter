# MaizeBus

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
