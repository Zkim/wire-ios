//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

final class ConversationActionController {
    
    struct PresentationContext {
        let view: UIView
        let rect: CGRect
    }
    
    enum Context {
        case list, details
    }

    private let conversation: ZMConversation
    unowned let target: UIViewController
    var currentContext: PresentationContext?
    weak var alertController: UIAlertController?
    
    init(conversation: ZMConversation, target: UIViewController) {
        self.conversation = conversation
        self.target = target
    }

    func presentMenu(from sourceView: UIView?, context: Context) {
        currentContext = sourceView.map {
            .init(
                view: target.view,
                rect: target.view.convert($0.frame, from: $0.superview).insetBy(dx: 8, dy: 8)
            )
        }
        
        let actions: [ZMConversation.Action]
        switch context {
        case .details:
            actions = conversation.detailActions
        case .list:
            actions = conversation.listActions
        }
        
        let title = context == .list ? conversation.displayName : nil
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        actions.map(alertAction).forEach(controller.addAction)
        controller.addAction(.cancel())
        present(controller)

        alertController = controller
    }
    
    func enqueue(_ block: @escaping () -> Void) {
        ZMUserSession.shared()?.enqueue(block)
    }
    
    func transitionToListAndEnqueue(_ block: @escaping () -> Void) {
        ZClientViewController.shared?.transitionToList(animated: true) {
            ZMUserSession.shared()?.enqueue(block)
        }
    }

    func handleAction(_ action: ZMConversation.Action) {
        switch action {
        case .deleteGroup:
            guard let userSession = ZMUserSession.shared() else { return }

            requestDeleteGroupResult() { result in
                self.handleDeleteGroupResult(result, conversation: self.conversation, in: userSession)
            }
        case .archive(isArchived: let isArchived): self.transitionToListAndEnqueue {
            self.conversation.isArchived = !isArchived
            }
        case .markRead: self.enqueue {
            self.conversation.markAsRead()
            }
        case .markUnread: self.enqueue {
            self.conversation.markAsUnread()
            }
        case .configureNotifications: self.requestNotificationResult(for: self.conversation) { result in
            self.handleNotificationResult(result, for: self.conversation)
        }
        case .silence(isSilenced: let isSilenced): self.enqueue {
            self.conversation.mutedMessageTypes = isSilenced ? .none : .all 
            }
        case .leave: self.request(LeaveResult.self) { result in
            self.handleLeaveResult(result, for: self.conversation)
            }
        case .clearContent: self.requestClearContentResult(for: self.conversation) { result in
            self.handleClearContentResult(result, for: self.conversation)
            }
        case .cancelRequest:
            guard let user = self.conversation.connectedUser else { return }
            self.requestCancelConnectionRequestResult(for: user) { result in
                self.handleConnectionRequestResult(result, for: self.conversation)
            }
        case .block: self.requestBlockResult(for: self.conversation) { result in
            self.handleBlockResult(result, for: self.conversation)
            }
        case .moveToFolder:
            self.openMoveToFolder(for: self.conversation)
        case .removeFromFolder:
            enqueue {
                self.conversation.removeFromFolder()
            }
        case .favorite(isFavorite: let isFavorite):
            enqueue {
                self.conversation.isFavorite = !isFavorite
            }
        case .remove: fatalError()
        }
    }
    
    private func alertAction(for action: ZMConversation.Action) -> UIAlertAction {
        return action.alertAction { [weak self] in
            guard let `self` = self else { return }
            self.handleAction(action)
        }
    }

    func present(_ controller: UIViewController) {
        present(controller,
                currentContext: currentContext,
                target: target)
    }
    
    private func prepare(viewController: UIViewController, with context: PresentationContext) {
        viewController.popoverPresentationController.apply {
            $0.sourceView = context.view
            $0.sourceRect = context.rect
        }
    }
    
    private func present(_ controller: UIViewController,
                 currentContext: PresentationContext?,
                 target: UIViewController) {
        currentContext.apply {
            prepare(viewController: controller, with: $0)
        }
        target.present(controller, animated: true, completion: nil)
    }
    
}
