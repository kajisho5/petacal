# ペタカレ（仮称） / petacal

予定も、推し活も、収支も。写真で残せるカレンダー。iPhone／iPhone Duo／iPad／Mac 向け。

**開発中です。** いまは画面の骨組み（4つのタブと月の画面）と、計算の部品だけがあります。

## いまの状態

| 段階 | 内容 | 状態 |
|---|---|---|
| 1 | 骨組みと配布（空のアプリを TestFlight に出す） | 作業中 |
| 2 | 予定の表示・追加（iPhone に登録済みのカレンダー） | これから |
| 3 | 記録（写真・金額・メモ、ロック） | これから |
| 4 | ほかのアプリからの受け取り、写真をまとめて追加 | これから |
| 5 | AI取り込み | これから |
| 6 | 課金、集計・予算・まとめ画像、候補日メーカー | これから |
| 7 | iPhone Duo・iPad・Mac の作り込み、審査の準備 | これから |

設計とデザインは [design/design-spec.md](design/design-spec.md)、画面の一覧は [design/overview/](design/overview/) にあります。

## 構成

```
Packages/PetaCore/   画面に関係しない計算（日付の読み取り、集計、空き時間、月の格子）とそのテスト
Petacal/             アプリ本体（SwiftUI）
PetacalTests/        アプリのテスト
design/              設計書、モック（SVG と PNG）、モックの生成スクリプト
project.yml          XcodeGen の定義（.xcodeproj はここから毎回つくる）
tools/               TestFlight の状態を確認する道具
```

外部ライブラリは使っていません。

## テスト

GitHub に push すると自動で動きます（`.github/workflows/ci.yml`）。

- PetaCore のテスト（Linux）
- アプリのビルドとテスト（iOS シミュレータ）

## TestFlight への配布

配布は共通の仕組み [kajisho5/runway](https://github.com/kajisho5/runway) に任せています。

初回だけ必要な作業：

1. runway の配布先にこのリポを足す：https://github.com/kajisho5/runway/edit/main/repos.txt の末尾に `kajisho5/petacal` を足して「Commit changes」
2. Bundle ID を登録する：https://developer.apple.com/account/resources/identifiers/add/bundleId で App IDs → App → Explicit に `com.seventhwell.petacal` を入れて Register
3. アプリを作る：https://appstoreconnect.apple.com/apps の「＋」→「新規 App」（iOS、Bundle ID は 2 のもの）

実行：https://github.com/kajisho5/petacal/actions/workflows/testflight.yml の「Run workflow」。

届かないときは https://github.com/kajisho5/petacal/actions/workflows/testflight-status.yml を実行して状態を見ます。
