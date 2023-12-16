//
//  ModelEntity+Extension.swift
//  TimeForCube
//
//  Created by Tim Mitra on 2023-12-15.
//

import Foundation
import RealityKit

extension ModelEntity {
  
  class func createFingertip() -> ModelEntity {
    let entity = ModelEntity(
      mesh: .generateSphere(radius: 0.005), // 5mm
      materials: [UnlitMaterial(color: .cyan)],
      collisionShape: .generateSphere(radius: 0.005),
      mass: 0.0
    )
    
    entity.components.set(PhysicsBodyComponent(mode: .kinematic))
    entity.components.set(OpacityComponent(opacity: 0.0))
    
    return entity
  }
}
