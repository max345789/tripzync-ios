//
//  TripzyncApp.swift
//  Tripzync
//
//  Created by sarath c on 18/02/26.
//

import SwiftUI
import CoreData

@main
struct TripzyncApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
