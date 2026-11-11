# CLAUDE.md（作業メモ・毎回読み込まれる）

## 前提
- 返答は日本語。専門用語は避け、使うときは一言説明を添える。「版」ではなく「バージョン」と書く。
- 設計とデザインの正は `design/design-spec.md`。画面を作る・直す前に必ず読む。モックは `design/mocks/`。
- バンドルIDは `com.seventhwell.petacal`。アプリ名「ペタカレ」は仮称。
- 実機確認は TestFlight だけ。配信は **kajisho5/runway**（`.github/workflows/testflight.yml` が呼ぶ）。Mac の Xcode から実機に入れる前提の提案はしない。
- サンプルデータは明らかに架空のものにする（実在の人物・会場・案件を使わない）。

## 構成
- `Packages/PetaCore/` … 画面に関係しない計算（日付の読み取り、集計、空き時間、月の格子）。Linux でもテストできる。AI や Apple 専用の仕組みを入れない。
- `Petacal/` … アプリ本体（SwiftUI）。`project.yml` から XcodeGen で `.xcodeproj` をつくる（コミットしない）。
- `design/` … 設計書、モック、モックの生成スクリプト。

## 開発ルール
- 外部ライブラリは入れない。
- 計算は PetaCore に書き、テストを付ける。日付の補完と金額の合計を AI に任せない。
- 画面の文言は String Catalogs（`Petacal/Resources/Localizable.xcstrings`）で管理する。
- 秘密情報（API キー、証明書、.p8 など）はコミットしない。
- コミットの作者メールは `info@seventh-well.com`。
