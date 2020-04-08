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
	let completion: (Data?) -> Void

	init(url: URL, completion: @escaping (Data?) -> Void) {
		self.url = url
		self.completion = completion
	}

	override func main() {
		if isCancelled {
			completion(nil)
			return
		}
		guard let data = try? Data(contentsOf: url), !isCancelled else {
			completion(nil)
			return
		}
		completion(data)
	}
}
