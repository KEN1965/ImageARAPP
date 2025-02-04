//
//  ContentView.swift
//  ImageARApp
//
//  Created by Kenichi on R 7/02/03.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var showPermissionAlert = false
    @State private var permissionMessage = ""
    
    @State private var images: [UIImage] = []
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var showARScreen = false
    @State private var showExplanation = false // 吹き出しを表示するための変数

    var body: some View {
        NavigationStack { // ✅ NavigationView → NavigationStack に変更
            ZStack{
                VStack {
                    PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                        VStack{
                            Spacer()
                            Image("icon")
                                .resizable()
                                .frame(width: 150, height: 150)
                                .cornerRadius(10)
                            Text("ImageAR")
                                .background(Color.white.opacity(0.3))
                                .foregroundStyle(.black)
                                .cornerRadius(10)
                            Spacer()
                     
                        }
                        .zIndex(-1) // 最前面に配置（吹き出しや広告より上）
                        .onAppear {
                                checkPermissions()
                               }
                               .alert(isPresented: $showPermissionAlert) {
                                   Alert(title: Text("権限が必要です"),
                                         message: Text(permissionMessage),
                                         dismissButton: .default(Text("OK")))
                               }
                    }
                    .onChange(of: selectedImage) { oldValue, newValue in
                        if let selectedItem = newValue {
                            selectedItem.loadTransferable(type: Data.self) { result in
                                switch result {
                                case .success(let data?):
                                    if let uiImage = UIImage(data: data) {
                                        self.images = [uiImage]
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // ✅ 少し遅らせて遷移を安定させる
                                            self.showARScreen = true
                                        }
                                    }
                                case .failure(let error):
                                    print("画像読み込み失敗: \(error)")
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
                // ✅ `NavigationStack` の直下に `navigationDestination` を配置
                .navigationDestination(isPresented: $showARScreen) {
                    ARViewScreen(isPresented: $showARScreen, images: $images)
                }
                ZStack{
                    VStack {
                        Spacer()
                        // 吹き出しを中央のボタンと広告の間に配置
                        if showExplanation {
                            Text("KEY_TITLE1")
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
            }
        }
    }
    func checkPermissions() {
            // 📸 カメラのアクセス許可を確認
            PhotoAccessManager.requestCameraPermission { granted in
                if !granted {
                    permissionMessage = "カメラのアクセスが拒否されました。設定から許可してください。"
                    showPermissionAlert = true
                }
            }
            
            // 🖼 フォトライブラリのアクセス許可を確認
            PhotoAccessManager.requestPhotoLibraryPermission { granted in
                if !granted {
                    permissionMessage = "フォトライブラリのアクセスが拒否されました。設定から許可してください。"
                    showPermissionAlert = true
                }
            }
        }
}

// ✅ 画像をリサイズする関数
func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    let size = image.size

    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height
    let newSize: CGSize

    if widthRatio > heightRatio {
        newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
        newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
    }

    let rect = CGRect(origin: .zero, size: newSize)

    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage ?? image
}
