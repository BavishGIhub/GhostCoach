# 👻 Ghost Coach - Vision AI Sports Analyzer

Ghost Coach is a state-of-the-art sports analysis tool powered by computer vision. Record your sports sessions, and let the Ghost Coach Vision AI evaluate your performance, tactical awareness, pace, and highlight your most critical key moments automatically. 

![Vision AI Preview](assets/logo/logo.png "Ghost Coach Logo")

## 🚀 Key Features

*   **🎮 Cross-Game Compatibility**: Profiles built for Soccer, Valorant, and custom motion-tracked exercises.
*   **🧠 Vision AI Capture**: Analyzes raw video directly on the backend using YOLOv8 tracking combined with Hugging Face's V-JEPA context evaluation to flag critical moments (e.g. Goals, Kills, Spikes).
*   **📉 Client-Side Compression**: Ultra-fast upload processing utilizing on-device 720p downsampling before fetching AI inference over cellular networks.
*   **📊 Tactical Radar & Storyboards**: Visual breakdowns of movement patterns and a swipeable frame-by-frame analysis of the "peak action" periods in your footage.
*   **🏆 Built-In Gamification**: Level up your profile, earn XP modifiers for high grades (A+ logic), and unlock streak-based rewards with an extensive offline SQLite tracking system.

## 📥 Download the App

You can find the latest compiled Android application package directly in the repositories `releases` folder.
*   👉 **[Download GhostCoachApp.apk](releases/GhostCoachApp.apk)**

## 🛠️ Tech Stack & Architecture

### Frontend (User App)
*   **Framework**: Flutter & Dart (Riverpod State Management)
*   **Storage**: Drift (Local SQLite) cache & offline capabilities
*   **UI/UX**: Extensive use of `GlassContainer` shaders, animated gradients, and staggered animations using `flutter_animate`. Fully customized Riverpod navigation utilizing `GoRouter`.

### Backend (Vision Pipeline)
*   **API Framework**: FastAPI
*   **Models**: YOLOv8 (Player/Target tracking) & Meta's V-JEPA 2 (Video Joint Embedding Predictive Architecture)
*   **Implementation**: Temporally-weighted peak finding algorithms deployed via an ephemeral Kaggle Cloud GPU cluster connected to the client app through Ngrok tunnels.

## 💻 Developer Setup

If you wish to spin up the source code natively instead of downloading the APK:

### 1. The Application (Flutter)
```bash
cd ghost_coach_app
flutter pub get
flutter run
```

### 2. The AI Backend (Kaggle / RunPod)
The backend pipeline requires GPU compute. To run the isolated server:
1. Copy the contents of `backend/kaggle_cells.py`
2. Follow the 3-Cell initialization instructions provided within the file inside a Kaggle notebook instance or RunPod environment.
3. Hook your generated `ngrok` URL into the Flutter application's settings!

---
*Developed with a focus on seamless design, low technical latency, and actionable AI athleticism insights.*
