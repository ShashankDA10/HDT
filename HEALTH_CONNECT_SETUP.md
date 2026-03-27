# Health Connect Integration Setup

This app integrates with Health Connect to read vitals from Samsung Health, Galaxy Watch, and other health devices.

## Prerequisites

1. **Android Device** with Android 14+ (API 34+) or Health Connect app installed
2. **Health Connect App** - Install from [Google Play Store](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata)
3. **Samsung Health** or compatible health app syncing to Health Connect

## Setup Steps

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Android Configuration

The Android configuration has been set up with:
- **minSdkVersion**: 26 (required for Health Connect)
- **Permissions**: All necessary Health Connect permissions in AndroidManifest.xml
- **Queries**: Health Connect package queries configured

### 3. Build and Run

```bash
flutter run
```

## How It Works

1. **Galaxy Watch** → Syncs vitals to **Samsung Health**
2. **Samsung Health** → Syncs to **Health Connect**
3. **Your App** → Reads from **Health Connect**

### Supported Vitals

- ❤️ Heart Rate
- 🫁 Blood Oxygen (SpO₂)
- 🩸 Blood Pressure (if available in your region)
- 🌡️ Body Temperature
- 👣 Steps
- 🔥 Calories Burned
- 💤 Sleep Duration

## Usage

1. Open the app and navigate to **Vitals** screen
2. Grant permissions when prompted
3. The app will automatically fetch the latest vitals from Health Connect
4. Pull down to refresh and get the latest data

## Important Notes

- ⚠️ **Not Real-Time**: Data appears after your watch syncs to phone (usually within minutes)
- 📱 **Android Only**: Health Connect is Android-specific. iOS uses HealthKit (not yet implemented)
- 🔒 **Permissions**: You must grant Health Connect permissions for the app to read data
- 📊 **Data Source**: Data comes from whatever apps you've connected to Health Connect (Samsung Health, Google Fit, etc.)

## Troubleshooting

### "Health Connect Not Available"
- Install Health Connect from Google Play Store
- Ensure your device is running Android 14+ or has Health Connect installed

### "No Data Available"
- Ensure your Galaxy Watch is syncing to Samsung Health
- Check that Samsung Health is connected to Health Connect
- Sync your watch manually: Open Samsung Health → Settings → Sync

### "Permission Denied"
- Go to Settings → Apps → Health Connect → Permissions
- Grant permissions to your app
- Or re-open the app and grant permissions when prompted

## Technical Details

- **Plugin**: `health: ^13.2.1`
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: Latest
- **Permissions**: All Health Connect read permissions configured

