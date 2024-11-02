// Copyright (C) 2019 The American University in Cairo
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import CThreadPool
import Foundation

var pool: threadpool?

public class Future {
  static var pool: threadpool?

  private var semaphore: DispatchSemaphore
  private var store: Any?
  private var executor: () -> Any

  init(executor: @escaping () -> Any) {
    semaphore = DispatchSemaphore(value: 0)
    self.executor = executor

    if Future.pool == nil {
      Future.pool = thpool_init(
        CInt(
          ProcessInfo.processInfo.environment["FAULT_THREADS"] ?? ""
        ) ?? CInt(clamping: ProcessInfo.processInfo.processorCount))
    }

    _ = thpool_add_work(
      Future.pool!,
      {
        pointer in
        let this = Unmanaged<Future>.fromOpaque(pointer!).takeUnretainedValue()
        this.store = this.executor()
        this.semaphore.signal()
      }, Unmanaged.passUnretained(self).toOpaque()
    )
  }

  public var value: Any {
    semaphore.wait()
    let value = store!
    return value
  }
}
