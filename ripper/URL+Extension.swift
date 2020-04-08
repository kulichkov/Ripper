//
//  URL+Extension.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 07.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

extension URL {
	func withoutLastPathComponent() -> URL {
		guard let index = absoluteString.lastIndex(of: "/") else { return self }
		let string = String(absoluteString.prefix(upTo: index))
		return URL(string: string) ?? self
	}

	func resolved(to pathComponent: String) -> URL {
		return appendingPathComponent(pathComponent).standardized
	}
}
