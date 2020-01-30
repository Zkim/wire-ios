
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
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

///TODO: non optional
@objc
protocol TokenFieldDelegate: NSObjectProtocol {
    @objc optional func tokenField(_ tokenField: TokenField, changedTokensTo tokens: [Token])
    @objc optional func tokenField(_ tokenField: TokenField, changedFilterTextTo text: String)
    @objc optional func tokenFieldDidBeginEditing(_ tokenField: TokenField)
    @objc optional func tokenFieldWillScroll(_ tokenField: TokenField)
    @objc optional func tokenFieldDidConfirmSelection(_ controller: TokenField)
    @objc optional func tokenFieldString(forCollapsedState tokenField: TokenField) -> String
}
