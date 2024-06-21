//
//  TimeForCubeViewModel.swift
//  TimeForCube
//
//  Created by Tim Mitra on 2023-12-15.
//

import Foundation
import ARKit
import RealityKit

@MainActor class TimeForCubeViewModel: ObservableObject {
  private let session = ARKitSession()
  private let handTracking = HandTrackingProvider()
  private let sceneReconstruction = SceneReconstructionProvider()
  
  private var contentEntity = Entity()
  
  private var meshEntities = [UUID: ModelEntity]()
  
  private let fingerEntities: [HandAnchor.Chirality: ModelEntity] = [
    .left: .createFingertip(),
    .right: .createFingertip()
  ]
  
  func setupContentEntity() -> Entity {
    for entity in fingerEntities.values {
      contentEntity.addChild(entity)
    }
    return contentEntity
  }
  
  func runSession() async {
    do {
      try await session.run([sceneReconstruction, handTracking])
    } catch {
      print ("failed to start session: \(error)")
    }
  }

  /*
  // Function to return the translation distance from a transform; for inspecting the various transforms
  func distanceTranslationFromTransform(_ transform: simd_float4x4) -> Float {
      let translation = transform.columns.3
      let translationVector = SIMD3<Float>(translation.x, translation.y, translation.z)
      let translationDistance = sqrt( pow(translationVector.x, 2) + pow(translationVector.y, 2) + pow(translationVector.z, 2))
      return translationDistance
  }
  */
  
  func processHandUpdates() async {
    for await update in handTracking.anchorUpdates {
      let handAnchor = update.anchor
      
      guard handAnchor.isTracked else { continue }
      
      let fingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip)
      
      guard ((fingerTip?.isTracked) != nil) else { continue }
      
      let originFromWrist = handAnchor.originFromAnchorTransform  // location of the 'hand' (wrist) in world space

        // walk the skeleton back to the wrist, printing out names and distances
        // sequence: 
        //      .indexFingerTip = tip of finger
        //      .indexFingerIntermediateTip = DIP joint
        //      .indexFingerIntermediateBase = PIP joint
        //      .indexFingerKnuckle = MP joint
        //      .indexFingerMetacarpal = metacarpal shaft
        //      .wrist = wrist, which has no parent, and pfj and afj are 0.0
        //
        /* // uncomment to see the components of the skeleton and how they relate to each other
           // (will also have to uncomment the function above)
        var thisJoint = fingerTip
        while (thisJoint != nil) {
            let nextJoint = thisJoint!.parentJoint
            let jointName = thisJoint!.name
            let jointDescription = thisJoint!.description // description is really long, & spells out components of transform
            let pfj = thisJoint!.parentFromJointTransform
            let afj = thisJoint!.anchorFromJointTransform
            print("Joint \(jointName) has pfj \(distanceTranslationFromTransform(pfj)) and afj \(distanceTranslationFromTransform(afj))")
            thisJoint = nextJoint
        }
        */
        
      // anchorFromJointTransform gives transfrom from base joint of skeleton; parent just gives transform from immediate prior joint
      
      let wristFromIndex = fingerTip?.anchorFromJointTransform
      let originFromIndex = originFromWrist * wristFromIndex!
      
      fingerEntities[handAnchor.chirality]?.setTransformMatrix(originFromIndex, relativeTo: nil)
    }
  }
  
  func processReconstructionUpdates() async {
    for await update in sceneReconstruction.anchorUpdates {
      let meshAnchor = update.anchor
      
      guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
      
      switch update.event {
      case .added:
        let entity = ModelEntity()
        entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
        entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
        entity.physicsBody = PhysicsBodyComponent()
        entity.components.set(InputTargetComponent())
        
        meshEntities[meshAnchor.id] = entity
        contentEntity.addChild(entity)
      case .updated:
        guard let entity = meshEntities[meshAnchor.id] else { fatalError("...") }
        entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
        entity.collision?.shapes = [shape]
      case .removed:
        meshEntities[meshAnchor.id]?.removeFromParent()
        meshEntities.removeValue(forKey: meshAnchor.id)
      default:
        fatalError("Unsupported anchor event")
      }
    }
  }
  
  
  func addCube(tapLocation: SIMD3<Float>) {
    let placementLocation = tapLocation + SIMD3<Float>(0, 0.2, 0)
    
    let entity = ModelEntity(
      mesh: .generateBox(size: 0.1, cornerRadius: 0.0),
      materials: [SimpleMaterial(color: .systemPink, isMetallic: false)],
      collisionShape: .generateBox(size: SIMD3<Float>(repeating: 0.1)),
      mass: 1.0)
    
    entity.setPosition(placementLocation, relativeTo: nil)
    entity.components.set(InputTargetComponent(allowedInputTypes: .indirect))
    
    let material = PhysicsMaterialResource.generate(friction: 0.8, restitution: 0.0)
    entity.components.set(PhysicsBodyComponent(shapes: entity.collision!.shapes,
                                               mass: 1.0,
                                               material: material,
                                               mode: .dynamic))
    
    contentEntity.addChild(entity)
  }
}
