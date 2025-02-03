import UIKit

// 画像をそのまま返す関数（背景削除なし）
func removeBackgroundUsingModel(image: UIImage, completion: @escaping (UIImage?) -> Void) {
    print("🔍 背景削除なしで画像をそのまま表示")
    completion(image)
}
