//
//  MediaDownloader.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 09.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

class MediaDownloader: AsyncOperation {
	let url: URL
	let path: String
	let completion: (Bool) -> Void

	private var dataTask: URLSessionDataTask?

	init(url: URL, path: String, completion: @escaping (Bool) -> Void) {
		self.url = url
		self.path = path
		self.completion = completion
	}

	override func main() {
		guard !isCancelled else {
			return
		}

		let fetchCompletion = { [path, weak self] (data: Data) -> Void in
			FileManager.default.createFile(atPath: path, contents: data)
			self?.completion(true)
			self?.finish() }

		fetchData(url: url, completion: fetchCompletion)

		if isCancelled {
			completion(false)
			return
		}
	}

	override func cancel() {
		dataTask?.cancel()
		super.cancel()
	}

	private func fetchData(url: URL, retries: Int = 5, completion: @escaping (Data) -> Void) {
		dataTask?.cancel()
		guard retries > 0 else {
			console.writeMessage("No data for \(url)", to: .error)
			self.completion(false)
			finish()
			return
		}
		dataTask = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
			if let data = data {
				completion(data)
			} else {
				self?.fetchData(url: url, retries: retries - 1, completion: completion)
			}
		}
		dataTask?.resume()
	}
}
