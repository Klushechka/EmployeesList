//
//  LocalContactsService.swift
//  Employees
//
//  Created by Olga Kliushkina on 31.05.2020.
//  Copyright © 2020 Olga Kliushkina. All rights reserved.
//

import Foundation
import Contacts
import ContactsUI

final class LocalContactsService {
    
    var permissionRequestNeeded: (() -> Void)?
    var localContacts: [CNContact]?
    var formattedContactsNames: [String]?
    
    func localContactsNames() -> [String]? {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            self.permissionRequestNeeded?()
            //presentSettingsActionSheet()
            return nil
        }

        // open it

        let store = CNContactStore()
        store.requestAccess(for: .contacts) { [weak self] granted, error in
            guard let self = self else { return }
            
            guard granted else {
                DispatchQueue.main.async {
                    self.permissionRequestNeeded?()
                }
                return
            }

            // get the contacts

            var contacts = [CNContact]()
            let request = CNContactFetchRequest(keysToFetch: [CNContactIdentifierKey as NSString, CNContactFormatter.descriptorForRequiredKeys(for: .fullName)])
            do {
                try store.enumerateContacts(with: request) { contact, stop in
                    contacts.append(contact)
                }
            } catch {
                print(error)
            }

            // do something with the contacts array (e.g. print the names)
            
            self.localContacts = contacts
            
            let formatter = CNContactFormatter()
            formatter.style = .fullName
            
            let formattedContacts: [String]? = contacts.compactMap { formatter.string(from: $0)?.lowercased()
            }
            
            self.formattedContactsNames = formattedContacts
        }
        
        return formattedContactsNames
    }
    
    func contact(with fullName: String) -> CNContact? {
        var results: [CNContact] = []
        do {
            let contactStore = CNContactStore()
            
            let request:CNContactFetchRequest
            request = CNContactFetchRequest(keysToFetch: [CNContactGivenNameKey as NSString, CNContactFamilyNameKey as NSString, CNContactViewController.descriptorForRequiredKeys()])
            request.predicate = CNContact.predicateForContacts(matchingName: fullName)
            try contactStore.enumerateContacts(with: request) {
                (contact, cursor) -> Void in
                results.append(contact)
                }
        }
        catch{
            print("Handle the error please")
        }
        
        return results.first
    }
    
}