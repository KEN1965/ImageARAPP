import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var images: [UIImage]
    @Binding var rotationAngle: Float // ✅ 回転角度を管理
    static var sharedARView: ARView? = ARView(frame: .zero)  // 共有インスタンス


    func makeUIView(context: Context) -> ARView {
        let arView = ARViewContainer.sharedARView ?? ARView(frame: .zero)
            ARViewContainer.sharedARView = arView
        // ✅ ここでジェスチャーをセットアップ
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
                let correctedImage = fixImageOrientation(image)
                
                // 画像処理を最適化
                guard let cgImage = correctedImage.cgImage else {
                    print("❌ CGImageの取得に失敗")
                    return
                }
                
                // より安定した画像処理のための設定
                let context = CIContext(options: [
                    .useSoftwareRenderer: false,
                    .cacheIntermediates: true
                ])
                
                let ciImage = CIImage(cgImage: cgImage)
                guard let processedCGImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
                    print("❌ 画像処理に失敗")
                    return
                }
                
                // 画像の保存と読み込みを最適化
                let processedImage = UIImage(cgImage: processedCGImage, scale: correctedImage.scale, orientation: .up)
                let imageURL = saveImageToTempDirectory(processedImage)
                
                // テクスチャの読み込みを最適化
                let textureResource = try TextureResource.load(contentsOf: imageURL)
                
                // マテリアルの設定を最適化
                var material = UnlitMaterial()
                material.color = .init(texture: MaterialParameters.Texture(textureResource))
                material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
                
                // エンティティの生成を最適化
                let aspectRatio = Float(correctedImage.size.width / correctedImage.size.height)
                let baseSize: Float = 0.3
                let width: Float = aspectRatio >= 1 ? baseSize : baseSize * aspectRatio
                let height: Float = aspectRatio < 1 ? baseSize : baseSize / aspectRatio
                
                let mesh = MeshResource.generatePlane(width: width, depth: height)
                let plane = ModelEntity(mesh: mesh, materials: [material])
                
                // コリジョン設定を最適化
                plane.generateCollisionShapes(recursive: false)
                plane.transform.rotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                
                // キャッシュをクリア
                context.clearCaches()
            
                // ✅ エンティティの位置設定
                  placeEntityInFrontOfCamera(entity: plane, in: arView)
                  
                  // ✅ 移動・拡大縮小の対象エンティティとして設定
                  trackedEntity = plane
                
            } catch {
                print("❌ 画像のテクスチャ生成に失敗: \(error.localizedDescription)")
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

        // 画像保存の最適化
        private func saveImageToTempDirectory(_ image: UIImage) -> URL {
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".png")
            
            if let imageData = image.pngData() {
                do {
                    try imageData.write(to: fileURL, options: .atomic)
                } catch {
                    print("❌ 画像の保存に失敗: \(error.localizedDescription)")
                }
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
            guard let arView = arView, let entity = trackedEntity else { return }

            let location = gesture.location(in: arView)
            
            switch gesture.state {
            case .began:
                let hitTestResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
                if let firstResult = hitTestResults.first {
                    isDragging = true
                    lastPanPosition = entity.position(relativeTo: nil)
                    initialPosition = SIMD3<Float>(
                        firstResult.worldTransform.columns.3.x,
                        firstResult.worldTransform.columns.3.y,
                        firstResult.worldTransform.columns.3.z
                    )
                }
                
            case .changed:
                if isDragging {
                    let hitTestResults = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any)
                    if let firstResult = hitTestResults.first {
                        // 指の位置をワールド座標に変換
                        let worldPosition = SIMD3<Float>(
                            firstResult.worldTransform.columns.3.x,
                            firstResult.worldTransform.columns.3.y,
                            firstResult.worldTransform.columns.3.z
                        )
                        
                        // スムージングを適用して自然な動きに
                        let smoothedPosition = lerp(from: entity.position(relativeTo: nil), to: worldPosition, t: 0.2)
                        entity.setPosition(smoothedPosition, relativeTo: nil)
                    }
                }
                
            case .ended, .cancelled:
                isDragging = false
                
            default:
                break
            }
        }

        func lerp(from: SIMD3<Float>, to: SIMD3<Float>, t: Float) -> SIMD3<Float> {
            return from + (to - from) * t
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
