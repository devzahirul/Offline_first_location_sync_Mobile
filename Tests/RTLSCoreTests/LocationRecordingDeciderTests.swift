import Foundation
import Testing
@testable import RTLSCore

@Suite("LocationRecordingDecider")
struct LocationRecordingDeciderTests {
    @Test("Time policy: respects interval")
    func timePolicyRespectsInterval() {
        var decider = LocationRecordingDecider(policy: .time(interval: 10))

        let t0 = Date(timeIntervalSince1970: 0)
        let coord = GeoCoordinate(latitude: 0, longitude: 0)

        #expect(decider.shouldRecord(sampleAt: t0, coordinate: coord))
        decider.markRecorded(sampleAt: t0, coordinate: coord)

        #expect(!decider.shouldRecord(sampleAt: t0.addingTimeInterval(5), coordinate: coord))
        #expect(decider.shouldRecord(sampleAt: t0.addingTimeInterval(10), coordinate: coord))
    }

    @Test("Distance policy: respects meters threshold")
    func distancePolicyRespectsThreshold() {
        var decider = LocationRecordingDecider(policy: .distance(meters: 100))

        let t0 = Date(timeIntervalSince1970: 0)
        let a = GeoCoordinate(latitude: 0, longitude: 0)
        let bClose = GeoCoordinate(latitude: 0.0003, longitude: 0) // ~33m
        let bFar = GeoCoordinate(latitude: 0.0012, longitude: 0) // ~133m

        #expect(decider.shouldRecord(sampleAt: t0, coordinate: a))
        decider.markRecorded(sampleAt: t0, coordinate: a)

        #expect(!decider.shouldRecord(sampleAt: t0.addingTimeInterval(1), coordinate: bClose))
        #expect(decider.shouldRecord(sampleAt: t0.addingTimeInterval(2), coordinate: bFar))
    }
}

