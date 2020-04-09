//
//  ConsoleIO.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 01.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

enum OutputType {
	case error
	case standard
}

class ConsoleIO {
	func writeMessage(_ message: String, to: OutputType = .standard, terminator: String = "\n") {
		switch to {
		case .standard:
			print("\(message)", terminator: terminator)
		case .error:
			fputs("Error: \(message)\n", stderr)
		}
	}
}
