//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

@objc
protocol ZMUserSessionInterface: NSObjectProtocol {
    
    @objc(performChanges:)
    func perform(_ changes: @escaping () -> ())
    
    @objc(enqueueChanges:)
    func enqueue(_ changes: @escaping () -> ())
    
    @objc(enqueueChanges:completionHandler:)
    func enqueue(_ changes: @escaping () -> Void, completionHandler: (() -> Void)!)

    var isNotificationContentHidden : Bool { get set }
}

// an interface for ZMUserSession's Swift-only functions
protocol UserSessionSwiftInterface: ZMUserSessionInterface {
    var conversationDirectory: ConversationDirectoryType { get }
}

extension ZMUserSession: UserSessionSwiftInterface {}
