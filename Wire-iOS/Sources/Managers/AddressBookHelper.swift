//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import Contacts

protocol AddressBookHelperProtocol: class {
    var isAddressBookAccessGranted : Bool { get }
    var isAddressBookAccessUnknown : Bool { get }
    var addressBookSearchPerformedAtLeastOnce : Bool { get set }
    var isAddressBookAccessDisabled : Bool { get }
    var accessStatusDidChangeToGranted: Bool { get }
    var addressBookSearchWasPostponed : Bool { get set }
    
    /// Configuration override (used for testing)
    var configuration : AddressBookHelperConfiguration! { get set }
    
    static var sharedHelper : AddressBookHelperProtocol { get }
    
    func startRemoteSearch(_ onlyIfEnoughTimeSinceLast: Bool)
    
    func requestPermissions(_ callback: ((Bool)->())?)
    func persistCurrentAccessStatus()
}

/// Allows access to address book for search
final class AddressBookHelper : AddressBookHelperProtocol {
    
    /// Time to wait between searches
    let searchTimeInterval : TimeInterval = 60 * 60 * 24 // 24h
    
    /// Singleton
    static var sharedHelper : AddressBookHelperProtocol = AddressBookHelper()
    
    /// Configuration override (used for testing)
    var configuration : AddressBookHelperConfiguration!

// MARK: - Permissions
    
    var isAddressBookAccessUnknown : Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .notDetermined
    }
    
    var isAddressBookAccessGranted : Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    var isAddressBookAccessDisabled : Bool {
        return CNContactStore.authorizationStatus(for: .contacts) == .denied
    }
    
    /// Request access to the user. Will asynchronously invoke the callback passing as argument
    /// whether access was granted.
    func requestPermissions(_ callback: ((Bool)->())?) {
        CNContactStore().requestAccess(for: .contacts, completionHandler: { [weak self] authorized, _ in
            DispatchQueue.main.async {                
                self?.persistCurrentAccessStatus()
                callback?(authorized)
            }
        })
    }
    
    /// Whether enough time has passed since last search to request a new search
    fileprivate var enoughTimeHasPassedForSearch : Bool {
        guard let lastSearchDate = UserDefaults.standard.object(forKey: addressBookLastSearchDate) as? Date else {
            return true
        }
        // Date check
        let timeSinceLastSearch = Date().timeIntervalSince(lastSearchDate)
        let customTimeLimit : TimeInterval
        if let timeLimitInConfiguration = self.configuration?.addressBookRemoteSearchTimeInterval, timeLimitInConfiguration > 0 {
            customTimeLimit = timeLimitInConfiguration
        } else {
            customTimeLimit = self.searchTimeInterval
        }
        return timeSinceLastSearch > customTimeLimit
    }
    
    /// Whether the address book search was performed at least once
    var addressBookSearchPerformedAtLeastOnce : Bool {
        get {
            return UserDefaults.standard.bool(forKey: addressBookSearchPerfomedAtLeastOnceKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: addressBookSearchPerfomedAtLeastOnceKey)
        }
    }
    
    /// Whether the user skipped address book search
    var addressBookSearchWasPostponed : Bool {
        get {
            return UserDefaults.standard.bool(forKey: addressBookSearchWasPostponedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: addressBookSearchWasPostponedKey)
        }
    }

// MARK: – Access Status Change Detection

    func persistCurrentAccessStatus() {
        let status = CNContactStore.authorizationStatus(for: .contacts).rawValue as Int
        UserDefaults.standard.set(NSNumber(value: status), forKey: addressBookLastAccessStatusKey)
    }

    private var lastAccessStatus: CNAuthorizationStatus? {
        guard let value = UserDefaults.standard.object(forKey: addressBookLastAccessStatusKey) as? NSNumber else { return nil }
        return CNAuthorizationStatus(rawValue: value.intValue)
    }

    var accessStatusDidChangeToGranted: Bool {
        guard let lastStatus = lastAccessStatus else { return false }
        return CNContactStore.authorizationStatus(for: .contacts) != lastStatus && isAddressBookAccessGranted
    }


// MARK: - Upload
    
    /// Starts an address book search, if enough time has passed since last search
    func startRemoteSearch(_ onlyIfEnoughTimeSinceLast: Bool) {
        assert(!ZMUser.selfUser().hasTeam, "Trying to upload contacts for account with team is a forbidden operation")

        guard self.isAddressBookAccessGranted && !self.addressBookSearchWasPostponed && (!onlyIfEnoughTimeSinceLast || self.enoughTimeHasPassedForSearch) else {
            return
        }
        self.addressBookSearchWasPostponed = false;
        self.addressBookSearchPerformedAtLeastOnce = true;
        
        if !UIDevice.isSimulator || (self.configuration?.shouldPerformAddressBookRemoteSearchEvenOnSimulator ?? false) {
            ZMUserSession.shared()?.uploadAddressBookIfAllowed()
        }
        UserDefaults.standard.set(Date(), forKey: addressBookLastSearchDate)
    }
}

// MARK: - Constants

private let addressBookLastSearchDate = "UserDefaultsKeyAddressBookExportDate"
private let addressBookSearchPerfomedAtLeastOnceKey = "AddressBookWasUploaded"
private let addressBookSearchWasPostponedKey = "AddressBookUploadWasPostponed"
private let addressBookLastAccessStatusKey = "AddressBookLastAccessStatus"

// MARK: - Testing
protocol AddressBookHelperConfiguration {

    /// Whether the remote search using address book should be performed also on simulator
    var shouldPerformAddressBookRemoteSearchEvenOnSimulator : Bool { get }
    
    /// Overriding interval between remote search
    var addressBookRemoteSearchTimeInterval : TimeInterval { get }
}

