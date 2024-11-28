import SwiftUI

struct DeviceDetailView: View {
    let device: BLEDevice
    @ObservedObject var bleManager: BLEManager
    
    var body: some View {
        VStack {
            Text(device.name)
                .font(.largeTitle)
                .padding()
            
            if !bleManager.deviceProperties.isEmpty {
                List(bleManager.deviceProperties.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    VStack(alignment: .leading) {
                        Text(key)
                            .font(.headline)
                        Text(value)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Text("Fetching properties...")
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            bleManager.connect(to: device)
        }
        .navigationTitle("Device Details")
    }
}
