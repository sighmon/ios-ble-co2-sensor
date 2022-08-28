//
//  ArchiveDetailView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 28/8/2022.
//

import SwiftUI

struct ArchiveDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var measurement: Measurement

    var body: some View {
        VStack {
            Text("\(measurement.co2)")
                .padding(.top, -60)
            Text("ppm CO₂")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 60)
            Text("\(measurement.temperature, specifier: "%.1f") °C")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 10)
            Text("\(measurement.humidity, specifier: "%.1f") %")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 10)
            Text("Latitude: \(measurement.latitude)")
                .font(.system(size: 20, weight: .light))
            Text("Longitutde: \(measurement.longitude)")
                .font(.system(size: 20, weight: .light))
                .padding(.bottom, 10)
            Text("\(measurement.timestamp ?? Date(), formatter: dateFormatter)")
                .font(.system(size: 20, weight: .light))
        }
        .font(.system(size: 80, weight: .medium))
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct ArchiveDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ArchiveDetailView(measurement: Measurement(context: PersistenceController.preview.container.viewContext)).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
