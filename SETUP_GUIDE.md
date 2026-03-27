# BodyClone - Setup & Testing Guide

## 🚀 Quick Start

### 1. Backend Setup (Python Flask)

```bash
cd bodyclone/bodyclone/backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows PowerShell:
.\venv\Scripts\Activate.ps1
# Windows CMD:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the backend server
python app.py
```

The backend will run on `http://localhost:5000`

### 2. Frontend Setup (Flutter)

```bash
cd bodyclone/bodyclone

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

**Note:** For physical devices or emulators, you may need to update the API URL in `lib/services/health_api_service.dart`:
- Android Emulator: `http://10.0.2.2:5000`
- iOS Simulator: `http://localhost:5000`
- Physical Device: `http://YOUR_COMPUTER_IP:5000` (e.g., `http://192.168.1.100:5000`)

### 3. Running on macOS

If the Flutter app does not run or render on macOS:

1. **Add the macOS platform** (if the `macos/` folder is missing):
   ```bash
   cd bodyclone/bodyclone
   flutter create --platforms=macos .
   ```

2. **Run the app on macOS**:
   ```bash
   flutter run -d macos
   ```

3. **Health / Vitals on macOS**: The `health` package only supports **iOS and Android**. On macOS the app runs normally, but the **Vitals** screen will show “Health Connect is available on Android devices” (and iOS uses HealthKit). All other screens (Reports, Medication, Consult, Avatar) work on macOS.

## 📱 App Flow

1. **Splash Screen** - Shows logo and "enter your virtual world" button
2. **Avatar Screen** - Main screen with:
   - Avatar in center (half screen)
   - 4 health metric icons positioned around avatar:
     - ❤️ **Vitals** (Top) - Heart rate, blood pressure, temperature, oxygen
     - 📄 **Reports** (Right) - Medical reports and test results
     - 💊 **Medication** (Bottom) - Current medications and schedule
     - 🏥 **Consult** (Left) - Upcoming consultations

## 🎯 Features Implemented

### Backend API Endpoints:
- `GET /` - Health check
- `GET /api/health` - API status
- `GET /api/vitals` - Get vital signs
- `GET /api/reports` - Get medical reports
- `GET /api/medication` - Get medication schedule
- `GET /api/consultations` - Get consultations
- `GET /api/health/summary` - Get complete health summary
- `GET /api/avatar/mood` - Get avatar mood state
- `POST /api/avatar/mood` - Update avatar mood

### Frontend Features:
- ✅ Navigation from splash to avatar screen
- ✅ Avatar with pulsing animation
- ✅ Health metric icons positioned around avatar
- ✅ Tap icons to view detailed health data
- ✅ Avatar mood changes based on selected metric
- ✅ Beautiful dark theme UI
- ✅ Modal bottom sheets for health data details

## 🧪 Testing

### Test Backend:
```bash
# Test health check
curl http://localhost:5000/

# Test health summary
curl http://localhost:5000/api/health/summary

# Test vitals
curl http://localhost:5000/api/vitals
```

### Test Frontend:
1. Start backend server
2. Run Flutter app
3. Click "enter your virtual world" button
4. Tap health metric icons to see details
5. Avatar color changes based on selected metric

## 📁 Project Structure

```
bodyclone/
├── backend/
│   ├── app.py              # Flask API server
│   └── requirements.txt    # Python dependencies
├── lib/
│   ├── main.dart           # App entry point
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   └── avatar_screen.dart
│   ├── services/
│   │   └── health_api_service.dart
│   ├── models/
│   │   └── health_data.dart
│   └── widgets/
│       ├── digital_twin_logo.dart
│       └── particle_background.dart
└── pubspec.yaml            # Flutter dependencies
```

## 🔧 Troubleshooting

### Backend not connecting?
- Make sure backend is running on port 5000
- Check firewall settings
- For physical devices, use your computer's IP address instead of localhost

### Flutter dependencies error?
```bash
flutter clean
flutter pub get
```

### Avatar not showing?
- Check if backend is running
- App will use mock data if backend is unavailable (for testing)

### App not rendering on macOS?
- Ensure the macOS platform is added: run `flutter create --platforms=macos .` from the Flutter project root (`bodyclone/bodyclone`). The repo may not include the `macos/` folder.
- The **health** plugin (Health Connect / HealthKit) only supports iOS and Android; the app is configured to skip it on macOS so the rest of the UI still renders. If you see a blank or crashed window, ensure you have the latest code and the `macos/` folder from the step above.

## 🎨 Customization

### Change Avatar Appearance:
Edit `lib/screens/avatar_screen.dart` - `_getMoodColors()` method to change colors

### Add More Health Metrics:
1. Add endpoint in `backend/app.py`
2. Add model in `lib/models/health_data.dart`
3. Add icon in `lib/screens/avatar_screen.dart`

### Change API URL:
Edit `lib/services/health_api_service.dart` - `baseUrl` constant

