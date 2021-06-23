import Foundation

let ble = BleConnection()

while let line = readLine() {
  ble.userInput(line)
}

print("bye")
