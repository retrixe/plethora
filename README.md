# plethora

An app for you to put links to your favourite GIFs in.

## KLIPY API support

The app reads `KLIPY_APP_KEY` at compile time through `envied`. If `tool/klipy.env` is missing or empty, the app still runs, but scraping KLIPY GIF URLs may be blocked by CloudFlare. With a key present, it can also resolve `klipy.com/gifs/...` share pages through the KLIPY API.

Use a local file like this in `tool/klipy.env` to provide your key:

```env
KLIPY_APP_KEY=your_key_here
```

Run it like this:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d linux
flutter build linux
```

If you change `tool/klipy.env` and the generated file still looks stale, run:

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```
