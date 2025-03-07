//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import XCTest
import Wire
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes
import AppCenterDistribute
import WireCommonComponents

class AnalyticsTests : XCTestCase {

    func testThatItSetsOptOutOnAppCenter() {
        // GIVEN
        TrackingManager.shared.disableCrashAndAnalyticsSharing = false
        
        // WHEN
        TrackingManager.shared.disableCrashAndAnalyticsSharing = true
        
        // THEN
        XCTAssertFalse(MSCrashes.isEnabled())
    }
    
    func testThatItSetsOptOutToSharedSettings() {
        // GIVEN
        TrackingManager.shared.disableCrashAndAnalyticsSharing = false
        // THEN
        XCTAssertFalse(ExtensionSettings.shared.disableCrashAndAnalyticsSharing)
        // WHEN
        TrackingManager.shared.disableCrashAndAnalyticsSharing = true
        // THEN
        XCTAssertTrue(ExtensionSettings.shared.disableCrashAndAnalyticsSharing)
    }
    
}
