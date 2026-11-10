// ESP32-C3 reference peripheral for the BLE Scanner app.
//
// Exposes the Bluetooth SIG Environmental Sensing Service (0x181A) with
//   Temperature (0x2A6E): sint16, 0.01 degC, read + notify
//   Humidity    (0x2A6F): uint16, 0.01 %,    read + notify
//
// Values are simulated, so no sensor needs to be wired. The temperature
// sweeps between 1 and 10 degC so it crosses the app's 2-8 degC alert range.
//
// Board: any ESP32-C3 dev board (for example ESP32-C3 SuperMini or
// ESP32-C3-DevKitM-1). It also builds for ESP32, ESP32-S3 and ESP32-C6.
// Arduino IDE: install "esp32 by Espressif Systems", select your board, upload.

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

static const char *DEVICE_NAME = "ENV-C3";
static const uint16_t ESS_UUID = 0x181A;
static const uint16_t TEMPERATURE_UUID = 0x2A6E;
static const uint16_t HUMIDITY_UUID = 0x2A6F;
static const uint32_t UPDATE_INTERVAL_MS = 2000;

static BLECharacteristic *temperatureChar = nullptr;
static BLECharacteristic *humidityChar = nullptr;
static volatile bool clientConnected = false;
static bool wasConnected = false;
static uint32_t lastUpdateMs = 0;
static uint32_t tick = 0;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) {
    clientConnected = true;
  }
  void onDisconnect(BLEServer *server) {
    clientConnected = false;
  }
};

static void publishReadings() {
  // Triangle wave: 1.00 -> 10.00 -> 1.00 degC in 0.25 degC steps.
  const int steps = 36;
  int phase = tick % (2 * steps);
  int position = phase < steps ? phase : (2 * steps - phase);
  int16_t temperature = 100 + position * 25;       // 0.01 degC
  uint16_t humidity = 5500 + (tick % 10) * 20;     // 0.01 %
  tick++;

  temperatureChar->setValue((uint8_t *)&temperature, sizeof(temperature));
  humidityChar->setValue((uint8_t *)&humidity, sizeof(humidity));
  if (clientConnected) {
    temperatureChar->notify();
    humidityChar->notify();
  }
  Serial.printf("T=%d.%02d C  RH=%u.%02u %%  connected=%d\n",
                temperature / 100, temperature % 100,
                humidity / 100, humidity % 100, clientConnected ? 1 : 0);
}

void setup() {
  Serial.begin(115200);

  BLEDevice::init(DEVICE_NAME);
  BLEServer *server = BLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  BLEService *service = server->createService(BLEUUID(ESS_UUID));
  temperatureChar = service->createCharacteristic(
      BLEUUID(TEMPERATURE_UUID),
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  temperatureChar->addDescriptor(new BLE2902());
  humidityChar = service->createCharacteristic(
      BLEUUID(HUMIDITY_UUID),
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  humidityChar->addDescriptor(new BLE2902());
  service->start();

  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLEUUID(ESS_UUID));
  advertising->setScanResponse(true);
  BLEDevice::startAdvertising();

  publishReadings();
  Serial.println("Advertising as ENV-C3");
}

void loop() {
  uint32_t now = millis();
  if (now - lastUpdateMs >= UPDATE_INTERVAL_MS) {
    lastUpdateMs = now;
    publishReadings();
  }

  // Restart advertising after a client disconnects.
  if (wasConnected && !clientConnected) {
    delay(300);
    BLEDevice::startAdvertising();
    Serial.println("Client disconnected, advertising again");
  }
  wasConnected = clientConnected;

  delay(20);
}
