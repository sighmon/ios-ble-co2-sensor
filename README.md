# A Bluetooth CO2 monitor app for iOS

An iOS app to read Sensirion SCD-41 CO2 sensor readings written in SwiftUI.

## Hardware

* [ESP32-C3](https://core-electronics.com.au/adafruit-qt-py-esp32-c3-wifi-dev-board-with-stemma-qt.html)
* [Lipo charger](https://core-electronics.com.au/adafruit-liion-or-lipoly-charger-bff-add-on-for-qt-py.html)
* [SCD-41](https://core-electronics.com.au/adafruit-scd-41-ndir-co2-temperature-and-humidity-sensor-stemma-qt-qwiic.html)
* [Qwiic cable](https://core-electronics.com.au/flexible-qwiic-cable-50mm.html)
* [JST 2-pin cable](https://core-electronics.com.au/jst-2-pin-cable.html)
* Nokia BP-6MT 3.7V battery

## Software

* [Arduino ESP32-C3 BLE and HTTP exporter](https://github.com/sighmon/co2_sensor_scd4x_esp32_http_server/tree/add/4-adafruit-qt-py-esp32-c3)

## TODO

- [x] Download historic data
- [ ] Read realtime data
- [ ] Export to InfluxDB
