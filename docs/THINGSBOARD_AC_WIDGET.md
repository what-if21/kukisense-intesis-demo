# ThingsBoard Intesis AC Control Widget Setup

## 1. Create AC Control Widget

### Step 1: Import Widget Bundle

Create a new widget bundle or add to existing dashboard:

```json
{
  "name": "Intesis AC Control",
  "type": "rpc",
  "sizeX": 8,
  "sizeY": 6,
  "row": 0,
  "col": 0,
  "config": {
    "title": "AC Control",
    "showTitle": true,
    "dropShadow": true,
    "enableFullscreen": true,
    "enableDataExport": false,
    "widgetStyle": {},
    "useDashboardTimewindow": false,
    "displayTimewindow": false,
    "showLegend": false,
    "actions": {}
  }
}
```

### Step 2: Widget HTML/JS

**HTML Template:**
```html
<div class="ac-control-widget">
  <div class="ac-header">
    <div class="ac-status">
      <span class="online-indicator" ng-class="{'online': telemetry.ac_online}"></span>
      <span class="device-name">Intesis AC</span>
    </div>
    <md-switch ng-model="ctx.values.ac_power" ng-change="sendCommand('power', ctx.values.ac_power)" 
               aria-label="Power" class="power-switch">
      {{ ctx.values.ac_power ? 'ON' : 'OFF' }}
    </md-switch>
  </div>
  
  <div class="ac-content" ng-if="ctx.values.ac_power">
    <div class="mode-selector">
      <button ng-repeat="mode in ['COOL', 'HEAT', 'DRY', 'FAN', 'AUTO']"
              ng-class="{'active': ctx.values.ac_mode === mode}"
              ng-click="sendCommand('mode', mode)">
        {{ mode }}
      </button>
    </div>
    
    <div class="temp-control">
      <button class="temp-btn" ng-click="adjustTemp(-0.5)">-</button>
      <div class="temp-display">
        <span class="setpoint">{{ ctx.values.ac_setpoint }}°C</span>
        <span class="room-temp">Room: {{ ctx.values.ac_room_temp }}°C</span>
      </div>
      <button class="temp-btn" ng-click="adjustTemp(0.5)">+</button>
    </div>
    
    <div class="fan-control">
      <span>Fan Speed:</span>
      <select ng-model="ctx.values.ac_fan" ng-change="sendCommand('fan', ctx.values.ac_fan)">
        <option value="LOW">Low</option>
        <option value="MEDIUM">Medium</option>
        <option value="HIGH">High</option>
        <option value="AUTO">Auto</option>
      </select>
    </div>
  </div>
  
  <div class="ac-offline" ng-if="!ctx.values.ac_online">
    <span class="offline-message">AC Gateway Offline</span>
  </div>
</div>
```

**CSS:**
```css
.ac-control-widget {
  padding: 16px;
  background: #1e1e1e;
  border-radius: 8px;
  color: white;
  font-family: 'Roboto', sans-serif;
}

.ac-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.online-indicator {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #ff4444;
  display: inline-block;
  margin-right: 8px;
}

.online-indicator.online {
  background: #00c853;
}

.power-switch .md-bar {
  background-color: #444;
}

.power-switch .md-thumb {
  background-color: #fff;
}

.power-switch.md-checked .md-bar {
  background-color: #00bcd4;
}

.mode-selector {
  display: flex;
  gap: 8px;
  margin-bottom: 20px;
}

.mode-selector button {
  flex: 1;
  padding: 12px;
  background: #333;
  border: none;
  border-radius: 4px;
  color: #aaa;
  cursor: pointer;
  transition: all 0.3s;
}

.mode-selector button.active {
  background: #00bcd4;
  color: black;
}

.temp-control {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 20px;
  margin-bottom: 20px;
}

.temp-btn {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #00bcd4;
  border: none;
  color: black;
  font-size: 24px;
  cursor: pointer;
}

.temp-display {
  text-align: center;
}

.setpoint {
  font-size: 48px;
  font-weight: bold;
  display: block;
}

.room-temp {
  font-size: 14px;
  color: #aaa;
}

.fan-control {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.fan-control select {
  padding: 8px 16px;
  background: #333;
  border: 1px solid #555;
  border-radius: 4px;
  color: white;
}

.ac-offline {
  text-align: center;
  padding: 40px;
}

.offline-message {
  color: #ff4444;
  font-size: 18px;
}
```

**JavaScript:**
```javascript
self.onInit = function() {
  self.ctx.$scope.sendCommand = function(type, value) {
    var params = {};
    
    switch(type) {
      case 'power':
        params.power = value;
        break;
      case 'mode':
        params.mode = value;
        break;
      case 'fan':
        params.fan = value;
        break;
    }
    
    var rpcRequest = {
      method: 'acControl',
      params: params
    };
    
    self.ctx.controlApi.sendTwoWayCommand(
      self.ctx.datasources[0].deviceId,
      rpcRequest.method,
      JSON.stringify(rpcRequest.params),
      5000
    ).subscribe(
      function(response) {
        console.log('AC command success:', response);
      },
      function(error) {
        console.error('AC command failed:', error);
      }
    );
  };
  
  self.ctx.$scope.adjustTemp = function(delta) {
    var current = parseFloat(self.ctx.$scope.ctx.values.ac_setpoint) || 24.0;
    var newTemp = Math.round((current + delta) * 2) / 2;
    newTemp = Math.max(16, Math.min(30, newTemp));
    
    self.ctx.$scope.sendCommand('temp', newTemp);
    self.ctx.$scope.ctx.values.ac_setpoint = newTemp;
  };
};

self.onDataUpdated = function() {
  // Update UI when telemetry changes
};
```

---

## 2. Telemetry Keys

Add these keys to the widget data source:

| Key | Type | Description |
|-----|------|-------------|
| `ac_power` | Boolean | AC ON/OFF status |
| `ac_mode` | String | COOL/HEAT/DRY/FAN/AUTO |
| `ac_setpoint` | Double | Target temperature (°C) |
| `ac_room_temp` | Double | Current room temperature |
| `ac_fan` | String | LOW/MEDIUM/HIGH/AUTO |
| `ac_online` | Boolean | Gateway connection status |

---

## 3. RPC Configuration

**RPC Method:** `acControl`

**Parameters:**
```json
{
  "power": true,
  "mode": "COOL",
  "temp": 22.5,
  "fan": "AUTO"
}
```

---

## 4. Dashboard Layout

Create a new dashboard with:
1. **AC Control Widget** (top center)
2. **Temperature History** (timeseries chart)
3. **Power Usage** (if available from AC)
4. **Alerts** (if AC goes offline)

---

## 5. Alternative: Using Existing KukiSense App

Instead of ThingsBoard widget, use the Flutter app I created:

1. Install the app from `warrenedit` branch
2. Configure AC device ID in settings
3. Control AC from the "AC" tab in bottom navigation

The app provides:
- Real-time control
- Quick actions (Comfort, Sleep, Eco modes)
- Automation rules
- Better UX than ThingsBoard widget

---

## Summary

| Component | Status | Location |
|-----------|--------|----------|
| Firmware TCP Client | ✅ Done | `hazelnut_IAQ/warrenedit` |
| Firmware RPC Handler | ✅ Done | `hazelnut_IAQ/warrenedit` |
| Flutter AC Controller | ✅ Done | `hazelnut_app/warrenedit` |
| Flutter AC Widget | ✅ Done | `hazelnut_app/warrenedit` |
| Flutter Navigation | ✅ Done | `hazelnut_app/warrenedit` |
| ThingsBoard Widget | 📋 Above | Copy HTML/CSS/JS |

All code is pushed and ready. The ThingsBoard widget configuration above can be imported directly into your dashboard.