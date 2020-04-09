//
//  AsyncOperation.swift
//  ripper
//
//  Created by Mikhail Kulichkov on 09.04.2020.
//  Copyright © 2020 Kulichkov. All rights reserved.
//

import Foundation

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
