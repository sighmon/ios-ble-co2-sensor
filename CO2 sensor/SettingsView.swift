//
//  SettingsView.swift
//  CO2 sensor
//
//  Created by Simon Loffler on 9/10/2022.
//

import SwiftUI

struct SettingsView: View {
    @State private var influxdbOrganisationID: String = ""
    @State private var influxdbBucketID: String = ""
    @State private var influxdbAPIKey: String = ""
    @State private var influxdbServer: String = ""
    @State private var postToInfluxdb: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea(.all)
                VStack {
                    Text("InfluxDB settings")
                        .font(.system(size: 30, weight: .medium))
                    TextField("Organisation ID", text: $influxdbOrganisationID)
                        .onChange(of: influxdbOrganisationID) {
                            UserDefaults.standard.set($0, forKey: "influxdbOrganisationID")
                        }
                    TextField("Bucket ID", text: $influxdbBucketID)
                        .onChange(of: influxdbBucketID) {
                            UserDefaults.standard.set($0, forKey: "influxdbBucketID")
                        }
                    SecureField("API Key", text: $influxdbAPIKey)
                        .onChange(of: influxdbAPIKey) {
                            UserDefaults.standard.set($0, forKey: "influxdbAPIKey")
                        }
                    TextField("Server URL", text: $influxdbServer)
                        .onChange(of: influxdbServer) {
                            UserDefaults.standard.set($0, forKey: "influxdbServer")
                        }
                    Toggle("Post to InfluxDB", isOn: $postToInfluxdb)
                        .onChange(of: postToInfluxdb) {
                            UserDefaults.standard.set($0, forKey: "postToInfluxdb")
                        }
                }
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding([.leading, .trailing], 40)
                .onAppear {
                    // Load InfluxDB settings from user defaults
                    influxdbOrganisationID = UserDefaults.standard.string(forKey: "influxdbOrganisationID") ?? ""
                    influxdbBucketID = UserDefaults.standard.string(forKey: "influxdbBucketID") ?? ""
                    influxdbAPIKey = UserDefaults.standard.string(forKey: "influxdbAPIKey") ?? ""
                    influxdbServer = UserDefaults.standard.string(forKey: "influxdbServer") ?? ""
                    postToInfluxdb = UserDefaults.standard.bool(forKey: "postToInfluxdb")
                }
            }
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
