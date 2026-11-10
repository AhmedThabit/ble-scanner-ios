# BLE Scanner for iOS

A small SwiftUI app that scans for Bluetooth Low Energy devices, connects to a
sensor exposing the standard Environmental Sensing Service (0x181A), and shows
live temperature and humidity. It comes with matching ESP32-C3 firmware, so the
whole chain can be tested without buying a sensor.

The project is built entirely on GitHub Actions. No Mac is needed.

## What it does

- Lists nearby BLE devices with signal strength, sensors first.
- Connects, subscribes to temperature (0x2A6E) and humidity (0x2A6F) notifications.
- Flags temperatures outside a 2 to 8 °C range in red.
- Reconnects automatically when the sensor comes back in range.
- Keeps a connection log on screen for debugging.

## Repository layout

| Path | Contents |
|---|---|
| `App/` | SwiftUI app and the CoreBluetooth manager |
| `BLECore/` | Pure Swift package with parsers and unit tests (runs on Linux) |
| `firmware/esp32c3_env_sensor/` | Arduino sketch for the ESP32-C3 reference sensor |
| `project.yml` | XcodeGen project definition (the `.xcodeproj` is generated in CI) |
| `.github/workflows/` | Linux unit tests and the macOS IPA build |

## Get the app onto an iPhone

1. Open the **Actions** tab, choose **iOS build (unsigned IPA)**, and open the latest successful run.
2. Download the artifact **BLEScanner-unsigned-ipa** and unzip it to get `BLEScanner-unsigned.ipa`.
3. Sign and install the IPA with a sideloading tool and your Apple ID. With a free Apple ID the app works for 7 days, then needs installing again.
4. On the iPhone, trust the developer profile under Settings > General > VPN & Device Management.
5. Open the app and allow Bluetooth access.

## Flash the ESP32-C3 sensor

1. In the Arduino IDE, install the board package **esp32 by Espressif Systems**.
2. Open `firmware/esp32c3_env_sensor/esp32c3_env_sensor.ino`.
3. Select your ESP32-C3 board and its serial port, then upload.
4. The board advertises as **ENV-C3**. The serial monitor at 115200 baud prints each reading.

The values are simulated: temperature sweeps from 1 to 10 °C, so it crosses the
alert range and the red warning can be seen in the app.

## Run the unit tests locally

```
swift test --package-path BLECore
```

## Limits of a free Apple ID build

Bluetooth, camera and local storage work. Push notifications, in-app purchases
and iCloud need a paid Apple Developer account.
