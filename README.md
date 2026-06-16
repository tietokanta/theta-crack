# ThetaCrack

A research project that demonstrates how to bypass the authentication flow in **Theta v6.0** by intercepting and faking the local network requests used for license verification.

This project was made for **educational and research purposes only**. By using it, you accept full responsibility for any consequences.

Telegram: [t.me/jailbreakland](https://t.me/jailbreakland)

## Requirements

- macOS with [Theos](https://theos.dev/) installed
- `ldid` and `insert_dylib` available in your PATH
- A decrypted copy of **Theta v6.0** named `theta.ipa` placed in `assets/theta.ipa`

## How it works

Theta communicates with its license server over HTTPS to endpoints like `/api/activate` and `/api/heartbeat`. This tweak hooks `NSURLSession` so those requests are intercepted inside the app process. The intercepted request is decrypted, a fake "active" response is generated, and it is encrypted back with the same keys before being returned to the app — making Theta think the license is valid.

Key parts:

- `src/TweakHTTP.m` — hooks `-[NSURLSession dataTaskWithRequest:completionHandler:]` and fakes activate/heartbeat responses.
- `src/TweakCrypto.m` — handles AES-256-CBC encryption/decryption and the wire format used by Theta.
- `src/TweakConfig.h` — static cryptographic keys.
- `src/TweakUI.m` — tweaks the in-app settings UI (Telegram link, footer text).
- `src/Tweak.m` — constructor, welcome alert, and automatic activation trigger.

## Building

1. Place your decrypted `theta.ipa` in `assets/theta.ipa`.
2. Run the build script:

```bash
./scripts/inject.sh
```

The cracked IPA will be written to `output/theta_cracked.ipa`.

You can also specify custom input/output paths:

```bash
./scripts/inject.sh -i ~/Downloads/theta.ipa -o ~/Desktop/theta_cracked.ipa
```

For a release build with debug symbols stripped (recommended for distribution):

```bash
./scripts/inject.sh -r
```

To build only the dylib without injecting it into an IPA:

```bash
./scripts/inject.sh -d -r
```

## Usage

After building, sign `output/theta_cracked.ipa` with your preferred sideloading tool and install it. The first time the app launches it shows a welcome popup; activation is triggered automatically once the popup is dismissed. On later launches, place three fingers on the screen and hold for 2 seconds to trigger activation.

## Disclaimer

This software is provided **as-is** for research and education. The author is not responsible for any misuse, account bans, legal issues, or damage caused by using this tool. You use it entirely at your own risk.
