# PinyinFlow

中国語動画・音声・テキストを読み込み、文字起こし、ピンイン、翻訳をまとめて確認できる iOS アプリです。

## 機能

- Files から `.mov` / `.mp4` などの動画や音声を選択
- 写真アプリ、リンク、テキスト入力から取り込み
- `AVFoundation` で動画から `.m4a` 音声を抽出
- `WhisperKit` で端末内文字起こし
- 設定で `WhisperKit` と iOS 純正音声認識を切り替え
- `CFStringTransform` で漢字ごとのピンインを声調付きで表示
- DeepL または iOS 純正翻訳で複数言語へ翻訳

## 実行

Xcode で `ChineseVideoTutor.xcodeproj` を開き、`ChineseVideoTutor` スキームを iPhone 実機またはシミュレータで実行します。

翻訳まで使う場合は、右上の設定から DeepL API キーを入力してください。未設定の場合は、文字起こしとピンインのみ表示します。

WhisperKit は初回実行時にモデルをダウンロードします。設定の `WhisperKit モデル` には `base` を既定値として入れています。速く試すなら `tiny`、中国語の精度を上げるなら `small` 以上を検討してください。

## 注意

WhisperKit は初回のモデル取得後、端末内で文字起こしします。端末・モデル・動画の長さによって処理時間と精度が変わります。
