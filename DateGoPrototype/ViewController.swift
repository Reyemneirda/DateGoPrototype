//
//  ViewController.swift
//  DateGoPrototype
//
//  Created by Adrien Meyer on 16/04/2018.
//  Copyright © 2018 DateGo. All rights reserved.
//

import UIKit
import Mapbox
import CoreLocation
import Mapbox
import SceneKit

class ViewController: UIViewController, CLLocationManagerDelegate, MGLMapViewDelegate, SCNSceneRendererDelegate, UICollectionViewDelegate {

    @IBOutlet weak var mapView: MGLMapView!
    @IBOutlet var sceneView: SCNView!
    var tapGestureRecognizer: UITapGestureRecognizer!

    static let kMapPitchDegrees: Float = 60.0
    
    var centerCoordinate: CLLocationCoordinate2D?
    var locationManager: CLLocationManager!
    var lastLocation: CLLocation?
    var lastHeading: CLHeading?
    
    
    // SceneKit scene
    var scene: SCNScene!
    var cameraNode: SCNNode!
    var camera: SCNCamera!
    var playerNode: SCNNode!
    var officeNode: SCNNode!
    var nodes: [SCNNode]!
    var ambientLightNode: SCNNode!
    var ambientLight: SCNLight!
    var omniLightNode: SCNNode!
    var omniLight: SCNLight!
    var sceneRect: CGRect!
    
    // Rendering state
    var renderStartTime: TimeInterval?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        
        setupMapView()
        setupSceneView()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    
    func setupMapView() {
        let camera = MGLMapCamera()
        mapView.setCamera(camera, animated: false)
        
        // MapBox configuration
        mapView.styleURL = URL(string: "mapbox://styles/reyem/cjg3ewjog2mq32rny5eiqb6dy")
        
        mapView.maximumZoomLevel = 22.0
        mapView.zoomLevel = 19.0
        mapView.minimumZoomLevel = 18.0
        
        
        mapView.allowsScrolling = false
        mapView.allowsRotating = false
        mapView.allowsTilting = false
        mapView.allowsZooming = false
        
        
        mapView.displayHeadingCalibration = true
        mapView.showsUserLocation = false
        mapView.compassView.isHidden = true
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        
        mapView.delegate = self
        centerCoordinate = mapView.centerCoordinate
        
        // detect tap gestures on map
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(onMapViewTapped(recognizer:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        mapView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func setupSceneView() {
        // transparent background for use as overlay
        sceneView.backgroundColor = UIColor.clear
        scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.loops = true
        sceneView.isPlaying = true
        sceneRect = sceneView.bounds
        
        // camera
        cameraNode = SCNNode()
        camera = SCNCamera()
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        
        // lighting
        ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1.0).cgColor
        ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // lighting
        omniLight = SCNLight()
        omniLight.type = .omni
        omniLightNode = SCNNode()
        omniLightNode.light = omniLight
        
        scene.rootNode.addChildNode(omniLightNode)
        
        // player node
        playerNode = SCNNode()
        let playerScene = SCNScene(named: "Body.scn")!
        let playerModelNode = playerScene.rootNode.childNodes.first!
        playerModelNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 0.118, green: 0.196, blue: 0.471, alpha: 1.0)
        playerModelNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        playerNode.addChildNode(playerModelNode)
        scene.rootNode.addChildNode(playerNode)
        
        // office node
        officeNode = SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0))
        nodes = [SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0)), SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0)), SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0)), SCNNode(geometry: SCNBox(width: 20.0, height: 20.0, length: 20.0, chamferRadius: 2.0))]
        
        officeNode.setValue(CLLocationCoordinate2DMake(32.064778, 34.774500), forKey: "coordinate")
        
        
        officeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
        officeNode.geometry?.firstMaterial?.specular.contents = UIColor.white
        officeNode.setValue(false, forKey: "tapped")
        scene.rootNode.addChildNode(officeNode)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        

         //ask for permission / enable location updates
        let authorizationStatus = CLLocationManager.authorizationStatus()
        if !(authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse) {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        
        // disable location updates
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
        
        super.viewWillDisappear(animated)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if (status == .authorizedAlways || status == .authorizedWhenInUse) {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let (shouldUpdate, immediately) = shouldUpdateLocation(newLocation: locations[0])
        if shouldUpdate {
            let heading = lastHeading?.magneticHeading ?? 0
            let previousAltitude = mapView.camera.altitude
            
            let camera = MGLMapCamera(lookingAtCenter: self.lastLocation!.coordinate, fromDistance: previousAltitude,
                                      pitch: CGFloat(ViewController.kMapPitchDegrees), heading: heading)
            mapView.setCamera(camera, withDuration: (immediately ? 0 : 0.5), animationTimingFunction: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading
        
        if let lastLocation = self.lastLocation {
            let previousAltitude = mapView.camera.altitude
            let camera = MGLMapCamera(lookingAtCenter: lastLocation.coordinate, fromDistance: previousAltitude,
                                      pitch: CGFloat(ViewController.kMapPitchDegrees), heading: newHeading.magneticHeading)
            mapView.setCamera(camera, animated: true)
        }
        
    }
    
    func shouldUpdateLocation(newLocation: CLLocation) -> (Bool, Bool) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        if let lastLocation = self.lastLocation {
            
            if newLocation.horizontalAccuracy > 65.0 && abs(lastLocation.timestamp.timeIntervalSinceNow) <= 10.0 {
                return (false, false)
            }
            
            let newTimestamp = newLocation.timestamp.timeIntervalSince1970
            let oldTimestamp = lastLocation.timestamp.timeIntervalSince1970
            if newTimestamp > oldTimestamp + 5.0 {
                if newLocation.distance(from: lastLocation) > 18.0 {
                    self.lastLocation = newLocation
                    
                    if newTimestamp - oldTimestamp > 60 {
                        return (true, true) // significant distance, long time since last update
                    }
                    else {
                        return (true, false) // significant distance
                    }
                }
                else {
                    return (false, false) // insignificant change
                }
            }
            else {
                return (false, false) // too soon
            }
        }
        else {
            self.lastLocation = newLocation // first location
            return (true, true)
        }
    }
    
    // convert geographic coordinates to screen coordinates in the map view
    func coordinateToOverlayPosition(coordinate: CLLocationCoordinate2D) -> SCNVector3 {
        let p: CGPoint = mapView.convert(coordinate, toPointTo: mapView)
        return SCNVector3Make(Float(p.x), Float(sceneRect.size.height - p.y), 0)
    }
    
    // MARK: MGLMapViewDelegate
    
    func mapViewRegionIsChanging(_ mapView: MGLMapView) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // update coordinate of map
        centerCoordinate = mapView.centerCoordinate
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // if we don't have a map yet, we have no idea what to do
        if centerCoordinate == nil || lastLocation == nil {
            return
        }
        
        // calculate elapsed time since rendering started
        if renderStartTime == nil {
            renderStartTime = time - (1.0/60.0)
        }
        
        // parameters for rotation (objects rotate every 2 seconds)
        let dt = Float(time - renderStartTime!)
        let rotationSpeed = Float.pi
        
        // get pitch of map
        let mapPitchRads = Float(mapView.camera.pitch) * (Float.pi / 180.0)
        
        // update player
        let playerPoint = coordinateToOverlayPosition(coordinate: lastLocation!.coordinate)
        let scaleMat = SCNMatrix4MakeScale(4.0, 4.0, 4.0)
        playerNode.transform = SCNMatrix4Mult(scaleMat,
                                              SCNMatrix4Mult(SCNMatrix4MakeRotation(-mapPitchRads, 1, 0, 0),
                                                             SCNMatrix4MakeTranslation(playerPoint.x, playerPoint.y, 0)))
        
        // update office
        let officePoint = coordinateToOverlayPosition(coordinate: officeNode.value(forKey: "coordinate") as! CLLocationCoordinate2D)
        officeNode.transform =
            SCNMatrix4Mult(SCNMatrix4MakeRotation(dt*rotationSpeed, 0, 1, 0),
                           SCNMatrix4Mult(SCNMatrix4MakeRotation(mapPitchRads, 1, 0, 0),
                                          SCNMatrix4MakeTranslation(officePoint.x, officePoint.y, 0)))
        let nodeTapped = officeNode.value(forKey: "tapped") as! Bool
        officeNode.geometry?.firstMaterial?.diffuse.contents = nodeTapped ? UIColor.red : UIColor.white
        
        // update light position
        omniLightNode.position = SCNVector3Make(playerPoint.x, playerPoint.y + 30, 20) // magic number alert!
        
        // update camera
        let metersPerPoint = mapView.metersPerPoint(atLatitude: centerCoordinate!.latitude)
        let altitudePoints = mapView.camera.altitude / metersPerPoint
        let projMat = GLKMatrix4MakeOrtho(0, Float(sceneRect.size.width),  // left, right
            0, Float(sceneRect.size.height), // bottom, top
            1, Float(altitudePoints+100))               // zNear, zFar
        cameraNode.position = SCNVector3Make(0, 0, Float(altitudePoints))
        cameraNode.camera!.projectionTransform = SCNMatrix4FromGLKMatrix4(projMat)
    }
    
    @objc func onMapViewTapped(recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(point, options: [SCNHitTestOption.firstFoundOnly : true])
        if hitTestResults.count > 0 {
            let node = hitTestResults.first!.node
            if node == officeNode {
                officeNode.setValue(true, forKey: "tapped")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    self.officeNode.setValue(false, forKey: "tapped")
                })
            }
        }
    }
    
    @IBAction func menu(_ sender: Any)
    {
        self.viewDeckController?.open(.left, animated: true)
    }
    


}

