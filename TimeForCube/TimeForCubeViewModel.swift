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
  
  func processHandUpdates() async {
    for await update in handTracking.anchorUpdates {
      let handAnchor = update.anchor
      
      guard handAnchor.isTracked else { continue }
      
      let fingerTip = handAnchor.handSkeleton?.joint(.indexFingerTip)
      
      guard ((fingerTip?.isTracked) != nil) else { continue }
      
      let originFromWrist = handAnchor.originFromAnchorTransform
      let wristFromIndex = fingerTip?.parentFromJointTransform
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
