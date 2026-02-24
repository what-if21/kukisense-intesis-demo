# JSON Format Fix - Summary

## Problem
Flutter app was sending `display_params` as a JSON array:
```json
{
  "display_params": ["co2", "pm25", "temperature", "tvoc"]
}
```

But ESP32 firmware expected a comma-separated string:
```json
{
  "display_params": "co2,pm25,temperature,tvoc"
}
```

## Fix Applied

### Flutter App (lib/main.dart:1527)
**Before:**
```dart
'display_params': _selectedParams,
```

**After:**
```dart
'display_params': _selectedParams.join(','),  // Send as comma-separated string
```

## Result
Now both app and firmware use the same format:
```json
{
  "frame_name": "Living Room",
  "wifi_ssid": "MyWiFi",
  "wifi_pass": "password123",
  "server_url": "https://dashboard.what-if.sg",
  "server_username": "user",
  "server_password": "pass",
  "device_id": "device_001",
  "display_params": "co2,pm25,temperature,tvoc",
  "orientation": "portrait"
}
```

## APK File Location
```
/home/warren/eink_frame_app_v1.1.1.apk (49 MB)
```

Or rebuild from source:
```bash
cd /home/warren/.openclaw/workspace/eink_frame_app
flutter build apk --release
```

## Files Modified
- `eink_frame_app/lib/main.dart` - Line 1527
