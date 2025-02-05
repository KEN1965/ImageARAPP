import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var images: [UIImage]
    @Binding var rotationAngle: Float // ✅ 回転角度を管理

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        startARSession(in: arView)
        context.coordinator.arView = arView
        context.coordinator.setupGestures(for: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        if images.isEmpty { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            uiView.scene.anchors.removeAll()

            for image in images {
                context.coordinator.addImageToARView(image, in: uiView)
            }
        }
        
        // ✅ 回転を適用
        context.coordinator.updateRotation(rotationAngle)
    }
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}
    private func startARSession(in arView: ARView) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
//        configuration.environmentTexturing = .automatic
        configuration.environmentTexturing = .none  // ✅ メモリ節約
          configuration.isLightEstimationEnabled = false // ✅ 不要な計算を減らす
        // ✅ 既存の AR セッションをリセット
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
// ✅ **画像の向きを正しく修正**
   private func fixImageOrientation(_ image: UIImage) -> UIImage {
       guard image.imageOrientation != .up else { return image }
       UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
       image.draw(in: CGRect(origin: .zero, size: image.size))
       let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
       UIGraphicsEndImageContext()
       return correctedImage ?? image
   }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }

    class Coordinator: NSObject , ARSessionDelegate {
        
        var arView: ARView?
         var trackedEntity: ModelEntity? = nil
         private var currentRotation: Float = 0.0 // ✅ 現在の回転角度を保持

        var lastPanPosition: SIMD3<Float>? = nil // ✅ 前回の位置を記録
        var isDragging = false // ✅ 移動中かどうかを管理
        var initialPosition: SIMD3<Float>? = nil // ✅ 最初の位置を保存（手前に来ないように）
        
        func session(_ session: ARSession, didFailWithError error: Error) {
            print("❌ ARSession failed: \(error.localizedDescription)")
        }

        func sessionWasInterrupted(_ session: ARSession) {
            print("⚠️ ARSession was interrupted")
        }

        func sessionInterruptionEnded(_ session: ARSession) {
            print("✅ ARSession interruption ended")
        }

        // ✅ 画像を回転させるメソッド
        func updateRotation(_ angle: Float) {
            guard let entity = trackedEntity else { return }
            currentRotation += angle  // ✅ 累積するように変更
            let rotation = simd_quatf(angle: currentRotation * .pi / 180, axis: [0, 0, 1])
            entity.transform.rotation = rotation
        }
        // ✅ **EXIF情報を考慮し、正しい向きのUIImageを取得**
        func fixImageOrientation(_ image: UIImage) -> UIImage {
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let correctedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return correctedImage ?? image
        }




        func addImageToARView(_ image: UIImage, in arView: ARView) {
            do {
                // ✅ **画像の回転を修正する**
                let correctedImage = fixImageOrientation(image)
                
                // ✅ **修正後の画像を保存**
                let imageURL = saveImageToTempDirectory(correctedImage)
                let texture = try TextureResource.load(contentsOf: imageURL)
                var material = UnlitMaterial()
                material.color = .init(texture: MaterialParameters.Texture(texture))

                let aspectRatio = Float(correctedImage.size.width / correctedImage.size.height)
                let baseSize: Float = 0.3
                let width: Float = aspectRatio >= 1 ? baseSize : baseSize * aspectRatio
                let height: Float = aspectRatio < 1 ? baseSize : baseSize / aspectRatio

                let plane = ModelEntity(mesh: .generatePlane(width: width, depth: height), materials: [material])
                plane.generateCollisionShapes(recursive: false)

                // ✅ **回転処理を削除**
                 plane.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])

                placeEntityInFrontOfCamera(entity: plane, in: arView)
                trackedEntity = plane
            } catch {
                print("❌ 画像のテクスチャ生成に失敗: \(error)")
            }
        }


        private func placeEntityInFrontOfCamera(entity: ModelEntity, in arView: ARView) {
            guard let frame = arView.session.currentFrame else {
                print("⚠️ ARSession の currentFrame が取得できません。")
                return
            }

            let cameraTransform = frame.camera.transform
            let forwardVector = simd_float3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)

            let position = simd_make_float3(
                cameraTransform.columns.3.x + forwardVector.x * 0.5,
                cameraTransform.columns.3.y + forwardVector.y * 0.5,
                cameraTransform.columns.3.z + forwardVector.z * 0.5
            )

            let anchor = AnchorEntity(world: position)
            anchor.addChild(entity)
            arView.scene.anchors.append(anchor)

            initialPosition = position // ✅ 最初の位置を保存（移動時に z 軸を変えないため）
        }

        private func saveImageToTempDirectory(_ image: UIImage) -> URL {
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".png")

            if let imageData = image.pngData() {
                try? imageData.write(to: fileURL)
            }

            return fileURL
        }

        // ✅ **ジェスチャーのセットアップ**
        func setupGestures(for arView: ARView) {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
            panGesture.minimumNumberOfTouches = 1
            panGesture.maximumNumberOfTouches = 1
            arView.addGestureRecognizer(panGesture)

            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            arView.addGestureRecognizer(pinchGesture)
        }

        // ✅ **パンジェスチャーで画像を移動（Z軸を変更しないように修正）**
        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let arView = arView, let entity = trackedEntity, let initialPos = initialPosition else { return }
            
            let location = gesture.location(in: arView) // ✅ タップ位置を取得
            let translation = gesture.translation(in: arView)

            switch gesture.state {
            case .began:
                if let hitEntity = arView.entity(at: location), hitEntity == entity {
                    isDragging = true
                    lastPanPosition = entity.transform.translation

                    // ✅ ワールド座標を取得（失敗時は lastPanPosition を維持）
                    let hitTestResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
                    if let firstResult = hitTestResults.first {
                        let worldTransform = firstResult.worldTransform
                        lastPanPosition = SIMD3<Float>(
                            (lastPanPosition!.x + worldTransform.columns.3.x) / 3, // ✅ 前回の値と平均を取る
                            (lastPanPosition!.y + worldTransform.columns.3.y) / 3, // ✅ Y軸の急激な変化を抑える
                            initialPos.z
                        )
                    } else {
                        print("⚠️ hitTestResults が取得できませんでした。前回の位置を維持します。")
                    }
                }
            case .changed:
                if isDragging, let lastPosition = lastPanPosition {
                    let newPosition = SIMD3<Float>(
                        lastPosition.x + Float(translation.x) * 0.002,  // ✅ X軸移動
                        lastPosition.y - Float(translation.y) * 0.003,  // ✅ Y軸も移動できるように修正
                        initialPos.z // ✅ Z軸を固定
                    )

                    // ✅ 急激な変化を防ぐスムージング
                    // ✅ スムージングを距離に応じて調整
                    let smoothingFactor: Float = distance(lastPanPosition!, newPosition) > 0.1 ? 8.0 : 4.0
                    let smoothedPosition = SIMD3<Float>(
                        (entity.position.x + newPosition.x) / smoothingFactor,
                        (entity.position.y + newPosition.y) / smoothingFactor,
                        initialPos.z
                    )


                    entity.setPosition(smoothedPosition, relativeTo: nil)
                }
            case .ended, .cancelled:
                isDragging = false
            default:
                break
            }
        }
        func distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
            return sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2) + pow(b.z - a.z, 2))
        }



        // ✅ **ピンチで拡大縮小**
        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            guard let entity = trackedEntity else { return }

            switch gesture.state {
            case .changed:
                let scaleFactor = Float(gesture.scale)
                let newScale = entity.scale * scaleFactor
                let clampedScale = SIMD3<Float>(
                    max(0.3, min(newScale.x, 1.5)),
                    max(0.3, min(newScale.y, 1.5)),
                    max(0.3, min(newScale.z, 1.5))
                )
                entity.setScale(clampedScale, relativeTo: nil)
                gesture.scale = 1.0
            default:
                break
            }
        }

    }
