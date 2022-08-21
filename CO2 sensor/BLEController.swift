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
    @Published var isSwitchedOn = false
    @Published var co2Value = 0
    @Published var temperatureValue = 0.0
    @Published var humidityValue = 0.0
    @Published var rssiValue = 0

    // Source: https://github.com/Sensirion/arduino-ble-gadget/blob/master/src/Sensirion_GadgetBle_Lib.h
    // TOFIX: currently retrieves historic data
    let co2Identifier = "50B30635-FC9C-57E6-A116-8FF87F780018"
    let co2MonitorServiceUUID = CBUUID(string: "00008000-b38d-4985-720e-0f993a68ee41")
    let co2MonitorCharacteristicUUID = CBUUID(string: "00008004-b38d-4985-720e-0f993a68ee41")

    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myPeripheral = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
            myCentral.scanForPeripherals(withServices: nil, options: nil)
        }
        else {
            isSwitchedOn = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("BLE Peripheral found: \(peripheral), \(peripheral.name ?? "No name") (RSSI: \(RSSI))")
        print(peripheral.services ?? "No services...")
        if peripheral.identifier.uuidString == co2Identifier {
            myPeripheral = peripheral
            rssiValue = RSSI.intValue
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
        peripheral.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("BLE Connected to: \(peripheral)")
        peripheral.delegate = self
        peripheral.discoverServices([co2MonitorServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("BLE Disconnected from \(peripheral)... retrying")
        central.connect(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error == nil {
            print("BLE raw: \(String(describing: characteristic.value?.hexadecimalString()))")

            let data = NSData(data: characteristic.value!)
            if !data.isEmpty {
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
                    self.co2Value = decodeCO2(co2: co2)
                    self.temperatureValue = decodeTemperature(temperature: temperature)
                    self.humidityValue = decodeHumidity(humidity: humidity)
                    print("BLE data: \(self.co2Value) \(self.temperatureValue) \(self.humidityValue)")
                }
            }
            peripheral.readRSSI()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("BLE Services: \(String(describing: peripheral.services))")
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("BLE Characteristics: \(String(describing: service.characteristics))")
        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == co2MonitorCharacteristicUUID {
                print("BLE Signing up for notifications from: \(characteristic)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("BLE notification state changed: \(characteristic.isNotifying)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        rssiValue = RSSI.intValue
    }

    // TODO: Decode using https://github.com/custom-components/ble_monitor/blob/master/custom_components/ble_monitor/ble_parser/sensirion.py

    func decodeTemperature(temperature: Int16) -> Double {
        return ((Double(temperature) / 65535) * 175) - 45
    }
    
    func decodeHumidity(humidity: Int16) -> Double {
        return 100 + ((Double(humidity) / 65535) * 100)
    }
    
    func decodeCO2(co2: Int16) -> Int {
        return Int(co2)
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
