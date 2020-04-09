//
//  Operations.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 04.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation
import AVFoundation

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
