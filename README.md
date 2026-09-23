# SWIMETAR

SWIMETAR is a SwiftUI app for retrieving ATIS (Automatic Terminal Information Service) reports from the SWIM Web API for specified ICAO airport codes.

SWIMETAR は、指定した ICAO 空港コードの ATIS（Automatic Terminal Information Service）を SWIM Web API から取得して表示する SwiftUI アプリです。

SWIM (System Wide Information Management) is a civil aviation information-sharing framework operated by the Civil Aviation Bureau of the Ministry of Land, Infrastructure, Transport and Tourism. It provides standardized access to aeronautical and weather information, including airport operational status, flight information, and other data used by aviation stakeholders. This app focuses on ATIS delivered through the SWIM Web API.

SWIM（System Wide Information Management）とは、国土交通省航空局が運用する航空情報の共有基盤です。空港運航情報、気象情報、飛行情報などの航空関連データを標準化された方式で提供し、航空関係者が安全かつ効率的に情報を利用できるようにする仕組みです。SWIMETAR は、この SWIM Web API を通じて ATIS を取得し、簡単に確認できるようにしたアプリです。

## Features

- Enter one or more ICAO airport codes
- Fetch the latest ATIS information from SWIM
- View recent ATIS messages grouped by airport
- Adjust the number of messages to display
- Copy, share, or print ATIS reports
- Store SWIM credentials locally on the device using Keychain
- Built with SwiftUI for Apple platforms

## 機能

- 1つ以上の ICAO 空港コードを入力できる
- SWIM から最新の ATIS 情報を取得できる
- 空港ごとに最近の ATIS メッセージを表示できる
- 表示件数を調整できる
- ATIS レポートをコピー、共有、印刷できる
- SWIM の認証情報を端末の Keychain に保存できる
- Apple プラットフォーム向けに SwiftUI で開発されている

## Supported Platforms

- iOS
- iPadOS
- macOS (via the Xcode project)

## 対応プラットフォーム

- iOS
- iPadOS
- macOS（Xcode プロジェクト上で利用可能）

## Requirements

- Xcode 26 or later
- An Apple device or Mac capable of running the project
- Valid SWIM Web API credentials

## 必要条件

- Xcode 26 以降
- アプリを実行できる Apple デバイスまたは Mac
- 有効な SWIM Web API の認証情報

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/halka/SWIMETAR.git
   cd SWIMETAR
   ```
2. Open `SWIM METAR.xcodeproj` in Xcode.
3. Build and run the app on a simulator or device.
4. Enter your SWIM API email and password when prompted.
5. Add ICAO airport codes such as `RJTT`, `RJAA`, or `RJCH` and fetch ATIS.

## はじめ方

1. リポジトリをクローンする:
   ```bash
   git clone https://github.com/halka/SWIMETAR.git
   cd SWIMETAR
   ```
2. Xcode で `SWIM METAR.xcodeproj` を開く。
3. シミュレータまたは実機でビルドして実行する。
4. 起動時に表示される画面で SWIM API のメールアドレスとパスワードを入力する。
5. `RJTT`、`RJAA`、`RJCH` などの ICAO 空港コードを入力して ATIS を取得する。

## Usage

- Enter airport codes separated by commas, spaces, tabs, or newlines.
- Use the stepper to control how many ATIS entries are returned.
- Tap the action menu to copy, share, or print the currently displayed report.
- Credentials are saved in the device Keychain and reused for future requests.

## 使い方

- 空港コードはカンマ、スペース、タブ、改行で区切って入力できる。
- ステッパーで表示する ATIS 件数を調整できる。
- アクションメニューから、現在表示中のレポートをコピー、共有、印刷できる。
- 認証情報は端末の Keychain に保存され、次回以降も再利用される。

## Project Structure

- `SWIM METAR/` — app source code
- `SWIM METAR.xcodeproj/` — Xcode project files
- `README.md` — project documentation
- `LICENSE` — MIT license

## プロジェクト構成

- `SWIM METAR/` — アプリ本体のソースコード
- `SWIM METAR.xcodeproj/` — Xcode プロジェクトファイル
- `README.md` — プロジェクトの説明書
- `LICENSE` — MIT ライセンス

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## ライセンス

本プロジェクトは MIT License のもとで提供されています。詳細は [LICENSE](LICENSE) ファイルをご覧ください。
