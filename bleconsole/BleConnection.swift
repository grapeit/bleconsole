import Foundation
import CoreBluetooth

class BleConnection: NSObject {
  private var manager: CBCentralManager!
  private var peripheral: CBPeripheral!
  private var service: CBService!
  private var characteristic: CBCharacteristic!
  private var discoveredDevices = [CBPeripheral]()
  private var discoveredServices = [CBService]()
  private var discoveredCharacteristics = [CBCharacteristic]()
  private var outputStyle = OutputStyle.raw

  enum OutputStyle {
    case raw
    case hexadecimal
  }

  override init() {
    super.init()
    manager = CBCentralManager(delegate: self, queue: DispatchQueue.global(qos: .background))
  }

  func reset() {
    discoveredCharacteristics.removeAll()
    discoveredServices.removeAll()
    discoveredDevices.removeAll()
    characteristic = nil
    service = nil
    peripheral = nil
    centralManagerDidUpdateState(manager)
  }

  func userInput(_ input: String) {
    if input == "\u{18}" { // Ctrl+X
      if characteristic != nil && service != nil && peripheral != nil {
        discoveredCharacteristics.removeAll()
        characteristic = nil
        print("re-discovering characteristics of service \(service.displayName)")
        peripheral.discoverCharacteristics(nil, for: service)
        return
      }
      if service != nil && peripheral != nil {
        discoveredCharacteristics.removeAll()
        discoveredServices.removeAll()
        characteristic = nil
        service = nil
        print("re-discovering services of \(peripheral.displayName)")
        peripheral.discoverServices(nil)
        return
      }
      if peripheral != nil {
        manager.cancelPeripheralConnection(peripheral)
        return
      }
      reset()
      return
    }
    if input == "\u{6}" { // Ctrl+F
      if characteristic != nil && peripheral != nil {
        print("requesting value for \(characteristic.displayName)")
        peripheral.readValue(for: characteristic)
      }
      return
    }
    if peripheral == nil {
      connect(deviceNumber: Int(input) ?? 0)
      return
    }
    if service == nil {
      selectService(serviceNumber: Int(input) ?? 0)
      return
    }
    if characteristic == nil {
      outputStyle = input.hasSuffix("h") ? .hexadecimal : .raw
      selectCharacteristc(characteristicNumber: Int(outputStyle != .raw ? String(input.dropLast()) : input) ?? 0)
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
    print("connecting to \(peripheral.displayName)")
    manager.connect(peripheral, options: nil)
  }

  func selectService(serviceNumber: Int) {
    guard peripheral != nil && serviceNumber > 0 && serviceNumber <= discoveredServices.count else {
      print("wrong service #\(serviceNumber)")
      return
    }
    service = discoveredServices[serviceNumber - 1]
    print("discovering characteristics of service \(service.displayName)")
    peripheral.discoverCharacteristics(nil, for: service)
  }

  func selectCharacteristc(characteristicNumber: Int) {
    guard peripheral != nil && characteristicNumber > 0 && characteristicNumber <= discoveredCharacteristics.count else {
      print("wrong characteristic #\(characteristicNumber)")
      return
    }
    characteristic = discoveredCharacteristics[characteristicNumber - 1]
    print("communicating with characteristic \(characteristic.displayName)")
    peripheral.readValue(for: characteristic)
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
      discoveredDevices.removeAll()
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
    for i in discoveredDevices {
      if i.identifier == peripheral.identifier {
        return
      }
    }
    discoveredDevices.append(peripheral)
    print("\(discoveredDevices.count): [\(RSSI)] \(peripheral.displayName)")
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("connected to \(peripheral.displayName)")
    peripheral.discoverServices(nil)
    print("discovering services of \(peripheral.displayName)")
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    print("failed to connect to \(peripheral.displayName)")
    reset()
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    print("disconnected from \(peripheral.displayName)")
    reset()
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
      print("\(idx): \(service.displayName)")
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
    print("\(peripheral.displayName) modified services")
    manager.cancelPeripheralConnection(peripheral)
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
      print("\(idx)[h]: \(characteristic.displayName)")
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    guard let data = characteristic.value else {
      return
    }
    let input: String
    switch outputStyle {
    case .raw:
      input = String(data: data, encoding: .ascii) ?? ""
    case .hexadecimal:
      input = data.map{ String(format: "%02hhx", $0) }.joined()
    }
    print("<<\(input)")
  }
}

private func makeDisplayName(raw: String, desc: String?) -> String {
  if raw == desc {
    return "[\(raw)]"
  } else {
    return "[\(raw)] \(desc!)"
  }
}

extension CBPeripheral {
  var displayName: String {
    return makeDisplayName(raw: identifier.uuidString, desc: name)
  }
}

extension CBService {
  var displayName: String {
    return makeDisplayName(raw: uuid.uuidString, desc: String(describing: uuid))
  }
}

extension CBCharacteristic {
  var displayName: String {
    return makeDisplayName(raw: uuid.uuidString, desc: String(describing: uuid))
  }
}
