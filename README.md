# SWIMETAR

SWIMETAR is a SwiftUI app for retrieving ATIS (Automatic Terminal Information Service) reports from the SWIM Web API for specified ICAO airport codes.

It is designed for quick access to airport weather and operational information in a simple, readable format, with support for multiple airports, sharing/exporting messages, and local credential storage in the Keychain.

## Features

- Enter one or more ICAO airport codes
- Fetch the latest ATIS information from SWIM
- View recent ATIS messages grouped by airport
- Adjust the number of messages to display
- Copy, share, or print ATIS reports
- Store SWIM credentials locally on the device using Keychain
- Built with SwiftUI for Apple platforms

## Supported Platforms

- iOS
- iPadOS
- macOS (via the Xcode project)

## Requirements

- Xcode 26 or later
- An Apple device or Mac capable of running the project
- Valid SWIM Web API credentials

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

## Usage

- Enter airport codes separated by commas, spaces, tabs, or newlines.
- Use the stepper to control how many ATIS entries are returned.
- Tap the action menu to copy, share, or print the currently displayed report.
- Credentials are saved in the device Keychain and reused for future requests.

## Project Structure

- `SWIM METAR/` — app source code
- `SWIM METAR.xcodeproj/` — Xcode project files
- `README.md` — project documentation
- `LICENSE` — MIT license

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
