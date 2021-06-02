//
//  ViewController.swift
//  Track My Run
//
//  Created by Jay Phillips on 5/27/21.
//

import UIKit
import MapKit
import CoreLocation
import MessageUI

class MainViewController: UIViewController {
    
    //IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var currentRunView: CurrentRunView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    
    
    @IBOutlet weak var runSummaryView: RunDetailsView!
    @IBOutlet weak var milesKilometersSegmentControl: UISegmentedControl!
    @IBOutlet weak var totalDistanceLabel: UILabel!
    @IBOutlet weak var shareButton: UIButton!
    
    
    //Variables & Constants
    var distance: DistanceType?
    let distanceTypes: [DistanceType] = [.miles, .kilometers]
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 500
    
    var locationsPassed = [CLLocation]()
    var runHasStarted = false
    var totalDistance = 0.0
    var timer = Timer()
    var time = 0
    var runningRoute: MKPolyline?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        resetMap()
        intialViewSetup()
        
    }
    
    // Functions
    func intialViewSetup() {
        runSummaryView.isHidden = true
        shareButton.tintColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        startStopButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        startStopButton.tintColor = .green
        checkLocationServicesAreEnabled()
    }
    
    func addLocations(_ locations: [CLLocation]) {
        for location in locations {
            if !locationsPassed.contains(location) {
                locationsPassed.append(location)
            }
        }
    }
    
    func calculateDistance() {
        var total = 0.0
        for i in 0..<locationsPassed.count {
            guard let lastLocation = locationsPassed.last else { return }
            let currentLocation = locationsPassed[i]
            total += currentLocation.distance(from: lastLocation)
            }
        
            totalDistance = total
        
        switch milesKilometersSegmentControl.selectedSegmentIndex {
        case 0:
            totalDistanceLabel.text = String(format: "You went a total of %.2f miles. Great job!", totalDistance * 0.0006213712)
        case 1:
            totalDistanceLabel.text = String(format: "You went a total of %.2f kilometers. Great job!", totalDistance * 0.001)
        default:
            print("")
        }
        totalDistanceLabel.textColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        runSummaryView.isHidden = false
    }

    func beginRun() {
        runSummaryView.isHidden = true
        startStopButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
        startStopButton.tintColor = .red
        resetMap()
        resetTimer()
        setRunAnnotations()
        runHasStarted = true
        startTimer()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.startUpdatingLocation()
    }
    
    func endRun() {
        runHasStarted = false
        startStopButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        startStopButton.tintColor = .green
        stopTimer()
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.stopUpdatingLocation()
        calculateDistance()
        setRunAnnotations()
        fetchRunRoute(startingCoordinate: locationsPassed.first!.coordinate, finishingCoordinate: locationsPassed.last!.coordinate)
        runSummaryView.isHidden = false
        
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timerCount), userInfo: nil, repeats: true)
    }
    
    @objc func timerCount() {
        time += 1
        timeLabel.text = "\(formatTimeToString(time: TimeInterval(time)))"
    }
    
    func stopTimer() {
        timer.invalidate()
    }
    
    func resetTimer() {
        timer.invalidate()
        time = 0
        timeLabel.text = "\(formatTimeToString(time: TimeInterval(time)))"
    }
    
    func formatTimeToString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50
    }
    
    func fetchRunRoute(startingCoordinate: CLLocationCoordinate2D, finishingCoordinate: CLLocationCoordinate2D) {
        removeMapOverlays()
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startingCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: finishingCoordinate))
        request.transportType = .walking
        
        let route = MKDirections(request: request)
        route.calculate { response, error in
            guard let rt = response?.routes.first else { return }
            self.mapView.addOverlay(rt.polyline)
            self.mapView.setVisibleMapRect(rt.polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 200, left: 50 , bottom: 50, right: 50), animated: true)
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let runRouteRenderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        runRouteRenderer.lineWidth = 5
        runRouteRenderer.alpha = 0.75
        runRouteRenderer.strokeColor = .systemOrange
        return runRouteRenderer
    }
    
    func removeMapOverlays() {
        self.mapView.overlays.forEach({ self.mapView.removeOverlay($0)})
    }
    
    func fetchRunRouteURLFromAppleMaps() -> String? {
        guard let start = locationsPassed.first?.coordinate, let finish = locationsPassed.last?.coordinate, locationsPassed.count > 1 else { return nil }
        fetchRunRoute(startingCoordinate: start, finishingCoordinate: finish)
        let url = "http://maps.apple.com/maps?saddr=\(start.latitude),\(start.longitude)&daddr=\(finish.latitude),\(finish.longitude)"
        return url
    }
    
    func sendMessage(message: String) {
        let messageVC = MFMessageComposeViewController()
        messageVC.messageComposeDelegate = self
        messageVC.body = message
        
        if MFMessageComposeViewController.canSendText() {
            self.present(messageVC, animated: true, completion: nil)
        } else {
            print("Can't send message")
        }
    }
    
    @IBAction func startStopButtonWasPressed(_ sender: Any) {
        runHasStarted = !runHasStarted
        
        if runHasStarted {
            beginRun()
        } else {
            endRun()
        }
    }
    
    @IBAction func distanceTypeChanged(_ sender: Any) {
        distance = distanceTypes[milesKilometersSegmentControl.selectedSegmentIndex]
        if !runHasStarted && locationsPassed.count > 0 {
            calculateDistance()
        }
    }
    
    @IBAction func shareButtonWasPressed(_ sender: Any) {
        sendMessage(message: "Check out this route I just ran, \(String(describing: fetchRunRouteURLFromAppleMaps()))")
    }
    

}

extension MainViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? RunAnnotation {
            let id = "pin"
            let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.canShowCallout = true
            view.animatesDrop = true
            view.pinTintColor = annotation.mapPoint == .start ? .systemGreen : .systemRed
            view.calloutOffset = CGPoint(x: -8, y: -3)
            
            return view
        }
        return nil
    }
    
    func setRunAnnotations() {
        guard let startingPoint = locationsPassed.first?.coordinate, let endingPoint = locationsPassed.last?.coordinate, locationsPassed.count > 1 else { return }
        
        let start = RunAnnotation(mapPoint: .start, coordinate: startingPoint)
        let finish = RunAnnotation(mapPoint: .finish, coordinate: endingPoint)
        
        mapView.addAnnotation(start)
        mapView.addAnnotation(finish)
    }
    
    func removeMapAnnotations() {
        let mapAnnotations = mapView.annotations
        mapView.removeAnnotations(mapAnnotations)
    }
    
    func resetMap() {
        removeMapAnnotations()
        removeMapOverlays()
        totalDistance = 0
        locationsPassed.removeAll()
    }
    
    
}

extension MainViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if runHasStarted {
            addLocations(locations)
        }
        
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
        mapView.setRegion(region, animated: true)
    }
    
    func checkLocationAuthorizationStatus() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            centerUserLocationOnMap()
        case .authorizedWhenInUse:
            centerUserLocationOnMap()
        case .denied:
            //TODO: Show alert
        break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            //TODO: Show alert
        break
        @unknown default:
            //TODO: Show alert
        break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorizationStatus()
    }
    
    func centerUserLocationOnMap() {
        guard let location = locationManager.location?.coordinate else { return }
        let region = MKCoordinateRegion(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
        mapView.setRegion(region, animated: true)
        mapView.showsUserLocation = true
    }
    
    func checkLocationServicesAreEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorizationStatus()
        } else {
            locationManager.requestWhenInUseAuthorization()
        }
    }
}

extension MainViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        self.dismiss(animated: true, completion: nil)
    }
}


