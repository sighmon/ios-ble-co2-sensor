//
//  ArchiveDetailView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 28/8/2022.
//

import SwiftUI
import MapKit

struct ArchiveDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    var measurement: Measurement

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 37.334_900,
            longitude: -122.009_020
        ),
        latitudinalMeters: 750,
        longitudinalMeters: 750
    )

    var body: some View {
        VStack {
            Map(coordinateRegion: $region)
                .onAppear {
                    setRegion(CLLocationCoordinate2D(
                        latitude: measurement.latitude,
                        longitude: measurement.longitude)
                    )
                }
                .padding(.top, 0)
                .ignoresSafeArea()
            Text("\(measurement.co2)")
                .padding(.top, 0)
            Text("ppm CO₂")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 30)
            Text("\(measurement.temperature, specifier: "%.1f") °C")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 10)
            Text("\(measurement.humidity, specifier: "%.1f") %")
                .font(.system(size: 30, weight: .light))
                .padding(.bottom, 30)
            Text("\(measurement.timestamp ?? Date(), formatter: dateFormatter)")
                .font(.system(size: 20, weight: .light))
                .padding(.bottom, 30)
        }
        .font(.system(size: 80, weight: .medium))
    }

    private func setRegion(_ coordinate: CLLocationCoordinate2D) {
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 0.005,
                    longitudeDelta: 0.005
                )
            )
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
