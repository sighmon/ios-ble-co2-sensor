//
//  ContentView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 31/7/2022.
//

import SwiftUI
import CoreData
import AVFoundation

let kBackgroundColour = "backgroundColour"
let kIsSoundOn = "isSoundOn"

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    @StateObject var bleController = BLEController()
    @StateObject var locationManager = LocationManager()

    @State private var backgroundColour = false
    @State private var showingSettingsSheet = false

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Measurement.timestamp, ascending: true)],
        animation: .default)
    private var measurements: FetchedResults<Measurement>

    init() {
        setupBackgroundAudio()
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Background colour
                // Color(red: 0.9, green: 0.9, blue: 0.9).edgesIgnoringSafeArea(.all)
                GeometryReader { geometry in
                    // Background CO2 reading gauge
                    Rectangle()
                        .foregroundColor(co2Colour(co2: bleController.co2Value))
                        .ignoresSafeArea(.all)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                }
                VStack {
                    Text("\(bleController.co2Value)")
                        .font(.system(size: 80, weight: .medium))
                        .padding(.top, -40)
                        .onTapGesture {
                            backgroundColour = !backgroundColour
                            UserDefaults.standard.set(backgroundColour, forKey: kBackgroundColour)
                        }
                    Text("ppm CO₂")
                        .font(.system(size: 30, weight: .light))
                        .padding(.bottom, 60)
                    HStack {
                        Text("\(bleController.temperatureValue, specifier: "%.1f")")
                            .font(.system(size: 30, weight: .medium))
                        Text("°C")
                            .font(.system(size: 30, weight: .light))
                    }
                    HStack {
                        Text("\(bleController.humidityValue, specifier: "%.1f")")
                            .font(.system(size: 30, weight: .medium))
                        Text("%")
                            .font(.system(size: 30, weight: .light))
                    }
                    .padding(1)
                    HStack {
                        if bleController.isHistoryMode {
                            Text("\(bleController.historicReadingNumber)")
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 40, alignment: .trailing)
                                .onTapGesture {
                                    liveMode()
                                }
                            Image(systemName: "clock")
                                .font(.system(size: 20))
                                .onTapGesture {
                                    liveMode()
                                }
                        } else {
                            Text("\(bleController.rssiValue)")
                                .font(.system(size: 20, weight: .regular))
                                .frame(width: 40, alignment: .trailing)
                                .onTapGesture {
                                    historicMode()
                                }
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 20))
                                .onTapGesture {
                                    historicMode()
                                }
                        }
                    }
                    .padding(.top, 60)
                }

                VStack {
                    Spacer()
                    actionBar
                }
                .padding()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true

                // Load user defaults
                backgroundColour = UserDefaults.standard.bool(forKey: kBackgroundColour)
                bleController.isSoundOn = UserDefaults.standard.bool(forKey: kIsSoundOn)
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var actionBar: some View {
        if #available(iOS 26.0, *) {
            HStack(spacing: 0) {
                actionControls
            }
            .buttonStyle(HomeActionButtonStyle())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            HStack(spacing: 8) {
                actionControls
            }
            .font(.system(size: 20, weight: .light))
            .foregroundColor(.secondary)
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var actionControls: some View {
        homeAction(
            bleController.isSoundOn ? "Mute" : "Sound",
            systemImage: bleController.isSoundOn ? "speaker.slash" : "speaker.wave.3",
            action: toggleSound
        )
        homeAction("Settings", systemImage: "gear") {
            showingSettingsSheet.toggle()
        }
        homeAction("Save", action: addMeasurement)
        NavigationLink(destination: ArchiveView()) {
            homeActionLabel("Archive")
        }
        .help("Archive")
    }

    private func homeAction(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            homeActionLabel(title, systemImage: systemImage)
        }
        .help(title)
    }

    @ViewBuilder
    private func homeActionLabel(_ title: String, systemImage: String? = nil) -> some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        } else {
            Text(title)
        }
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
        UserDefaults.standard.set(bleController.isSoundOn, forKey: kIsSoundOn)
    }

    private func co2Colour(co2: Int) -> Color {
        var colour = Color(.systemGreen)
        if !backgroundColour {
            return colour.opacity(0)
        }
        if co2 == 0 {
            colour = Color(.systemPink)
        }
        if co2 > 850 && co2 < 1500 {
            colour = Color(.systemYellow)
        }
        if co2 > 1500 && co2 < 2000 {
            colour = Color(.systemOrange)
        }
        if co2 > 2000 {
            colour = Color(.systemRed)
        }
        if colorScheme == .dark {
            colour = colour.opacity(0.4)
        }
        return colour
    }
}

private func setupBackgroundAudio() {
    do {
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
        print("Background playback setup")
        try AVAudioSession.sharedInstance().setActive(true)
        print("Background playback session is active")
    } catch {
        print(error)
    }
}

private struct HomeActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext).previewInterfaceOrientation(.portrait)
    }
}
