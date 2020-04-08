//
//  main.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 01.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

let args = CommandLine.arguments
let console = ConsoleIO()

enum RipperError: Error {
	case wrongURL
	case responseError(Error)
	case parseError(Error)
}

struct Segment: Decodable {
	let url: String
}

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

if args.count == 3 {
	let masterURL = args[1]
	let outputFilename = args[2]
	let currentPath = FileManager.default.currentDirectoryPath

	getJSONDict(url: masterURL) { result in
		switch result {
		case .success(let master):
			console.writeMessage("Master file is downloaded...")

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

			let videoBase64String = video.init_segment
			let audioBase64String = audio.init_segment

			//FileManager.default.createFile(atPath: videoOutputPath, contents: Data(base64Encoded: videoBase64String))

			//			let videoFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: videoOutputPath))
			//			videoFile?.seekToEndOfFile()
			//			defer { videoFile?.closeFile() }
			
			console.writeMessage("Starting download video...")
			downloadMedia(video, to: videoSegmentsFolder, baseURL: mediaBaseURL)

			console.writeMessage("Starting download audio...")
			downloadMedia(audio, to: audioSegmentsFolder, baseURL: mediaBaseURL)


		case .failure(let error):
			print(error)
		}
	}
} else {
	printUsage()
}


func downloadMedia(_ media: Media, to localFolder: String, baseURL: URL) {
	do {
		try FileManager.default.createDirectory(
			atPath: localFolder,
			withIntermediateDirectories: true)
	} catch {
		console.writeMessage(error.localizedDescription, to: .error)
		return
	}

	let mediaURL = baseURL.resolved(to: media.base_url)

	let operations = media.segments.map { (segment) -> MediaDownloader in
		let segmentSourceURL = mediaURL.resolved(to: segment.url)
		let segmentPath = localFolder + "/" + segment.url
		return MediaDownloader(url: segmentSourceURL, path: segmentPath) { isDownloaded in
			if isDownloaded {
				console.writeMessage("data written to \(segmentPath)")
			} else {
				console.writeMessage("no data written for \(segment.url)")
			} } }

	let queue = OperationQueue()
	queue.addOperations(operations, waitUntilFinished: true)
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



/*
function combineSegments(type, i, segmentsUrl, output, cb) {
  if (i >= segmentsUrl.length) {
    console.log(`${type} done`);
    return cb();
  }

  console.log(`Download ${type} segment ${i}`);

  https.get(segmentsUrl[i], (res) => {
    res.on('data', (d) => output.write(d));

    res.on('end', () => combineSegments(type, i+1, segmentsUrl, output, cb));

  }).on('error', (e) => {
    cb(e);
  });
}
*/
