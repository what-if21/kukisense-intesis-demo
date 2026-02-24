# E-Ink Frame System Review & Integration Analysis

## 📋 Executive Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Flutter App** | ✅ Ready | BLE config, ThingsBoard API, clean UI |
| **ESP32 Firmware** | ✅ Ready | BLE GATT, WiFi, HTTP, EPD driver |
| **Integration** | ⚠️ Needs Review | JSON format mismatch risk |
| **Display Strategy** | ⚠️ Needs Improvement | Ghosting prevention incomplete |

---

## 1. Flutter App ↔ Firmware Integration Review

### ✅ What's Working Well

| Feature | App | Firmware | Match |
|---------|-----|----------|-------|
| BLE Service UUID | `0x00FF` | `0x00FF` | ✅ |
| BLE Char UUIDs | `0xFF01-0xFF07` | `0xFF01-0xFF07` | ✅ |
| Device Name | `EINK-Frame-Setup` | `EINK-Frame-Setup` | ✅ |
| Orientation | `landscape/portrait` | `0/1` | ✅ |
| Display Params | `co2,pm25,tvoc,temperature` | Same | ✅ |

### ⚠️ Potential Issues Found

#### Issue 1: JSON Config Format Mismatch
**Risk Level: HIGH**

**Flutter App sends:**
```json
{
  "wifi_ssid": "MyWiFi",
  "wifi_pass": "password123",
  "server_url": "https://dashboard.what-if.sg",
  "server_username": "user",
  "server_password": "pass",
  "frame_name": "Living Room",
  "device_id": "device_001",
  "orientation": "portrait",
  "display_params": ["co2", "pm25", "temperature", "tvoc"]
}
```

**Firmware expects:**
```c
// From main.c - parsing with simple string search
char *ssid_start = strstr(json, "\"wifi_ssid\"");
char *pass_start = strstr(json, "\"wifi_pass\"");
char *url_start = strstr(json, "\"server_url\"");
// ... etc
```

**Problem:** The firmware uses naive string parsing (`strstr` + manual char iteration) which:
- May fail with escaped characters
- No JSON validation
- Array format mismatch (`["co2","pm25"]` vs expected `"co2,pm25,temperature,tvoc"`)

**Recommendation:** 
- Use cJSON library in firmware (already available in ESP-IDF)
- Standardize on flat JSON format (no arrays for display_params)

#### Issue 2: Server Authentication
**Risk Level: MEDIUM**

**Current Flow:**
1. Flutter app logs into ThingsBoard (basic auth)
2. Gets device list via REST API
3. User selects device
4. Config sent to ESP32 via BLE

**Problem:** ESP32 firmware stores plaintext password in NVS
```c
char server_password[64];  // Stored as plain text
```

**Security Risk:** Physical access = credential exposure

**Recommendation:**
- Use ThingsBoard device tokens instead of user credentials
- Token scope limited to specific device
- Token can be revoked independently

#### Issue 3: WiFi Credential Security
**Risk Level: LOW**

BLE characteristics for WiFi SSID/Password are plaintext during transfer.

**Recommendation:**
- Acceptable for initial setup
- Document security warning
- Consider BLE bonding/encryption for production

---

## 2. E-Ink Display Refresh Strategy

### Current Implementation

```c
// From main.c - partial refresh logic
#define NUM_PARTIAL_REFRESH 10

static void update_iaq_display(void) {
    // Check each parameter for changes
    if (newCO2 != lastCO2) zonesNeedRefresh[ZONE_CO2] = true;
    if (newPM25 != lastPM25) zonesNeedRefresh[ZONE_PM25] = true;
    // ... etc
    
    static int partialCount = 0;
    if (++partialCount >= NUM_PARTIAL_REFRESH) {
        epd_full_refresh();  // Clean cycle
        partialCount = 0;
    } else {
        // Partial refresh changed zones only
        for (int z = 0; z < ZONE_COUNT; z++) {
            if (zonesNeedRefresh[z]) refreshZone(z);
        }
    }
}
```

### Problems with Current Approach

1. **Ghosting Accumulation:** 10 partials before full refresh may cause visible ghosting
2. **No Color Transition Handling:** Spectra 6 needs special handling for color changes
3. **Missing Clean Cycle:** No white/black flash cycle before image update
4. **Zone Overlap Risk:** Adjacent zones may leave artifacts

### Recommended Refresh Strategy

```c
// Improved refresh sequence for Spectra 6

typedef enum {
    REFRESH_FULL,           // Full clean cycle (ghosting reset)
    REFRESH_PARTIAL_FAST,   // Quick update (same color family)
    REFRESH_PARTIAL_COLOR,  // Standard partial (color change)
} refresh_type_t;

#define GHOSTING_THRESHOLD  5   // Full refresh every N updates
#define CLEAN_CYCLES        3   // White→Black→White flashes

void optimized_refresh(bool force_full) {
    static uint8_t update_count = 0;
    static uint32_t last_full_refresh = 0;
    uint32_t now = xTaskGetTickCount();
    
    // Force full refresh every 5 minutes or every GHOSTING_THRESHOLD updates
    bool need_full = force_full || 
                     (++update_count >= GHOSTING_THRESHOLD) ||
                     ((now - last_full_refresh) > pdMS_TO_TICKS(300000));
    
    if (need_full) {
        // Full clean cycle to eliminate ghosting
        epd_clean_cycle();           // Flash white/black/white
        epd_full_refresh();          // Complete redraw
        update_count = 0;
        last_full_refresh = now;
    } else {
        // Partial refresh with ghosting mitigation
        epd_partial_refresh_with_dither();
    }
}
```

### Spectra 6 Specific Considerations

| Aspect | Behavior | Strategy |
|--------|----------|----------|
| **Color transitions** | Slow (Yellow→Red faster than Black→White) | Group updates by color |
| **Ghosting** | Visible after 5-8 partials | Force full refresh every 5 updates |
| **Temperature** | Optimal at 20-25°C | Update more frequently in stable temps |
| **Border artifacts** | Common at zone edges | Add 2px overlap buffer |

---

## 3. IAQ Display Design Proposal

### Design Goals
1. **Readability:** Large values visible from 2-3 meters
2. **At-a-glance status:** Color-coded indicators
3. **Power efficiency:** Minimal refresh cycles
4. **Professional look:** Clean, modern aesthetic

### Proposed Layout: "Dashboard Cards"

```
┌─────────────────────────────────────────┐ 800x480
│                                         │
│  🏠 LIVING ROOM              ● WiFi  ●  │ 50px
│  ─────────────────────────────────────  │
│                                         │
│  ┌──────────────┐  ┌──────────────┐    │
│  │   🌬️ CO₂     │  │   🫁 PM2.5   │    │ 200px
│  │              │  │              │    │
│  │    850       │  │     12       │    │
│  │    ppm       │  │    μg/m³     │    │
│  │              │  │              │    │
│  │  [🟢 GOOD]   │  │  [🟡 MODERATE]│   │
│  └──────────────┘  └──────────────┘    │
│                                         │
│  ┌──────────────┐  ┌──────────────┐    │
│  │   🧪 TVOC    │  │   🌡️ TEMP    │    │ 150px
│  │              │  │              │    │
│  │    0.45      │  │    24.5      │    │
│  │   mg/m³      │  │     °C       │    │
│  │              │  │              │    │
│  │  [🟢 GOOD]   │  │  [🟢 GOOD]   │    │
│  └──────────────┘  └──────────────┘    │
│                                         │
│  ─────────────────────────────────────  │
│  🕐 14:32  │  Next: 14:37  │  ⚡ 85%   │ 40px
└─────────────────────────────────────────┘
```

### Color Coding (SS 554 + Spectra 6)

| Level | CO₂ (ppm) | PM2.5 (μg/m³) | TVOC (mg/m³) | Temp (°C) | Color |
|-------|-----------|---------------|--------------|-----------|-------|
| 🟢 **Good** | <800 | <35 | <0.3 | 22-26 | **Green** |
| 🟡 **Moderate** | 800-1000 | 35-55 | 0.3-0.5 | 20-22, 26-28 | **Yellow** |
| 🟠 **Unhealthy** | 1000-1500 | 55-150 | 0.5-1.0 | 18-20, 28-30 | **Orange** |
| 🔴 **Poor** | >1500 | >150 | >1.0 | <18, >30 | **Red** |

### Typography & Sizing

```c
// Proposed font sizes for 7.3" display
#define FONT_TITLE        24    // Location name
#define FONT_PARAM_NAME   20    // CO2, PM2.5 labels
#define FONT_VALUE        64    // Main numeric value (readable from 3m)
#define FONT_UNIT         16    // ppm, μg/m³
#define FONT_STATUS       18    // GOOD, MODERATE
#define FONT_FOOTER       14    // Timestamp
```

### Refresh Zones (Optimized)

```c
typedef struct {
    uint16_t x, y, w, h;
    uint8_t priority;        // Higher = refresh first
    uint32_t min_interval;   // Minimum seconds between refreshes
} zone_config_t;

zone_config_t zones[] = {
    // Header - static after init
    {0, 0, 480, 50, 0, 3600},
    
    // Main cards - update on value change
    {20, 60, 215, 180, 1, 30},   // CO2 (30s min)
    {245, 60, 215, 180, 1, 30},  // PM2.5
    {20, 260, 215, 140, 2, 120}, // TVOC (2min min - slower changing)
    {245, 260, 215, 140, 2, 120},// TEMP
    
    // Footer - every refresh cycle
    {0, 420, 480, 40, 3, 300},   // Timestamp (5min)
};
```

---

## 4. Implementation Recommendations

### Immediate Actions (Before First Use)

1. **Fix JSON parsing in firmware**
   ```bash
   # Add cJSON to CMakeLists.txt
   # Replace manual string parsing with cJSON_Parse()
   ```

2. **Reduce ghosting threshold**
   ```c
   # Change from 10 to 5
   #define NUM_PARTIAL_REFRESH 5
   ```

3. **Add clean cycle before full refresh**
   ```c
   void epd_clean_cycle() {
       epd_fill_color(COLOR_WHITE);
       epd_full_refresh();
       epd_fill_color(COLOR_BLACK);
       epd_full_refresh();
       epd_fill_color(COLOR_WHITE);
       epd_full_refresh();
   }
   ```

### Medium Term (Next Sprint)

1. **Switch to device tokens** instead of user credentials
2. **Implement adaptive refresh** (faster updates when values changing rapidly)
3. **Add battery level indicator** to footer
4. **Implement alert mode** (flash red when values exceed thresholds)

### Long Term (Production)

1. **Over-the-air (OTA) updates** for firmware
2. **Multiple display templates** selectable from app
3. **Historical graph view** (last 24h sparkline)
4. **Multi-language support**

---

## 5. Files & Locations

| Artifact | Path | Status |
|----------|------|--------|
| Flutter App | `eink_frame_app/` | ✅ Ready |
| ESP32 Firmware | `eink-frame-firmware-idf/` | ✅ Ready |
| Firmware Binary | `eink-frame-firmware-idf/build/eink_frame.bin` | ✅ Flashed |
| Linux Desktop App | `eink_frame_app/build/linux/x64/release/bundle/` | ✅ Built |
| Android APK | Building... | ⏳ In Progress |

---

*Review completed: 2026-02-12*
*Next: APK delivery + ghosting fix implementation*
