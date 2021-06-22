//
//  main.swift
//  bleconsole
//
//  Created by Aleksandr Vinogradov on 6/21/21.
//

import Foundation

let ble = BleConnection()

while let line = readLine() {
  ble.userInput(line)
}

print("bye")
