//
//  EmployeesListController.swift
//  Employees
//
//  Created by Olga Kliushkina on 27.05.2020.
//  Copyright © 2020 Olga Kliushkina. All rights reserved.
//

import Foundation
import Contacts

final class EmployeeListViewModelImpl: EmployeesListViewModel, LocalContactsViewModel {
    
    var employees: [Employee]? {
        didSet {
            self.employeesListUpdated?()
        }
    }
    
    var positions: [String]? {
        didSet {
            self.employeesListUpdated?()
        }
    }
    
    var positionsForSearchResults: [String]? {
        didSet {
            self.isSearchRefreshCompleted = true
            
            self.employeesListUpdated?()
        }
    }
    
    var employeesMatchingQuery: [Employee]? {
        didSet {
            self.employeesListUpdated?()
        }
    }
    
    var localContactsNames: [String]? {
        didSet {
            if self.localContactsNames != oldValue {
                self.localContactsListUpdated?()
            }
        }
    }
    
    var localContactsService: LocalContactsService?
    
    var isSearchRefreshCompleted: Bool = false
    
    var employeesListUpdated: (() -> Void)?
    var localContactsListUpdated: (() -> Void)?
    var errorOccured: (() -> Void)?
    
    private var employeesOperation: EmployeesOperation?
    private var networkManager: NetworkManager?
    private var dataStorageManager: DataStorageManager?
    
    init() {
        setUpManagers()
        fetchEmployees()
        fetchLocalContacts()
    }
    
    private func setUpManagers() {
        self.networkManager = NetworkManager()
        self.dataStorageManager = DataStorageManager()
    }
    
    private func fetchEmployees() {
        if let storedEmployees = fetchStoredEmployees() {
            self.employees = storedEmployees
            self.setUpPositions()
        }
        
        downloadEmployees()
    }
    
    private func fetchStoredEmployees() -> [Employee]? {
        guard let dataStorageManager = self.dataStorageManager else { return nil }
        
        return dataStorageManager.retrieveData(fileName: .employees, dataType: [Employee].self)
    }
    
    func downloadEmployees(completion: (() -> Void)? = nil) {
        guard let networkManager = self.networkManager, let dataStorageManager = self.dataStorageManager else { return }
        self.employeesOperation = networkManager.createOperation(EmployeesOperation.self, dataStorageManager: dataStorageManager) as? EmployeesOperation
        
        guard let employeesOperation = self.employeesOperation, employeesOperation.isReadyToLoadData else { return }
        
        networkManager.requestData(operation: employeesOperation) { [weak self] employees, requestDidSucceed, error in
            guard let self = self else { return }
            
            guard let allEmployees = employees as? [Employee], requestDidSucceed else {
                self.errorOccured?()
                
                return
            }
            
            if completion != nil {
                self.isSearchRefreshCompleted = false
            }
            
            self.employees = allEmployees
            
            self.setUpPositions()
            
            completion?()
        }
    }
    
    private func setUpPositions(isSearchActive: Bool = false) {
        var employeesList: [Employee]?
        
        switch isSearchActive {
        case true: employeesList = self.employeesMatchingQuery
        case false: employeesList = self.employees
        }
        
        guard let employees = employeesList else { return }
        
        var allPositions = [String]()
        
        for employee in employees as [Employee] {
            if !allPositions.contains(employee.position) {
                allPositions.append(employee.position)
            }
        }
        
        let sortedPositions = allPositions.sorted(by: { $0 < $1 })
        
        if isSearchActive {
            self.positionsForSearchResults = sortedPositions
            
            return
        }
        
        self.positions = sortedPositions
    }
    
    func employeesWithPosition(positionSection: Int, isSearchActive: Bool = false) -> [Employee]? {
        let emploeesList = isSearchActive ? self.employeesMatchingQuery : self.employees
        
        guard let employees = emploeesList else { return nil }
        
        let positions = isSearchActive ?  self.positionsForSearchResults : self.positions
        
        guard let allPositions = positions, positionSection < allPositions.count else { return nil }
        
        let employeesWithParticularPosition = employees.filter( { $0.position == allPositions[positionSection] })
        
        return employeesWithParticularPosition.sorted(by: { $0.surname < $1.surname })
    }
    
}

extension EmployeeListViewModelImpl {
    
    internal func fetchLocalContacts() {
        self.localContactsService = LocalContactsService()
        
        guard let localContactsService = self.localContactsService else { return }
        
        localContactsService.localContactsNames { [weak self] localContactsNames in
            if let self = self {
                self.localContactsNames = localContactsNames
            }
        }
    }
    
    func isEmployeeInLocalContacts(employee: Employee) -> Bool {
        guard let localContactsNames = self.localContactsNames else { return false }
        
        let fullName = String("\(employee.name) \(employee.surname)").lowercased()
        
        return localContactsNames.contains(fullName)
    }
    
    func localContact(fullName: String) -> CNContact? {
        guard let localContact = self.localContactsService?.contact(with: fullName) else {
            self.errorOccured?()
            return nil
        }
        
        return localContact
    }
    
}

extension EmployeeListViewModelImpl {
    
    func filterEmployeesMatching(query: String?) {
        guard let searchQuery = query, searchQuery.count > 0 else {
            return
        }
        guard let employees = self.employees, employees.count > 0 else {
            return
        }
        
        let lowercasedSearchQuery = searchQuery.lowercased()
        
        self.employeesMatchingQuery = employees.filter {
            $0.name.lowercased().range(of: lowercasedSearchQuery) != nil ||
                $0.surname.lowercased().range(of: lowercasedSearchQuery) != nil ||
                
                $0.contactDetails.email.lowercased().range(of: lowercasedSearchQuery) != nil ||
                $0.contactDetails.phone?.range(of: lowercasedSearchQuery) != nil ||
                
                $0.position.lowercased().range(of: lowercasedSearchQuery) != nil ||
                
                $0.projects?.contains(where: {
                    $0.lowercased().range(of: lowercasedSearchQuery) != nil
                }) ?? false
        }
        
        setUpPositions(isSearchActive: true)
    }
    
}
