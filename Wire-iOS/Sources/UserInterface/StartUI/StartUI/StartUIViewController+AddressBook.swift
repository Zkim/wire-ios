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

extension StartUIViewController {

    var needsAddressBookPermission: Bool {
        let shouldSkip = AutomationHelper.sharedHelper.skipFirstLoginAlerts || ZMUser.selfUser().hasTeam
        return !AddressBookHelper.sharedHelper.isAddressBookAccessGranted && !shouldSkip
    }

    func presentShareContactsViewController() {
        let shareContactsViewController = ShareContactsViewController()
        shareContactsViewController.delegate = self
        navigationController?.pushViewController(shareContactsViewController, animated: true)
    }

    func handleUploadAddressBookLogicIfNeeded() {
        guard !addressBookUploadLogicHandled else { return }

        addressBookUploadLogicHandled = true

        // We should not even try to access address book when in a team
        guard !ZMUser.selfUser().hasTeam else { return }

        if addressBookHelper.isAddressBookAccessGranted {
            // Re-check if we need to start AB search
            addressBookHelper.startRemoteSearch(true)
        } else if addressBookHelper.isAddressBookAccessUnknown {
            self.addressBookHelper.requestPermissions({ success in
                if success {
                    DispatchQueue.main.async(execute: {
                        self.addressBookHelper.startRemoteSearch(true)
                    })
                }
            })
        }
    }
}

extension StartUIViewController: ShareContactsViewControllerDelegate {

    func shareDidFinish(_ viewController: UIViewController) {
        viewController.dismiss(animated: true)
    }

    func shareDidSkip(_ viewController: UIViewController) {
        dismiss(animated: true) {
            UIApplication.shared.topmostViewController()?.presentInviteActivityViewController(with: self.quickActionsBar)
        }
    }
}
