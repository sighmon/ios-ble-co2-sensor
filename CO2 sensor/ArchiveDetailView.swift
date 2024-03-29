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
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    var measurement: Measurement

    @State private var region: MKCoordinateRegion = {
        let initialCoordinate = CLLocationCoordinate2D(
            latitude: 37.334_900,
            longitude: -122.009_020
        )
        return MKCoordinateRegion(
            center: initialCoordinate,
            latitudinalMeters: 750,
            longitudinalMeters: 750
        )
    }()

    init(measurement: Measurement) {
        self.measurement = measurement
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: measurement.latitude,
                longitude: measurement.longitude
            ),
            latitudinalMeters: 750,
            longitudinalMeters: 750
        ))
    }

    var body: some View {
        ZStack {
            VStack {
                Map(coordinateRegion: $region, annotationItems: [measurement]) {_ in
                    MapMarker(coordinate: CLLocationCoordinate2D(
                        latitude: measurement.latitude,
                        longitude: measurement.longitude
                    ))
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
            LinearGradient(
                gradient: Gradient(
                    colors: getColours()
                ),
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.2)
            )
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    func getColours() -> Array<Color> {
        var colours = Array<Color>()
        if colorScheme == .light {
            colours = [Color.white, Color.white.opacity(0)]
        } else {
            colours = [Color.black, Color.black.opacity(0)]
        }
        return colours
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
