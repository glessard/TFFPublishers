//
//  Lock.swift
//
//  Created by Guillaume Lessard on 6/7/20.
//

import Darwin

extension UnsafeMutablePointer where Pointee == os_unfair_lock_s
{
  init()
  {
    let lock = Self.allocate(capacity: 1)
    lock.initialize(to: os_unfair_lock())
    self = lock
  }

  func clean()
  {
    deinitialize(count: 1)
    deallocate()
  }

  func lock()
  {
    os_unfair_lock_lock(self)
  }

  func unlock()
  {
    os_unfair_lock_unlock(self)
  }
}

typealias Lock = UnsafeMutablePointer<os_unfair_lock_s>
