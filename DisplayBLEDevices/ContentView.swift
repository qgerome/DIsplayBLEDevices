//
//  ContentView.swift
//  DisplayBLEDevices
//
//  Created by Quentin Gérôme on 26/11/2024.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var bleManager = BLEManager()

    var body: some View {
        NavigationView {
            List(bleManager.devices) { device in
                NavigationLink(
                    destination: DeviceDetailView(device: device, bleManager: bleManager)) {
                        HStack {
                            Text(device.name)
                                .font(.headline)
                            Spacer()
                            Text("RSSI: \(device.rssi)")
                                .foregroundColor(.gray)
                        }
                    }
            }
            .navigationTitle("Sport Devices")
            .onAppear {
                bleManager.centralManagerDidUpdateState(bleManager.centralManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
