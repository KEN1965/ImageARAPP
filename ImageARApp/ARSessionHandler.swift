import ARKit
import RealityKit

class ARSessionHandler: NSObject, ARSessionDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            print("✅ ARトラッキングが正常です")
        case .notAvailable:
            print("❌ ARトラッキングが利用できません")
        case .limited(let reason):
            switch reason {
            case .initializing:
                print("⏳ トラッキングを初期化中...")
            case .excessiveMotion:
                print("⚠️ カメラの動きが速すぎます！ ゆっくり動かしてください")
            case .insufficientFeatures:
                print("⚠️ 十分な特徴点がありません。明るい場所で試してください")
            case .relocalizing:
                print("⏳ 再ローカライズ中...")
            @unknown default:
                print("⚠️ 未知のトラッキングエラー")
            }
        }
    }
}
