//
//  MovieApp.swift
//  Movie
//
//  Created by Daikin Electronic Devices Malaysia on 28/01/2024.
//

import SwiftUI

@main
struct MovieApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
