# BGCTUB Companion 🎓

**The Ultimate Campus Companion for BGC Trust University.**

This is a high-performance, offline-first mobile application designed to streamline campus life for students and teachers. Built with Flutter and powered by Firebase, it provides real-time updates for class routines, university notices, and academic resources.

## ✨ Key Features
* **Smart Routine System:** Offline-access to class schedules with automatic background syncing.
* **Instant Notices:** Real-time push notifications for university announcements with targeted filtering (Semester/Section).
* **Developer Panel:** A hidden administrative suite for managing the routine database and system insights.
* **Zero-Cost Lifecycle:** Integrated auto-update system utilizing the GitHub REST API for version management.
* **Premium UI:** Elegant "Blue" aesthetic with full responsive scaling for all device sizes.

## 🛠 Tech Stack
* **Framework:** [Flutter](https://flutter.dev) (v3.x)
* **State Management:** [Riverpod](https://riverpod.dev)
* **Local Database:** [Drift (SQLite)](https://drift.simonbinder.eu/)
* **Backend:** [Firebase](https://firebase.google.com/) (Auth, Firestore, Cloud Messaging)
* **Network:** [Dio](https://pub.dev/packages/dio)

## 🚀 Getting Started

### Prerequisites
* Flutter SDK installed.
* A Firebase project.

### Installation & Security
Note: For security reasons, sensitive configuration files (`google-services.json`, `firebase_options.dart`) are excluded via `.gitignore`.

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/shatattya/my-uni-app.git](https://github.com/shatattya/my-uni-app.git)
    cd my-uni-app
    ```
2.  **Configure Firebase:**
    * Use the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli/) to re-generate `lib/firebase_options.dart`.
    * Place your `google-services.json` in `android/app/`.
3.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Run the app:**
    ```bash
    flutter run
    ```

## 🛡 Security & Distribution
This app uses **Dart Code Obfuscation** for production builds to prevent reverse engineering. To build a secure release:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols

