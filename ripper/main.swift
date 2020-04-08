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
			let videoOutputPath = currentPath + "/\(master.clip_id).m4v"
			let audioOutputPath = currentPath + "/\(master.clip_id).m4a"
			let masterURL = URL(string: masterURL)!

			let video = master.video.sorted { $0.bitrate > $1.bitrate }.first!

			let videoURL = masterURL
				.withoutLastPathComponent()
				.resolved(to: master.base_url)
				.resolved(to: video.base_url)

			let base64String = video.init_segment

			FileManager.default.createFile(atPath: videoOutputPath, contents: Data(base64Encoded: base64String))
			let videoFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: videoOutputPath))
			videoFile?.seekToEndOfFile()
			defer { videoFile?.closeFile() }

			let operations = video.segments.map { (segment) -> MediaDownloader in
				let segmentURL = videoURL.resolved(to: segment.url)
				return MediaDownloader(url: segmentURL) { data in
					guard let data = data else {
						console.writeMessage("no data for \(segmentURL)")
						return
					}
					videoFile?.write(data)
					console.writeMessage("data written for \(segmentURL)", sameLine: true) } }

			let queue = OperationQueue()
			queue.maxConcurrentOperationCount = 1
			queue.addOperations(operations, waitUntilFinished: true)

		case .failure(let error):
			print(error)
		}
	}
} else {
	printUsage()
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
