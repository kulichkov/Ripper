//
//  Operations.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 04.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation
import AVFoundation

// https://www.avanderlee.com/swift/asynchronous-operations/

class AsyncOperation: Operation {
	private let lockQueue = DispatchQueue(label: "ru.kulichkov.asyncoperation", attributes: .concurrent)

	override var isAsynchronous: Bool {
		return true
	}

	private var _isExecuting: Bool = false
	override private(set) var isExecuting: Bool {
		get {
			return lockQueue.sync { () -> Bool in
				return _isExecuting
			}
		}
		set {
			willChangeValue(forKey: "isExecuting")
			lockQueue.sync(flags: [.barrier]) {
				_isExecuting = newValue
			}
			didChangeValue(forKey: "isExecuting")
		}
	}

	private var _isFinished: Bool = false
	override private(set) var isFinished: Bool {
		get {
			return lockQueue.sync { () -> Bool in
				return _isFinished
			}
		}
		set {
			willChangeValue(forKey: "isFinished")
			lockQueue.sync(flags: [.barrier]) {
				_isFinished = newValue
			}
			didChangeValue(forKey: "isFinished")
		}
	}

	override func start() {
		guard !isCancelled else {
			finish()
			return
		}

		isFinished = false
		isExecuting = true
		main()
	}

	override func main() {
		fatalError("Subclasses must implement `execute` without overriding super.")
	}

	func finish() {
		isExecuting = false
		isFinished = true
	}
}

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

class MediaMerger: AsyncOperation {
	let videoPath: Path
	let audioPath: Path
	let output: Path

	init(videoPath: Path, audioPath: Path, output: Path) {
		self.videoPath = videoPath
		self.audioPath = audioPath
		self.output = output
	}

	override func main() {
		guard !isCancelled else {
			return
		}

		console.writeMessage("Starting merging tracks...")

		let videoAsset = AVAsset(url: URL(fileURLWithPath: videoPath))
		let audioAsset = AVAsset(url: URL(fileURLWithPath: audioPath))
		let mixComposition = AVMutableComposition()
		let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: 0)
		let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: 0)

		do {
			try videoTrack?.insertTimeRange(
				videoAsset.tracks.first!.timeRange,
				of: videoAsset.tracks.first!,
				at: .zero)

			try audioTrack?.insertTimeRange(
				audioAsset.tracks.first!.timeRange,
				of: audioAsset.tracks.first!,
				at: .zero)
		} catch {
			console.writeMessage(error.localizedDescription)
		}

		guard !isCancelled else {
			return
		}

		guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetPassthrough) else { return }
		exporter.outputURL = URL(fileURLWithPath: output)
		exporter.outputFileType = .mp4

		guard !isCancelled else {
			return
		}

		exporter.exportAsynchronously {
			console.writeMessage("Merging completed")
			self.finish()
		}
	}
}
