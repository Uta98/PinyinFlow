# ChineseVideoTutor

中国語動画を読み込み、音声を抽出して文字起こしし、各文にピンインと日本語訳を付ける iOS アプリです。

## 機能

- Files から `.mov` / `.mp4` などの動画を選択
- `AVFoundation` で動画から `.m4a` 音声を抽出
- `WhisperKit` で端末内文字起こし
- WhisperKit が失敗した場合のみ `Speech` フレームワークにフォールバック
- `CFStringTransform` で漢字ごとのピンインを声調付きで表示
- 設定画面の DeepL API キーを使って日本語訳を生成

## 実行

Xcode で `ChineseVideoTutor.xcodeproj` を開き、`ChineseVideoTutor` スキームを iPhone 実機またはシミュレータで実行します。

翻訳まで使う場合は、右上の設定から DeepL API キーを入力してください。未設定の場合は、文字起こしとピンインのみ表示します。

WhisperKit は初回実行時にモデルをダウンロードします。設定の `WhisperKit モデル` には `base` を既定値として入れています。速く試すなら `tiny`、中国語の精度を上げるなら `small` 以上を検討してください。

## 注意

WhisperKit は初回のモデル取得後、端末内で文字起こしします。端末・モデル・動画の長さによって処理時間と精度が変わります。
