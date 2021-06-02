//
//  RunAnnotation.swift
//  Track My Run
//
//  Created by Jay Phillips on 5/27/21.
//

import Foundation
import MapKit

class RunAnnotation: NSObject, MKAnnotation {
    let title: String?
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D
    let mapPoint: MapPoint
    
    init(mapPoint: MapPoint, coordinate: CLLocationCoordinate2D) {
        self.mapPoint = mapPoint
        self.coordinate = coordinate
        self.title = mapPoint == .start ? "Start" : "Finish"
        self.subtitle = mapPoint == .start ? "You started here." : "You finished here."
    }    
}

enum MapPoint {
    case start
    case finish
}
