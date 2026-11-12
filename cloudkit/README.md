# CloudKit のデータの形（スキーマ）

記録（`Record`）と写真（`RecordPhoto`）を iCloud でそろえるときの、CloudKit の形です。SwiftData が使う名前の決まり（`CD_` ＋項目名）で書いています。

- TestFlight と App Store のアプリは、CloudKit の**本番**の環境を使う。本番の形は CloudKit Console の「Deploy Schema Changes」ボタンでしか入れられず、入れた項目はあとから消せない。
- コマンド（`cktool`）で入れられるのは**開発用**の環境だけ。`.github/workflows/cloudkit-schema.yml` がこのファイルを開発用の環境に入れる（`validate` で確かめ、`import` で入れ、`export` で今の形を書き出す）。
- 項目を足したら、このファイルも足す（消すことはできない）。

【推測】項目名と型は SwiftData（Core Data の CloudKit 連携）の決まりから書いたもので、実際にアプリが書き込んだ形とはまだ照らし合わせていない。`export` の結果と見比べて直す。
