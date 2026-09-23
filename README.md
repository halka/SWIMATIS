# SWIMETAR

SWIMETAR is a SwiftUI application for retrieving and displaying ATIS (Automatic Terminal Information Service) information from the SWIM Web API for specified ICAO airport codes.

This application is intended for authorized users who have valid SWIM Web API credentials and a legitimate operational need to access aeronautical information. It is not a public information service for general consumers, and use by the general public is not expected or supported.

SWIMETAR は、指定した ICAO 空港コードに対応する ATIS（Automatic Terminal Information Service）を、SWIM Web API から取得して表示するための SwiftUI アプリケーションです。

**認可された利用者が SWIM Web API を通じて ATISを短時間で確認できるようにすることを目的としています。**

> [!WARNING]
>
> 航空関係者・認定ユーザー等の業務利用を想定しており、一般市民向けの情報閲覧アプリではありません。<br>
> 本アプリは、SWIM Web API の利用資格を有し、航空情報を業務上必要とする利用者を前提としています。<br>
> 利用には適切な認証情報、利用目的、及び情報提供者の条件を満たしていることが前提です。

## About SWIM

SWIM (System Wide Information Management) is an information-sharing framework for aviation data managed by the Civil Aviation Bureau of the Ministry of Land, Infrastructure, Transport and Tourism. It provides standardized access to airport operational information, weather information, flight information, and other relevant aeronautical data used by aviation stakeholders.

## SWIM について

SWIM（System Wide Information Management）は、国土交通省航空局が管理する航空情報の共有基盤です。空港運航情報、気象情報、飛行情報など、航空関係者が安全かつ効率的に利用するための各種データを標準化された方式で提供します。

## Features

- Enter one or more ICAO airport codes
- Retrieve the latest ATIS information from SWIM
- View recent ATIS messages grouped by airport
- Adjust the number of messages displayed
- Copy, share, or print ATIS reports
- Save SWIM credentials locally on the device using Keychain
- Built with SwiftUI for Apple platforms

## 機能

- 1つ以上の ICAO 空港コードを入力できる
- SWIM から最新の ATIS 情報を取得できる
- 空港ごとに直近の ATIS メッセージを表示できる
- 表示件数を調整できる
- ATIS レポートをコピー、共有、印刷できる
- SWIM の認証情報を端末の Keychain に安全に保存できる
- Apple プラットフォーム向けに SwiftUI で構築されている

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
- Appropriate authorization and compliance with the applicable usage conditions

## 必要条件

- Xcode 26 以降
- アプリを実行できる Apple デバイスまたは Mac
- 有効な SWIM Web API 認証情報
- 利用に必要な権限および適用される利用条件への適合

## Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/halka/SWIMETAR.git
   cd SWIMETAR
   ```
2. Open `SWIM METAR.xcodeproj` in Xcode.
3. Build and run the app on a simulator or device.
4. Enter your SWIM API email and password when prompted.
5. Add ICAO airport codes such as `RJTT`, `RJAA`, or `RJCH` and retrieve ATIS information.

## はじめ方

1. リポジトリをクローンします。
   ```bash
   git clone https://github.com/halka/SWIMETAR.git
   cd SWIMETAR
   ```
2. Xcode で `SWIM METAR.xcodeproj` を開きます。
3. シミュレータまたは実機でビルドして実行します。
4. 起動時に表示される認証画面で、SWIM API のメールアドレスとパスワードを入力します。
5. `RJTT`.`RJAA`,`RJCH` などの ICAO 空港コードを入力し、ATIS を取得します。

## Usage

- Enter airport codes separated by commas, spaces.
- Use the stepper to control the number of ATIS entries returned.
- Tap the action menu to copy, share, or print the currently displayed report.
- Credentials are saved in the device Keychain and reused for future requests.

## 使い方

- 空港コードはカンマ、スペースで区切って入力できます。
- ステッパーで表示する ATIS 件数を調整できます。
- アクションメニューから、現在表示中のレポートをコピー、共有、印刷できます。
- 認証情報は端末の Keychain に保存され、次回以降も再利用されます。

## Screenshots

The following sections are reserved for application screenshots and explanatory images. They will be added as the app interface and usage flow are finalized.

## スクリーンショット

以下のセクションは、アプリの画面イメージや操作説明用の画像を掲載するためのスペースです。アプリの画面構成と利用フローが固まった段階で、画像を追加する予定です。

- 画面1: 空港コード入力画面
- 画面2: ATIS 一覧表示画面
- 画面3: 共有・印刷・コピー操作メニュー
- 画面4: 認証情報の保存状態と利用画面

## Project Structure

- `SWIM METAR/` — application source code
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
