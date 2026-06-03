import SwiftUI

/// Power adapter card. Renders only when an adapter is connected and reporting details.
struct AdapterSection: View {
    let adapter: AdapterInfo

    var body: some View {
        if adapter.isConnected && adapter.hasDetails {
            SectionCard("Power Adapter") {
                if let watts = adapter.watts {
                    MetricRow(icon: "powerplug.fill", label: "Wattage", value: "\(watts) W")
                }
                if let name = adapter.name {
                    MetricRow(icon: "tag", label: "Name", value: name)
                }
                if adapter.voltageV != nil {
                    MetricRow(icon: "bolt", label: "Voltage", value: Fmt.volts(adapter.voltageV))
                }
                if adapter.currentA != nil {
                    MetricRow(icon: "bolt.horizontal", label: "Current", value: Fmt.amps(adapter.currentA))
                }
                if let mfr = adapter.manufacturer {
                    MetricRow(icon: "building.2", label: "Manufacturer", value: mfr)
                }
                if let serial = adapter.serial {
                    MetricRow(icon: "barcode", label: "Serial", value: serial)
                }
            }
        } else if !adapter.isConnected {
            SectionCard("Power Adapter") {
                MetricRow(icon: "powerplug", label: "Status", value: "Not connected")
            }
        }
    }
}
