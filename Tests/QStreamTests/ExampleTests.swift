//
//  ExampleTests.swift
//  QStream
//
//  Created by Quirin Schweigert on 25.01.26.
//

import XCTest
@testable import QStream
import SwiftUI

struct Contact: Sendable {
    enum Category: Sendable { case friends, business }

    let name: String
    let category: Category
}

actor DatabaseService {
//    var storedContacts: [Contact]
    
    let storedContacts: Subject<[Contact]> = .init(value: [])

    func contacts() -> some QStream.Stream<[Contact]> {
        storedContacts
    }
}

actor ExampleViewModel: ViewModel {
    let databaseService = DatabaseService()

    let filterTerm: Subject<String?> = .init(value: nil)
    let selectedCategory: Subject<Contact.Category?>

    var subscriptions: [AnySubscription] = []

    init(selectedCategory: Subject<Contact.Category?>) async {
        self.selectedCategory = selectedCategory
        
        await databaseService
            .contacts()
            .combineLatest(filterTerm, selectedCategory)
            .map { contacts, filterTerm, selectedCategory in
                contacts
                    .filter { if let filterTerm { $0.name.contains(filterTerm) } else { true } }
                    .filter { if let selectedCategory { $0.category == selectedCategory } else { true } }
            }
            .tap { contactsToDisplay in
                print("contacts to display: \(contactsToDisplay.map(\.name))")
            }
            .store(in: &subscriptions)
    }

    func simulateChanges() async throws {
        let delay: Duration = .seconds(3)

        try await Task.sleep(for: delay)
        print("— Adding contacts")
        await databaseService.storedContacts.set([
            Contact(name: "Alice", category: .friends),
            Contact(name: "Bob", category: .business),
            Contact(name: "Charlie", category: .friends),
            Contact(name: "Diana", category: .business),
        ])
        
        try await Task.sleep(for: delay)
        print("— Filter by category: .friends")
        await selectedCategory.set(.friends)
        
        try await Task.sleep(for: delay)
        print("— Filter by name: \"Ali\"")
        await filterTerm.set("Ali")
        
        try await Task.sleep(for: delay)
        print("— Clear category filter")
        await selectedCategory.set(nil)
        
        try await Task.sleep(for: delay)
        print("— Clear all filters")
        await filterTerm.set(nil)
        
        try await Task.sleep(for: delay)
        print("— Delete Bob")
        await databaseService.storedContacts.mutate { $0.removeAll(where: { $0.name == "Bob" }) }
    }
    
    func trigger(input: ContactView.Input) {
        switch input {
        case .setFilterCategory(let category):
            Task { await selectedCategory.set(<#T##value: Contact.Category?##Contact.Category?#>) }
        }
    }
}

struct ContactView: View {
    struct ViewState {
        struct Contact {
            enum Category {
                case friends
            }
            
            let name: String
            let category: Category
        }
        
        var contacts: [Contact]
    }
    
    enum Input {
        case setFilterCategory(ViewState.Contact.Category)
        
    }
    
//    @ObservableObject viewModel: AnyViewModel<ViewState, Input>
    
    var body: some View {
        Button { viewModel.trigger(.setFilterCategory(.friends)) } label: {
            Text("")
        }
    }
}

actor CategoryViewModel {
    let selectedCategory: Subject<Contact.Category?> = .init()
    
    let exampleViewModel: ExampleViewModel
    
    init() async {
        exampleViewModel = await ExampleViewModel(selectedCategory: selectedCategory)
        
        
//        selectedCategory.tap { }
    }
}

final class ExampleTests: XCTestCase {
    func testExample() {
        let expectation = self.expectation(description: "Example completed")

//        Task {
//            let exampleViewModel = await ExampleViewModel()
//            try await exampleViewModel.simulateChanges()
//            expectation.fulfill()
//        }

        wait(for: [expectation], timeout: 100)
    }
    
    //await signedInUserID
    //    .map { signedInUserID in await databaseService.contacts(for: signedInUserID) }
    //    .switchToLatest()
    //    .contacts()
    //    .combineLatest(filterTerm, selectedCategory)
    //    .map { contacts, filterTerm, selectedCategory in
    //        contacts
    //            .filter { if let filterTerm { $0.name.contains(filterTerm) } else { true } }
    //            .filter { if let selectedCategory { $0.category == selectedCategory } else { true } }
    //    }
    //    .tap { contactsToDisplay in
    //        print("contacts to display: \(contactsToDisplay.map(\.name))")
    //    }
    //    .store(in: &subscriptions)

    //    await filterTerm.debounce(for: .milliseconds(500))
    //        .map { filterTerm in
    //            fetchRemote(filterTerm)
    //        }
    //        .switchToLatest()

    
    
    
    
    
    
    
    func testSimpleDemo() async {
        let b: Subject<Int> = .init(value: 1)
        
        let subscription = await b.tap {
            print("value of b: \($0)")
        }

        
        
        
        
//        let c: Subject<Int> = .init(value: 2)
        
        
//        let a = await b.combineLatest(c).map { $0 + $1 }
        
//        let subscription = await a.tap { print("value of a: \($0)") }
        
        try? await Task.sleep(for: .seconds(3))
    
        print("setting b = 10 now")
        await b.set(10)
        
        withExtendedLifetime(subscription) { }
    }
}

