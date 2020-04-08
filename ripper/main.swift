//
//  main.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 01.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

typealias Path = String

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
			console.writeMessage("Master file downloaded")

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

			//			let videoFile = try? FileHandle(forWritingTo: URL(fileURLWithPath: videoOutputPath))
			//			videoFile?.seekToEndOfFile()
			//			defer { videoFile?.closeFile() }

			// Video processing
			console.writeMessage("Starting download video...")
			let videoPaths = downloadMedia(video, to: videoSegmentsFolder, baseURL: mediaBaseURL)

			console.writeMessage("Video downloaded. Starting merging video segments...")

			mergeMediaFiles(
				videoPaths,
				to: videoOutputPath,
				withInitData: Data(base64Encoded: videoBase64String))
			console.writeMessage("Video merged.")

			console.writeMessage("Deleting video segment folder...")
			do {
				try FileManager.default.removeItem(atPath: videoSegmentsFolder)
				console.writeMessage("Video segment folder deleted")
			} catch {
				console.writeMessage(error.localizedDescription, to: .error)
			}

			// Audio processing
			console.writeMessage("Starting download audio...")
			let audioPaths = downloadMedia(audio, to: audioSegmentsFolder, baseURL: mediaBaseURL)

			console.writeMessage("Audio downloaded. Starting merging audio segments...")

			mergeMediaFiles(
				audioPaths,
				to: audioOutputPath,
				withInitData: Data(base64Encoded: audioBase64String))
			console.writeMessage("audio merged.")

			console.writeMessage("Deleting audio segment folder...")
			do {
				try FileManager.default.removeItem(atPath: audioSegmentsFolder)
				console.writeMessage("Audio segment folder deleted")
			} catch {
				console.writeMessage(error.localizedDescription, to: .error)
			}

		case .failure(let error):
			print(error)
		}
	}
} else {
	printUsage()
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
