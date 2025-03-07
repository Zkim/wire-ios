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

extension UIViewController {

    /// return the default supported interface orientations of a view controller
    /// return .all only if the idiom is .pad and size class is .regular
    var wr_supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch (UIDevice.current.userInterfaceIdiom, traitCollection.horizontalSizeClass) {
        case (.pad, .regular),
             // Notice: for iPad with iOS9 in landscape mode, horizontalSizeClass is .unspecified (it is .regular in iOS11).
             (.pad, .unspecified):
            return .all
        default:
            return .portrait
        }
    }
}

