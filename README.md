# ペタカレ（仮称） / petacal

予定も、推し活も、収支も。写真で残せるカレンダー。iPhone／iPhone Duo／iPad／Mac 向け。

**開発中です。** いまは、iPhone に登録済みのカレンダーの予定を「日／週／月」で表示・追加でき、50色から色分けできます。記録（写真・金額・メモ）と集計のグラフも使えます。

## いまの状態

| 段階 | 内容 | 状態 |
|---|---|---|
| 1 | 骨組みと配布（空のアプリを TestFlight に出す） | 済み |
| 2 | 予定の表示・追加（日／週／月、予定の帯、色分け50色） | 済み（色の iCloud 同期は段階3で） |
| 3 | 記録（写真・金額・メモ、ロック）と集計のグラフ | 済み（iCloud 同期・無料／Pro の区別はこれから） |
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

1. runway の配布先にこのリポを足す（済み：runway の `repos.txt` に `kajisho5/petacal`）
2. Bundle ID `com.seventhwell.petacal` を登録する（`apple-setup` ワークフローが自動で行う）
3. アプリを作る（これだけ手作業。Apple の仕組み上、自動化できない）：https://appstoreconnect.apple.com/apps の「＋」→「新規 App」（iOS、Bundle ID は 2 のもの）

実行：https://github.com/kajisho5/petacal/actions/workflows/testflight.yml の「Run workflow」。

届かないときは https://github.com/kajisho5/petacal/actions/workflows/testflight-status.yml を実行して状態を見ます。
