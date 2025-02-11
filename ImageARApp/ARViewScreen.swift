import SwiftUI
import RealityKit
import Photos
import AVFoundation


struct ARViewScreen: View {
    @Binding var isPresented: Bool
    @Binding var images: [UIImage]
    
    @State private var rotationAngle: Float = 0.0 // 回転角度を管理
    @State private var isPhotoMode: Bool = true // モード管理（Photo / Video）
    @State private var isFixed: Bool = false // 固定状態管理
    @State private var showExplanation = false // 吹き出しを表示するための変数


    
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
                            .foregroundColor(.white) // Photoモード時は緑色
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .cornerRadius(10)
                    }
//                    
//                    Button(action: {
//                        isPhotoMode = false
//                    }) {
//                        Text("Video")
//                            .foregroundColor(isPhotoMode ? .white : .green) // Videoモード時は緑色
//                            .font(.system(size: 18, weight: .bold))
//                            .padding(.horizontal, 12)
//                            .padding(.vertical, 6)
//                            .background(isPhotoMode ? Color.clear : Color.black.opacity(0.5))
//                            .cornerRadius(10)
//                    }
                }
//                .padding(.bottom, 20) // ボタン間隔を縮める（さらに下に寄せる）

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
            ZStack{
                VStack {
                    Spacer()
                    // 吹き出しを中央のボタンと広告の間に配置
                    if showExplanation {
                        Text("KEY_TITLE2")
                            .font(.headline)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(radius: 10)
                            .transition(.slide)
                            .frame(maxWidth: .infinity, alignment: .center) // 吹き出し内で中央揃え
                            .multilineTextAlignment(.center) // テキストを中央揃え
                            .padding(.bottom, 20) // 広告との間にスペースを追加
                    }
                    
                    Spacer() // 下部のスペースを確保
                }
                VStack{
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                self.showExplanation.toggle() // 吹き出しの表示/非表示を切り替え
                            }
                        }) {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.system(size: 50)) // ボタンのサイズを大きくする
                                .foregroundColor(.black)
                                .padding()
                        }
                    }
                }
            }
                .padding(.bottom,10) // 下部の余白調整
                .padding(.horizontal,10)
            }
        .onAppear {
            requestPhotoLibraryPermission() // フォトライブラリの許可をリクエスト
        }
    }

    // 撮影ボタンを押したときの処理
    func takeScreenshot() {
        guard let arView = ARViewContainer.sharedARView else {
            print("❌ ARViewが見つかりません")
            return
        }

        playShutterSound()  // シャッター音を再生

        arView.snapshot(saveToHDR: false) { image in
            guard let screenshot = image else {
                print("❌ スクリーンショットの取得に失敗しました")
                return
            }

            // 画像をカメラロールに保存
            UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
            print("📸 スクリーンショットを保存しました！")

            // **📌 撮影後に元の画面に戻る**
            isPresented = false
        }
    }

    func playShutterSound() {
        AudioServicesPlaySystemSound(1108)  // iOS標準カメラのシャッター音
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
