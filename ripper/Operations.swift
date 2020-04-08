//
//  Operations.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 04.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

class MediaDownloader: Operation {
	let url: URL
	let path: String
	let completion: (Bool) -> Void

	init(url: URL, path: String, completion: @escaping (Bool) -> Void) {
		self.url = url
		self.path = path
		self.completion = completion
	}

	override func main() {
		guard !isCancelled else {
			return
		}

		let maxRetries = 5
		var i = 0
		var data: Data?

		while !isCancelled && data == nil && i <= maxRetries {
			i += 1
			do {
				data = try Data(contentsOf: url)
			} catch {
				console.writeMessage("\(i) retry for \(url)")
			}
		}

		if isCancelled {
			completion(false)
			return
		}

		FileManager.default.createFile(atPath: path, contents: data)
		completion(true)
	}
}
