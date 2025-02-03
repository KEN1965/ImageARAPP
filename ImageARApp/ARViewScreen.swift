import SwiftUI
import RealityKit
import Photos

struct ARViewScreen: View {
    @Binding var isPresented: Bool
    @Binding var images: [UIImage]
    
    @State private var rotationAngle: Float = 0.0 // ✅ 回転角度を管理

    var body: some View {
        ZStack {
            ARViewContainer(images: $images, rotationAngle: $rotationAngle) // ✅ 修正
            VStack {
                Spacer()
                HStack {
                    // ✅ 撮影ボタン
                    Button(action: {
                        takeScreenshot()
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .resizable()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    // ✅ 回転ボタン（写真撮影ボタンの右側）
//                    Button(action: {
//                        rotationAngle -= 90.0 // ✅ 左に45度回転
//                    }) {
//                        Image(systemName: "arrow.counterclockwise.circle.fill") // ⬅ 左回転アイコン
//                            .resizable()
//                            .frame(width: 60, height: 60)
//                            .foregroundColor(.white)
//                            .padding()
//                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
                   requestPhotoLibraryPermission() // ✅ ここで呼び出し
               }
    }
    // ✅ 事前にフォトライブラリの許可をリクエスト
    func requestPhotoLibraryPermission() {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                print("📸 写真ライブラリのアクセス許可が承認されました")
            case .denied, .restricted:
                print("⚠️ 写真ライブラリのアクセスが拒否されました")
            case .notDetermined:
                print("🕐 許可ダイアログを表示")
            case .limited:
                print("🔹 限定的なアクセスが許可されました")
            @unknown default:
                print("❌ 未知のエラー")
            }
        }
    }
         
    func takeScreenshot() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ エラー: ウィンドウが取得できませんでした。")
            return
        }

        let size = window.bounds.size

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if let screenshot = screenshot {
            UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
            print("📸 スクリーンショットを保存しました！")
            // **📌 撮影後に元の画面（ContentView）に戻る**
            isPresented = false
        } else {
            print("❌ スクリーンショットの取得に失敗しました。")
        }
    }
}


 


