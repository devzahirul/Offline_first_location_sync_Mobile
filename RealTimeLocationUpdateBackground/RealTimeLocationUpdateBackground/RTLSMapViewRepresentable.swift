import MapKit
import SwiftUI
import UIKit

struct RTLSMapViewRepresentable: UIViewRepresentable {
    var recordedPath: [CLLocationCoordinate2D]
    var subscribedPath: [CLLocationCoordinate2D]

    /// If non-nil, the map will keep centering around this coordinate (best-effort).
    var followCoordinate: CLLocationCoordinate2D?

    /// Change this to request a "fit to path" update.
    var fitTrigger: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator

        map.showsCompass = true
        map.showsScale = true
        map.showsUserLocation = false
        map.pointOfInterestFilter = .excludingAll

        return map
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.update(mapView: mapView)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate {
        fileprivate var parent: RTLSMapViewRepresentable

        private var recordedPolyline: MKPolyline?
        private var subscribedPolyline: MKPolyline?

        private var recordedAnnotation: RoleAnnotation?
        private var subscribedAnnotation: RoleAnnotation?

        private var recordedSignature = PathSignature.empty
        private var subscribedSignature = PathSignature.empty

        private var lastFitTrigger: UUID?

        init(parent: RTLSMapViewRepresentable) {
            self.parent = parent
        }

        func update(mapView: MKMapView) {
            updateRecorded(mapView: mapView, coordinates: parent.recordedPath)
            updateSubscribed(mapView: mapView, coordinates: parent.subscribedPath)

            if lastFitTrigger != parent.fitTrigger {
                lastFitTrigger = parent.fitTrigger
                fit(mapView: mapView, coordinates: parent.recordedPath + parent.subscribedPath)
                return
            }

            if let c = parent.followCoordinate {
                center(mapView: mapView, on: c)
            }
        }

        // MARK: - Paths

        private func updateRecorded(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            let sig = PathSignature(coordinates)
            guard sig != recordedSignature else { return }
            recordedSignature = sig

            if let recordedPolyline {
                mapView.removeOverlay(recordedPolyline)
                self.recordedPolyline = nil
            }
            if let recordedAnnotation {
                mapView.removeAnnotation(recordedAnnotation)
                self.recordedAnnotation = nil
            }

            if coordinates.count >= 2 {
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = "recorded"
                mapView.addOverlay(polyline)
                recordedPolyline = polyline
            }

            if let last = coordinates.last {
                let ann = RoleAnnotation(role: .device, coordinate: last)
                mapView.addAnnotation(ann)
                recordedAnnotation = ann
            }
        }

        private func updateSubscribed(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            let sig = PathSignature(coordinates)
            guard sig != subscribedSignature else { return }
            subscribedSignature = sig

            if let subscribedPolyline {
                mapView.removeOverlay(subscribedPolyline)
                self.subscribedPolyline = nil
            }
            if let subscribedAnnotation {
                mapView.removeAnnotation(subscribedAnnotation)
                self.subscribedAnnotation = nil
            }

            if coordinates.count >= 2 {
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = "subscribed"
                mapView.addOverlay(polyline)
                subscribedPolyline = polyline
            }

            if let last = coordinates.last {
                let ann = RoleAnnotation(role: .watched, coordinate: last)
                mapView.addAnnotation(ann)
                subscribedAnnotation = ann
            }
        }

        // MARK: - Camera helpers

        private func center(mapView: MKMapView, on coordinate: CLLocationCoordinate2D) {
            let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            mapView.setRegion(region, animated: true)
        }

        private func fit(mapView: MKMapView, coordinates: [CLLocationCoordinate2D]) {
            guard !coordinates.isEmpty else { return }

            var rect = MKMapRect.null
            for coord in coordinates {
                let p = MKMapPoint(coord)
                let r = MKMapRect(x: p.x, y: p.y, width: 0.1, height: 0.1)
                rect = rect.isNull ? r : rect.union(r)
            }

            guard !rect.isNull else { return }

            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 120, left: 40, bottom: 140, right: 40),
                animated: true
            )
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let r = MKPolylineRenderer(polyline: polyline)
            r.lineWidth = 4
            r.lineJoin = .round
            r.lineCap = .round

            switch polyline.title ?? "" {
            case "subscribed":
                r.strokeColor = UIColor.systemRed.withAlphaComponent(0.85)
            default:
                r.strokeColor = UIColor.systemBlue.withAlphaComponent(0.85)
            }
            return r
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ann = annotation as? RoleAnnotation else { return nil }

            let reuseId: String
            let tint: UIColor
            let glyphName: String

            switch ann.role {
            case .device:
                reuseId = "device"
                tint = .systemBlue
                glyphName = "location.fill"
            case .watched:
                reuseId = "watched"
                tint = .systemRed
                glyphName = "eye.fill"
            }

            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: ann, reuseIdentifier: reuseId)
            view.annotation = ann
            view.markerTintColor = tint
            view.glyphImage = UIImage(systemName: glyphName)
            view.canShowCallout = true

            return view
        }
    }
}

// MARK: - Small helpers

private final class RoleAnnotation: NSObject, MKAnnotation {
    enum Role {
        case device
        case watched
    }

    let role: Role
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?

    init(role: Role, coordinate: CLLocationCoordinate2D) {
        self.role = role
        self.coordinate = coordinate
        switch role {
        case .device:
            self.title = "Device"
        case .watched:
            self.title = "Watched"
        }
    }
}

private struct PathSignature: Equatable {
    private struct CoordinateKey: Equatable {
        var lat: Double
        var lng: Double

        init(_ c: CLLocationCoordinate2D) {
            lat = c.latitude
            lng = c.longitude
        }
    }

    static let empty = PathSignature(count: 0, first: nil, last: nil)

    private var count: Int
    private var first: CoordinateKey?
    private var last: CoordinateKey?

    init(_ coordinates: [CLLocationCoordinate2D]) {
        self.count = coordinates.count
        self.first = coordinates.first.map(CoordinateKey.init)
        self.last = coordinates.last.map(CoordinateKey.init)
    }

    private init(count: Int, first: CoordinateKey?, last: CoordinateKey?) {
        self.count = count
        self.first = first
        self.last = last
    }
}
