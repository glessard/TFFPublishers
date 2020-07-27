//
//  Lock.swift
//
//  Created by Guillaume Lessard on 6/7/20.
//

import Darwin

internal struct Lock
{
  private let pl: UnsafeMutablePointer<os_unfair_lock_s>

  private init()
  {
    pl = UnsafeMutablePointer.allocate(capacity: 1)
  }

  static func allocate() -> Lock
  {
    return Lock()
  }

  func deallocate()
  {
    pl.deinitialize(count: 1)
    pl.deallocate()
  }

  func lock()
  {
    os_unfair_lock_lock(pl)
  }

  func unlock()
  {
    os_unfair_lock_unlock(pl)
  }
}
