# kn_seatselect

[![Version](https://img.shields.io/badge/version-1.2.0-blue.svg)](CHANGELOG.md)
[![Framework](https://img.shields.io/badge/framework-Standalone-green.svg)](#導入)
[![License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

車両の近くで **乗車キー（既定 F）を長押し**すると座席選択 UI が開き、
選んだ席へ乗車する FiveM リソース。短押しは従来どおりの乗車。

standalone（フレームワーク不要 / サーバースクリプト無し / 完全クライアント側）。

## 由来

[SeatSelection by BeereMgM](https://github.com/BeereMgM/SeatSelection)（MIT）を基に、
座席 UI と「選んだ席へ乗車する」考え方を引き継ぎつつ、以下を作り直している。

- **長押し判定**（原案は単押しのみ）。長押しの開始でバニラの乗車が始まってしまう問題に対応するため、
  車両の近くにいる間だけ乗車 control を無効化し、短押しの乗車を自前で再現している
- **座席の占有表示**。原案は全席を同じ見た目で並べ、埋まっている席も押せた
- **座席番号の扱いを修正**。原案は席が埋まっていたときの代替席計算で UI 番号と GTA の座席
  インデックスを二重に変換しており、運転席が埋まっていると座席 -3（存在しない）を指していた
- **5 席目以降が無反応だった問題を修正**。原案はドアのボーン名を 4 席分しか持たず、
  該当しない席では乗車処理ごと打ち切られていた（バス等）
- **入力ガード**（NUI フォーカス中 / ポーズ中 / 乗車中 / 死亡中は反応しない）
- **施錠・大破車両の判定**、距離の再検証、ロケール（ja/en）分離

## 導入

1. `kn_seatselect` を `resources/` に置く
2. `server.cfg` に `ensure kn_seatselect`

依存リソースは無い。`ox_lib` があれば通知に使うが、無くても `chat` → GTA 標準通知に落ちる。

## 操作

| 操作 | 動作 |
|---|---|
| 車両の近くで **F 短押し** | 一番近いドアの空席に乗車（`Config.shortPress = 'driver'` で運転席優先） |
| 車両の近くで **F 長押し**（既定 300ms） | 座席選択 UI を開く |
| UI: クリック / 数字キー `1`〜`9` | その席へ乗車 |
| UI: `ESC` / パネル外クリック | 閉じる |

UI は画面を暗転させず、操作ヒントと同じ位置（画面下部）に出る 200px 幅のリスト。
ヒントがそのまま座席リストに入れ替わる。

## 主な設定（`config/config.lua`）

| キー | 既定 | 説明 |
|---|---|---|
| `locale` | `'ja'` | `'ja'` / `'en'` |
| `enterControl` | `23` | 監視する control ID（23 = INPUT_ENTER = 徒歩時の乗車） |
| `keyLabel` | `'F'` | UI ヒントに出すキー名（表示専用） |
| `holdMs` | `300` | 長押しと判定する時間 |
| `maxDistance` | `5.0` | 対象車両を拾う距離 |
| `suppressDefaultEnter` | `true` | 車両近くでバニラ乗車を無効化し短押しを自前実装する |
| `shortPress` | `'nearest'` | `'nearest'` / `'driver'` |
| `checkDoorLock` | `true` | 施錠された車両を弾く |
| `warpVehicleClasses` | `{}` | 歩かせず直接座らせる車両クラス |
| `correctSeatAfterEntry` | `true` | 乗車後に座席を確認し、違っていれば座り直す |
| `seatCorrectionDelayMs` | `700` | 座り直し判定までの待ち（自動シャッフルとの競合回避） |
| `frontSeatBias` | `0.35` | 短押しの距離判定で前席を優先する量（m）。`0.0` で無効 |
| `showHint` | `true` | 近づいたときの操作ヒント |

## 既知の制限

- **ヘリ / 飛行機**（クラス 15 / 16）も既定の `TaskEnterVehicle` で乗車できることを実機で確認済み。
  原案は航空機で経路探索を諦めて直接着席させていたが、その必要は無かった。
  万一乗れない機体があれば `Config.warpVehicleClasses = { [15] = true, [16] = true }` で
  直接着席に切り替えられる（見た目上は瞬間移動になる）。
- **座席の距離判定はドアではなく座席のボーンで行う**。ドアボーンはヒンジ位置にあり、
  後席ドアのヒンジが車体中央付近にあるため、ドア基準だと後席に判定が偏る。
- **完全にクライアント側**。座席の選択自体はバニラの乗車と同じくクライアントが決めるため、
  職業制限や車両所有者チェックを掛けたい場合は別途サーバー側の実装が必要。
- `suppressDefaultEnter = true` の間、車両から `maxDistance` 以内にいるとバニラの乗車操作が
  このリソース経由になる。他リソースが control 23 を独自に見ている場合は競合しうる。

## Credit / ライセンス

原作: **[SeatSelection](https://github.com/BeereMgM/SeatSelection)** by BeereMgM (MIT License)。
本リソースはその**フォーク**であり、原作と同じ MIT License で配布する。
`LICENSE` には原作の著作権表示を保持したまま、改変分の著作権表示を追記している。

原案のファイルをそのまま同梱しているものは無い。座席 UI の考え方と
「選んだ席へ乗車する」という設計を引き継いだうえで、実装は全面的に書き直している
(相違点は冒頭の「由来」を参照)。
