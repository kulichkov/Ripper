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
	func writeMessage(_ message: String, sameLine: Bool = false, to: OutputType = .standard) {
		switch to {
		case .standard:
			print("\(message)")
		case .error:
			fputs("Error: \(message)\n", stderr)
		}
	}
}
