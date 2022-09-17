//
//  ContentView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 31/7/2022.
//

import SwiftUI
import CoreData

var backgroundColour = false

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @StateObject var bleController = BLEController()
    @StateObject var locationManager = LocationManager()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Measurement.timestamp, ascending: true)],
        animation: .default)
    private var measurements: FetchedResults<Measurement>

    var body: some View {
        NavigationView {
            ZStack {
                // Background colour
                // Color(red: 0.9, green: 0.9, blue: 0.9).edgesIgnoringSafeArea(.all)
                GeometryReader { geometry in
                    // Background CO2 reading gauge
                    Rectangle()
                        .foregroundColor(co2Colour(co2: bleController.co2Value))
                        .opacity(0.3)
                        .ignoresSafeArea(.all)
                        .frame(
                            width: geometry.size.width,
                            height: backgroundHeight(
                                co2: bleController.co2Value,
                                height: Int(geometry.size.height)
                            )
                        )
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height - (backgroundHeight(
                                co2: bleController.co2Value,
                                height: Int(geometry.size.height)
                            ) / 2)
                        )
                }
                VStack {
                    Text("\(bleController.co2Value)")
                        .padding(.top, -60)
                        .onTapGesture {
                            backgroundColour = !backgroundColour
                        }
                    Text("ppm CO₂")
                        .font(.system(size: 30, weight: .light))
                        .padding(.bottom, 60)
                    Text("\(bleController.temperatureValue, specifier: "%.1f") °C")
                        .font(.system(size: 30, weight: .light))
                    Text("\(bleController.humidityValue, specifier: "%.1f") %")
                        .font(.system(size: 30, weight: .light))
                        .padding(1)
                    if bleController.isHistoryMode {
                        Text("⏱   \(bleController.historicReadingNumber)")
                            .font(.system(size: 20, weight: .light))
                            .padding([.bottom, .top], 60)
                    } else {
                        Text("📡   \(bleController.rssiValue)")
                            .font(.system(size: 20, weight: .light))
                            .padding([.bottom, .top], 60)
                    }
                    HStack {
                        Button("Save", action: addMeasurement)
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.secondary)
                            .buttonStyle(.bordered)
                        if bleController.isHistoryMode {
                            Button("Live", action: liveMode)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.secondary)
                                .buttonStyle(.bordered)
                        } else {
                            Button("History", action: historicMode)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.secondary)
                                .buttonStyle(.bordered)
                        }
                        if bleController.isSoundOn {
                            Button("Silent", action: toggleSound)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.secondary)
                                .buttonStyle(.bordered)
                        } else {
                            Button("Sound", action: toggleSound)
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.secondary)
                                .buttonStyle(.bordered)
                        }
                        NavigationLink(destination: ArchiveView()) {
                            Text("Archive")
                                .font(.system(size: 20, weight: .light))
                                .foregroundColor(.secondary)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .font(.system(size: 80, weight: .medium))
            .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
        .navigationViewStyle(.stack)
    }

    private func addMeasurement() {
        withAnimation {
            let newMeasurement = Measurement(context: viewContext)
            newMeasurement.timestamp = Date()
            newMeasurement.co2 = Int16(bleController.co2Value)
            newMeasurement.humidity = Float(bleController.humidityValue)
            newMeasurement.temperature = Float(bleController.temperatureValue)
            newMeasurement.latitude = locationManager.lastLocation?.coordinate.latitude ?? 0
            newMeasurement.longitude = locationManager.lastLocation?.coordinate.longitude ?? 0

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
    
    private func historicMode() {
        bleController.co2Value = 0
        bleController.temperatureValue = 0
        bleController.humidityValue = 0
        bleController.rssiValue = 0
        bleController.historicReadingNumber = 0
        bleController.historicMode()
    }

    private func liveMode() {
        bleController.co2Value = 0
        bleController.temperatureValue = 0
        bleController.humidityValue = 0
        bleController.rssiValue = 0
        bleController.historicReadingNumber = 0
        bleController.liveMode()
    }

    private func toggleSound() {
        bleController.isSoundOn = !bleController.isSoundOn
    }

    private func co2Colour(co2: Int) -> Color {
        let colour = Color(.systemGreen)
        if co2 == 0 || !backgroundColour {
            return colour.opacity(0)
        }
        if co2 > 850 && co2 < 1500 {
            return Color(.systemOrange)
        }
        if co2 > 1500 {
            return Color(.systemRed)
        }
        return colour
    }

    private func backgroundHeight(co2: Int, height: Int) -> CGFloat {
        return CGFloat(height) * CGFloat(co2) / 2000
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).previewInterfaceOrientation(.portrait)
    }
}
