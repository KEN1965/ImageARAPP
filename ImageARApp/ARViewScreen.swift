import SwiftUI
import RealityKit
import Photos

struct ARViewScreen: View {
    @Binding var isPresented: Bool
    @Binding var images: [UIImage]
    
    @State private var rotationAngle: Float = 0.0 // 回転角度を管理
    @State private var isPhotoMode: Bool = true // モード管理（Photo / Video）
    @State private var isFixed: Bool = false // 固定状態管理
    
    var body: some View {
        ZStack {
            ARViewContainer(images: $images, rotationAngle: $rotationAngle)
            
            VStack {
                Spacer()

                // Photo / Video モード切替ボタン
                HStack(spacing: 10) { // ボタン間隔を縮める
                    Button(action: {
                        isPhotoMode = true
                    }) {
                        Text("Photo")
                            .foregroundColor(isPhotoMode ? .green : .white) // Photoモード時は緑色
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isPhotoMode ? Color.black.opacity(0.5) : Color.clear)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isPhotoMode = false
                    }) {
                        Text("Video")
                            .foregroundColor(isPhotoMode ? .white : .green) // Videoモード時は緑色
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isPhotoMode ? Color.clear : Color.black.opacity(0.5))
                            .cornerRadius(10)
                    }
                }
                .padding(.bottom, 20) // ボタン間隔を縮める（さらに下に寄せる）

                // 撮影ボタンを中央下部に配置（独立させる）
                Button(action: {
                    takeScreenshot()
                }) {
                    Image(systemName: "camera.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                        .padding(10)
                }
                .padding(.bottom, 10) // 下に余白を追加

            }
            
            // 固定ボタン（撮影ボタンの右側50ポイントに配置）
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        isFixed.toggle()  // 固定状態の切り替え
                    }) {
                        Image(systemName: isFixed ? "pin.circle.fill" : "pin.circle")
                            .resizable()
                            .frame(width: 40, height: 40) // 固定ボタンのサイズ
                            .foregroundColor(isFixed ? .green : .white) // 固定されている場合は緑色
                            .padding(.leading, 50)  // 右隣に配置
                    }
                }
                .padding(.bottom,30) // 下部の余白調整
                .padding(.horizontal,30)
            }
        }
        .onAppear {
            requestPhotoLibraryPermission() // フォトライブラリの許可をリクエスト
        }
    }

    // 撮影ボタンを押したときの処理
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

    // フォトライブラリの許可をリクエスト
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
}
