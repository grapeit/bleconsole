//
//  BleConnection.swift
//  bleconsole
//
//  Created by Aleksandr Vinogradov on 6/21/21.
//

import Foundation
import CoreBluetooth


class BleConnection: NSObject {
  private var manager: CBCentralManager!
  private var peripheral: CBPeripheral!
  private var characteristic: CBCharacteristic!
  private var discoveredDevices = [CBPeripheral]()
  private var discoveredServices = [CBService]()
  private var discoveredCharacteristics = [CBCharacteristic]()

  override init() {
    super.init()
    manager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background))
  }

  func userInput(_ input: String) {
    if discoveredServices.isEmpty {
      connect(deviceNumber: Int(input) ?? 0)
      return
    }
    if discoveredCharacteristics.isEmpty {
      discoverCharacteristics(serviceNumber: Int(input) ?? 0)
      return
    }
    if characteristic == nil {
      selectCharacteristc(characteristicNumber: Int(input) ?? 0)
      return
    }
    send(input)
  }

  func connect(deviceNumber: Int) {
    guard manager != nil && deviceNumber > 0 && deviceNumber <= discoveredDevices.count else {
      print("wrong device #\(deviceNumber)")
      return
    }
    manager.stopScan()
    peripheral = discoveredDevices[deviceNumber - 1]
    peripheral.delegate = self
    print("connecting to #\(deviceNumber) [\(Unmanaged.passUnretained(peripheral).toOpaque())] - \(peripheral.name ?? "")")
    manager.connect(peripheral, options: nil)
  }

  func discoverCharacteristics(serviceNumber: Int) {
    guard peripheral != nil && serviceNumber > 0 && serviceNumber <= discoveredServices.count else {
      print("wrong service #\(serviceNumber)")
      return
    }
    print("discovering characteristics")
    peripheral.discoverCharacteristics(nil, for: discoveredServices[serviceNumber - 1])
  }

  func selectCharacteristc(characteristicNumber: Int) {
    guard peripheral != nil && characteristicNumber > 0 && characteristicNumber <= discoveredCharacteristics.count else {
      print("wrong characteristic #\(characteristicNumber)")
      return
    }
    characteristic = discoveredCharacteristics[characteristicNumber - 1]
    print("communicating with characteristic \(characteristic.uuid)")
    peripheral.setNotifyValue(true, for: characteristic)
  }

  func send(_ string: String) {
    guard let data = (string + "\r").data(using: .ascii) else {
      return
    }
    send(data)
  }

  func send(_ data: Data) {
    guard peripheral != nil && characteristic != nil else {
      return
    }
    peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
  }
}

extension BleConnection: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == CBManagerState.poweredOn {
      print("searching for devices")
      central.scanForPeripherals(withServices: nil, options: nil)
    } else {
      self.characteristic = nil
      self.peripheral = nil
      print("bluetooth is not available (\(central.state.rawValue))")
    }
  }

  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
    let advertisedName = String((advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString ?? "")
    guard !advertisedName.isEmpty else {
      return
    }
    let ptr = Unmanaged.passUnretained(peripheral).toOpaque()
    for i in discoveredDevices {
      if Unmanaged.passUnretained(i).toOpaque() == ptr {
        return
      }
    }
    discoveredDevices.append(peripheral)
    print("\(discoveredDevices.count): [\(ptr)] [\(RSSI)] \(peripheral.name ?? advertisedName)")
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("connected to [\(Unmanaged.passUnretained(peripheral).toOpaque())] - \(peripheral.name ?? "")")
    peripheral.discoverServices(nil)
    print("discovering services")
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    print("failed to connect to [\(Unmanaged.passUnretained(peripheral).toOpaque())] - \(peripheral.name ?? "")")
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    print("disconnected from [\(Unmanaged.passUnretained(peripheral).toOpaque())] - \(peripheral.name ?? "")")
  }
}

extension BleConnection: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard peripheral.services != nil else {
      print("no services")
      return
    }
    discoveredServices = peripheral.services!
    var idx = 0
    for service in discoveredServices {
      idx += 1
      print("\(idx): \(service.uuid) - \(service.uuid.uuidString)")
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard service.characteristics != nil else {
      print("no characteristics")
      return
    }
    discoveredCharacteristics = service.characteristics!
    var idx = 0
    for characteristic in service.characteristics! {
      idx += 1
      print("\(idx): \(characteristic.uuid) - \(characteristic.uuid.uuidString)")
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value else {
      return
    }
    print("<<\(String(data: data, encoding: .ascii) ?? "")")
  }
}