//
//  BLEController.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 2/8/2022.
//

import Foundation
import CoreBluetooth

class BLEController: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    var myCentral: CBCentralManager!
    var myPeripheral: CBPeripheral!
    @Published var isBluetoothOn = false
    @Published var isHistoryMode = false
    @Published var isSoundOn = false
    @Published var co2Value = 0
    @Published var temperatureValue = 0.0
    @Published var humidityValue = 0.0
    @Published var historicReadingNumber = 0
    @Published var rssiValue = 0
    @Published var locationManager = LocationManager()

    // Source: https://github.com/Sensirion/arduino-ble-gadget/blob/master/src/Sensirion_GadgetBle_Lib.h
    let sensirionId = "D506"
    let sensirionGadgetName = "S"
    // UUIDs for retrieving historic data
    let co2MonitorServiceUUID = CBUUID(string: "00008000-b38d-4985-720e-0f993a68ee41")
    let co2MonitorCharacteristicUUID = CBUUID(string: "00008004-b38d-4985-720e-0f993a68ee41")

    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myPeripheral = nil

        // For previewing
        // co2Value = 512
        // temperatureValue = 24.0
        // humidityValue = 48.0
        // rssiValue = -96
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isBluetoothOn = true
            myCentral.scanForPeripherals(withServices: nil, options: nil)
        }
        else {
            isBluetoothOn = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // print("BLE Peripheral found: \(peripheral), \(peripheral.name ?? "No name") (RSSI: \(RSSI))")

        if  peripheral.name == sensirionGadgetName {
            // For realtime data, read the advertisementData
            let data = advertisementData["kCBAdvDataManufacturerData"] as! NSData
            print("BLE ad data: \(String(describing: data))")

            let companyIdentifier = data.subdata(with: NSMakeRange(0, 2)).hexadecimalString(packed: true)

            if companyIdentifier == sensirionId {
                myPeripheral = peripheral
                rssiValue = RSSI.intValue

                if !data.isEmpty {
                    let temperature = data.subdata(with: NSMakeRange(6, 2)).withUnsafeBytes {
                        $0.load(as: Int16.self)
                    }
                    let humidity = data.subdata(with: NSMakeRange(8, 2)).withUnsafeBytes {
                        $0.load(as: Int16.self)
                    }
                    let co2 = data.subdata(with: NSMakeRange(10, 2)).withUnsafeBytes {
                        $0.load(as: Int16.self)
                    }
                    print("BLE raw data: \(co2) \(temperature) \(humidity)")
                    if co2 > 0 {
                        if isSoundOn && co2 != self.co2Value {
                            playNote(co2: co2)
                        }
                        if isSoundOn {
                            vibrate(co2: co2)
                        }
                        self.co2Value = decodeCO2(co2: co2)
                        self.temperatureValue = decodeTemperature(temperature: temperature)
                        self.humidityValue = decodeHumidity(humidity: humidity)
                        print("BLE decoded data: \(self.co2Value) \(self.temperatureValue) \(self.humidityValue)")
                        postToInfluxdb()
                    }
                }
            }
        }
        peripheral.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLE Connected to: \(peripheral)")
        peripheral.delegate = self
        peripheral.discoverServices([co2MonitorServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLE Disconnected from \(peripheral)")
        // If we want to always be connected to historic data, retry
        // central.connect(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            print("BLE raw: \(String(describing: characteristic.value?.hexadecimalString()))")
            // Decode historic data
            let data = NSData(data: characteristic.value!)
            if !data.isEmpty {
                let readingNumber = data.subdata(with: NSMakeRange(0, 2)).withUnsafeBytes {
                    $0.load(as: Int16.self)
                }
                let temperature = data.subdata(with: NSMakeRange(8, 2)).withUnsafeBytes {
                    $0.load(as: Int16.self)
                }
                let humidity = data.subdata(with: NSMakeRange(10, 2)).withUnsafeBytes {
                    $0.load(as: Int16.self)
                }
                let co2 = data.subdata(with: NSMakeRange(12, 2)).withUnsafeBytes {
                    $0.load(as: Int16.self)
                }
                if co2 > 0 {
                    if isSoundOn {
                        playNote(co2: co2)
                        vibrate(co2: co2)
                    }
                    self.co2Value = decodeCO2(co2: co2)
                    self.temperatureValue = decodeTemperature(temperature: temperature)
                    self.humidityValue = decodeHumidity(humidity: humidity)
                    self.historicReadingNumber = Int(readingNumber)
                    print("BLE data: \(self.co2Value) \(self.temperatureValue) \(self.humidityValue)")
                    postToInfluxdb()
                }
            }
            peripheral.readRSSI()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("BLE Services: \(String(describing: peripheral.services))")
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
            peripheral.discoverIncludedServices(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("BLE Characteristics: \(String(describing: service.characteristics))")
        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == co2MonitorCharacteristicUUID {
                print("BLE Signing up for notifications from: \(characteristic)")
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.discoverDescriptors(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("BLE notification state changed: \(characteristic.isNotifying)")
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        rssiValue = RSSI.intValue
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("BLE write value: \(characteristic)")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        print("BLE write value descriptor: \(descriptor)")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("BLE value for descriptor: \(descriptor)")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("BLE descriptors: \(characteristic)")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        print("BLE included services: \(service)")
    }

    // Decode using https://github.com/custom-components/ble_monitor/blob/master/custom_components/ble_monitor/ble_parser/sensirion.py

    func decodeTemperature(temperature: Int16) -> Double {
        return ((Double(temperature) / 65535) * 175) - 45
    }

    func decodeHumidity(humidity: Int16) -> Double {
        var humidity = ((Double(humidity) / 65535) * 100)
        // When humidity is greater than or equal to 50.0 it returns a negative value
        // and 100 needs to be added
        if (humidity < 0) {
            humidity = 100 + humidity
        }
        return humidity
    }

    func decodeCO2(co2: Int16) -> Int {
        return Int(co2)
    }

    func historicMode() {
        // For historic data download, connect to the peripheral
        isHistoryMode = true
        myCentral.stopScan()
        if myPeripheral != nil {
             myCentral.connect(myPeripheral, options: nil)
        }
    }

    func liveMode() {
        isHistoryMode = false
        if myPeripheral != nil {
            myCentral.cancelPeripheralConnection(myPeripheral)
        }
        myCentral.scanForPeripherals(withServices: nil, options: nil)
    }

    func postToInfluxdb() {
        let influxdbOrganisationID = UserDefaults.standard.string(forKey: "influxdbOrganisationID") ?? ""
        let influxdbBucketID = UserDefaults.standard.string(forKey: "influxdbBucketID") ?? ""
        let influxdbAPIKey = UserDefaults.standard.string(forKey: "influxdbAPIKey") ?? ""
        let postToInfluxdb = UserDefaults.standard.bool(forKey: "postToInfluxdb")
        let influxdbServer = UserDefaults.standard.string(forKey: "influxdbServer") ?? "https://us-central1-1.gcp.cloud2.influxdata.com"
        let influxdbURL = URL(string: "\(influxdbServer)/api/v2/write?org=\(influxdbOrganisationID)&bucket=\(influxdbBucketID)&precision=ns")!
        if (influxdbOrganisationID != "" && influxdbBucketID != "" && influxdbAPIKey != "" && postToInfluxdb) {
            var request = URLRequest(url: influxdbURL)
            let latitude = locationManager.lastLocation?.coordinate.latitude ?? 0
            let longitude = locationManager.lastLocation?.coordinate.longitude ?? 0
            request.httpMethod = "POST"
            request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("Token \(influxdbAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = "co2sensor,sensor_id=SCD41 temperature=\(temperatureValue),humidity=\(humidityValue),co2=\(co2Value),latitude=\(latitude),longitude=\(longitude)".data(using: .utf8)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    print("-----> data: \(String(describing: data))")
                    print("-----> error: \(String(describing: error))")
                    guard let data = data, error == nil else {
                        print(error?.localizedDescription ?? "No data")
                        return
                    }
                    let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
                    print("-----1> responseJSON: \(String(describing: responseJSON))")
                    if let responseJSON = responseJSON as? [String: Any] {
                        print("-----2> responseJSON: \(responseJSON)")
                    }
                }
            }
            task.resume()
        }
    }
}

internal extension Data {

    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }
    
    func to<T>(type: T.Type) -> T where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        _ = Swift.withUnsafeMutableBytes(of: &value, { copyBytes(to: $0)} )
        return value as T
    }

    static var isLittleEndian: Bool {

        let endian = CFByteOrderGetCurrent()

        if endian == CFIndex(Int(CFByteOrderLittleEndian.rawValue)) {
            return true
        }

        return false
    }

    var safeStringValue: String? {

        var maybeString: String?

        if self.count > 0 {
            if self[self.count - 1] == 0x00 {
                maybeString = String(data: self, encoding: .utf8)
            } else {
                maybeString = String(data: self, encoding: .ascii)
            }
        }

        return maybeString
    }

    // Formats Data as HEX String
    //
    // - Parameters:
    //   - formatted: Use Formatting where data is "[0x00][0x00]"
    //   - uselower: Lowercase string
    //   - packed: Packs the data together (no spaces)
    // - Returns: HEX Formatted String
    func hexadecimalString(formatted: Bool = false, uselower: Bool = false, packed: Bool = false) -> String {
        var hexString = String()

        if formatted {
            hexString = self.reduce("", { String(format: "\($0)[%02hhx] ", $1) })
        } else {
            hexString = self.reduce("", { String(format: "\($0)%02hhx ", $1) })
        }

        if packed {
            hexString = hexString.replacingOccurrences(of: " ", with: "")
        }

        if uselower {
            return hexString.lowercased() as String
        } else {
            return hexString.uppercased() as String
        }
    }
}
