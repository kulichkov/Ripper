//
//  main.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 01.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

enum RipperError: Error {
	case wrongURL
	case responseError(Error)
	case parseError(Error)
}

struct Segment: Decodable {
	let url: String
}

enum MediaType: String { case video, audio }

struct Media: Decodable {
	let base_url: String
	let init_segment: String
	let segments: [Segment]
	let bitrate: Int
}

struct Master: Decodable {
	let video: [Media]
	let audio: [Media]
	let clip_id: String
	let base_url: String
}

typealias Path = String

let args = CommandLine.arguments
let mp4Ext = ".mp4"

let console = ConsoleIO()

if args.count == 3 {
	let masterURL = args[1]
	let outputFilename: String = {
		var filename = args[2]
		if !filename.hasSuffix(mp4Ext) { filename += mp4Ext }
		return filename
	}()

	getJSONDict(url: masterURL) { result in
		switch result {
		case .success(let master):
			processMaster(
				master,
				masterURL: masterURL,
				outputFilename: outputFilename)
		case .failure(let error):
			print(error)
		}
	}
} else {
	printUsage()
}

func processMaster(_ master: Master, masterURL: String, outputFilename: String) {
	console.writeMessage("Master file downloaded")

	let currentPath = FileManager.default.currentDirectoryPath
	let videoOutputPath = currentPath + "/\(master.clip_id).m4v"
	let segmentsFolder = currentPath + "/\(master.clip_id)"
	let videoSegmentsFolder = segmentsFolder + "/video"
	let audioSegmentsFolder = segmentsFolder + "/audio"
	let audioOutputPath = currentPath + "/\(master.clip_id).m4a"
	let masterURL = URL(string: masterURL)!

	let video = master.video.sorted { $0.bitrate > $1.bitrate }.first!
	let audio = master.audio.sorted { $0.bitrate > $1.bitrate }.first!

	let mediaBaseURL = masterURL
		.withoutLastPathComponent()
		.resolved(to: master.base_url)

	// Video processing
	process(
		video,
		type: .video,
		to: videoOutputPath,
		baseURL: mediaBaseURL,
		tempFolder: videoSegmentsFolder)

	// Audio processing
	process(
		audio,
		type: .audio,
		to: audioOutputPath,
		baseURL: mediaBaseURL,
		tempFolder: audioSegmentsFolder)

	deleteLocalResources([segmentsFolder], startMessage: "Deleting segment folder")

	// Merging audio and video
	let merger = MediaMerger(
		videoPath: videoOutputPath,
		audioPath: audioOutputPath,
		output: currentPath + "/" + outputFilename)

	let queue = OperationQueue()
	queue.addOperations([merger], waitUntilFinished: true)

	deleteLocalResources(
		[videoOutputPath, audioOutputPath],
		startMessage: "Deleting separate audio/video files")
}

func process(_ media: Media, type: MediaType, to output: Path, baseURL: URL, tempFolder: Path) {
	console.writeMessage("Starting download \(type.rawValue)...")
	let mediaPaths = downloadMedia(media, to: tempFolder, baseURL: baseURL)

	console.writeMessage("\(type.rawValue.capitalized) downloaded. Starting merging \(type.rawValue) segments...")

	mergeMediaFiles(
		mediaPaths,
		to: output,
		withInitData: Data(base64Encoded: media.init_segment))
	console.writeMessage("\(type.rawValue.capitalized) merged.")

	deleteLocalResources([tempFolder], startMessage: "Deleting \(type.rawValue) segment folder")
}

func deleteLocalResources(_ paths: [Path], startMessage: String) {
	console.writeMessage(startMessage, terminator: "...")
	do {
		try paths.forEach(FileManager.default.removeItem)
		console.writeMessage("Completed")
	} catch {
		console.writeMessage(error.localizedDescription, to: .error)
	}
}

func mergeMediaFiles(_ paths: [Path], to output: Path, withInitData initData: Data?) {
	guard FileManager.default.createFile(atPath: output, contents: initData) else {
		console.writeMessage("Error creating file \(output)", to: .error)
		return
	}

	let output = FileHandle(forWritingAtPath: output)
	output?.seekToEndOfFile()

	defer { output?.closeFile() }

	do {
		for path in paths {
			output?.write(try Data(contentsOf: URL(fileURLWithPath: path)))
			try FileManager.default.removeItem(atPath: path)
		}
	} catch {
		console.writeMessage(error.localizedDescription, to: .error)
		return
	}
}

func downloadMedia(_ media: Media, to localFolder: Path, baseURL: URL) -> [Path] {
	do {
		try FileManager.default.createDirectory(
			atPath: localFolder,
			withIntermediateDirectories: true)
	} catch {
		console.writeMessage(error.localizedDescription, to: .error)
		return []
	}

	let mediaURL = baseURL.resolved(to: media.base_url)

	var fileURLs = [Path]()

	let operations = media.segments.map { (segment) -> MediaDownloader in
		let segmentSourceURL = mediaURL.resolved(to: segment.url)
		let segmentPath = localFolder + "/" + segment.url
		fileURLs.append(segmentPath)
		return MediaDownloader(url: segmentSourceURL, path: segmentPath) { isDownloaded in
			if isDownloaded {
				console.writeMessage("data written to \(segmentPath)")
			} else {
				console.writeMessage("no data written for \(segment.url)")
			} } }

	let queue = OperationQueue()
	queue.addOperations(operations, waitUntilFinished: true)
	return fileURLs
}

func printUsage() {
	let executableName = (CommandLine.arguments[0] as NSString).lastPathComponent
	console.writeMessage("usage:")
	console.writeMessage("\(executableName) \"<master url>\" \"<output>\"")
}

func getJSONDict(url: String, completion: (Result<Master, RipperError>) -> Void) {
	let base64Suffix = "?base64_init=1"
	var stringUrl = url
	if !stringUrl.hasSuffix(base64Suffix) {
		stringUrl += base64Suffix
	}

	guard let url = URL(string: stringUrl) else {
		completion(.failure(.wrongURL))
		return
	}

	let data: Data
	do {
		data = try Data(contentsOf: url)
	} catch {
		completion(.failure(.responseError(error)))
		return
	}

	do {
		let master = try JSONDecoder().decode(Master.self, from: data)
		completion(.success(master))
	} catch {
		completion(.failure(.parseError(error)))
	}
}
