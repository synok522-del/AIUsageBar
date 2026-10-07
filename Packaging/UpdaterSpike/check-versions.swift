import Foundation
import Sparkle
let comparator = SUStandardVersionComparator()
precondition(comparator.compareVersion("9001", toVersion: "9002") == .orderedAscending)
precondition(comparator.compareVersion("9002", toVersion: "9002") == .orderedSame)
precondition(comparator.compareVersion("9002", toVersion: "9001") == .orderedDescending)
print("PASS: Sparkle 2.10.0 comparator: newer, same, lower. This is not host discovery evidence.")
