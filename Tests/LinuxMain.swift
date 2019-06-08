import XCTest

import FaultTests

var tests = [XCTestCaseEntry]()
tests += FaultTests.allTests()
XCTMain(tests)
