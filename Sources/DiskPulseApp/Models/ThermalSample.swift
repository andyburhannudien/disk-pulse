import Foundation

struct ThermalSample: Codable, Identifiable {
    let date: Date
    let temperatureCelsius: Double
    let healthPercentage: Int
    let tbw: Double
    let mediaErrors: UInt64

    var id: Date { date }
}
