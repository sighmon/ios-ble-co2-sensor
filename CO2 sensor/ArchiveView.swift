//
//  ArchiveView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 21/8/2022.
//

import SwiftUI
import CoreData

struct ArchiveView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Measurement.timestamp, ascending: false)],
        animation: .default)
    private var measurements: FetchedResults<Measurement>
    
    var body: some View {
        List {
            ForEach(measurements) { measurement in
                NavigationLink {
                    Text("\(Int(measurement.co2)) ppm\n\(String(format: "%.1f", measurement.temperature)) °C\n\(Int(measurement.humidity)) % \n\n\(measurement.timestamp!, formatter: dateFormatter)")
                } label: {
                    Text("\(Int(measurement.co2)) ppm, \(String(format: "%.1f", measurement.temperature)) °C, \(Int(measurement.humidity)) %")
                }
            }
            .onDelete(perform: deleteMeasurements)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
    }
    
    private func deleteMeasurements(offsets: IndexSet) {
        withAnimation {
            offsets.map { measurements[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct ArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
