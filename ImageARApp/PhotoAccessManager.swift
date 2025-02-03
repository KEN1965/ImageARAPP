//
//  PhotoAccessManager.swift
//  ImageARApp
//
//  Created by Kenichi on R 7/02/03.
//

import AVFoundation
import Photos

class PhotoAccessManager {
    // 📸 カメラのアクセス許可をリクエスト
    static func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:  // すでに許可されている
            completion(true)
        case .notDetermined:  // 初回リクエスト
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:  // 拒否 or 制限あり
            completion(false)
        }
    }
    
    // 🖼 フォトライブラリのアクセス許可をリクエスト
    static func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:  // すでに許可されている
            completion(true)
        case .notDetermined:  // 初回リクエスト
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
        default:  // 拒否 or 制限あり
            completion(false)
        }
    }
}
