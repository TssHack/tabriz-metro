<div align="center">

<img src="assets/logo/logo-red.svg" width="96" alt="Tabriz Metro logo">

# مترو تبریز · Tabriz Metro

اپلیکیشن متن‌باز و رایگان زمان حرکت قطارهای **خط ۱ متروی تبریز** (ائل گؤلی ⟷ نور)

A free, open-source timetable app for riders of **Tabriz Metro Line 1** (Eyl Goli ⟷ Noor)

[![CI](https://github.com/tsshack/tabriz-metro/actions/workflows/ci.yml/badge.svg)](https://github.com/tsshack/tabriz-metro/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[فارسی](#فارسی) · [English](#english)

</div>

> **اسکرین‌شات‌ها / Screenshots:** _به‌زودی — coming soon_ (`docs/screenshots/`)

---

## فارسی

### امکانات

- **قطارهای بعدی** از ایستگاه شما در هر دو جهت با شمارش معکوس دقیقه‌ای
- تشخیص خودکار **روز عادی / جمعه و تعطیل رسمی** (با امکان انتخاب دستی)
- **نقشه شماتیک خط** با موقعیت تخمینی قطارها بر اساس جدول زمان‌بندی
- **نقشه شهر** (OpenStreetMap) با نزدیک‌ترین ایستگاه، فاصله، زمان پیاده‌روی و «اگر الان راه بیفتی به قطار … می‌رسی»
- **جدول زمان‌بندی** کامل هر ایستگاه، گروه‌بندی‌شده بر اساس ساعت
- **جستجوی ایستگاه** با یکسان‌سازی حروف فارسی/عربی (ی/ي، ک/ك، نیم‌فاصله)
- **برنامه‌ریز سفر** با زمان پیاده‌روی، انتظار، مدت سفر و تعداد ایستگاه‌ها
- **اتوماسیون‌ها** (همه با اعلان محلی و بدون سرور): یادآور «الان راه بیفت»، هشدار یک ایستگاه قبل از مقصد، انتخاب خودکار نزدیک‌ترین ایستگاه، یادآور آخرین قطار، میانبر رفت‌وآمد روزانه
- پوسته روشن/تیره، ارقام فارسی/انگلیسی، زبان فارسی/انگلیسی، راست‌به‌چپ کامل
- **به‌روزرسانی درون‌برنامه‌ای** از GitHub Releases با بررسی SHA-256 (اندروید)
- حریم خصوصی: موقعیت مکانی فقط روی دستگاه پردازش می‌شود؛ هیچ داده‌ای به سرور ارسال نمی‌شود

همه زمان‌ها **تخمینی** و بر اساس پوسترهای رسمی هستند.

### منبع داده

- زمان‌بندی: پوسترهای رسمی سازمان قطار شهری تبریز (روزهای عادی مهر ۱۴۰۴ و جمعه/تعطیل) — [`data/`](data/README.md)
- مختصات ایستگاه‌ها و مسیر خط: [OpenStreetMap](https://www.openstreetmap.org/relation/6168103) (© OpenStreetMap contributors، ODbL)
- تعطیلات رسمی ۱۴۰۴–۱۴۰۵: [`data/iran-holidays.json`](data/iran-holidays.json)

> ⚠️ **نیاز به بازبینی:** مختصات ایستگاه‌ها از OSM گرفته شده و رسماً تأیید نشده‌اند (ایستگاه «سالار ملی» در OSM با نام «میدان قطب» ثبت شده و بر اساس ترتیب مسیر تطبیق داده شده است). تاریخ تعطیلات قمری محاسبه‌شده‌اند و ممکن است ±۱ روز با تقویم رسمی تفاوت داشته باشند.

### ساخت و اجرا

پیش‌نیاز: Flutter stable (Dart 3)

```bash
flutter pub get
flutter run
```

### مشارکت

از مشارکت شما استقبال می‌کنیم! راهنما: [CONTRIBUTING.md](CONTRIBUTING.md). گزارش مشکل: [Issues](https://github.com/tsshack/tabriz-metro/issues/new).

---

## English

### Features

- **Next trains** from your station in both directions with a live minute countdown
- Automatic **weekday vs. Friday/holiday** timetable (with manual override)
- **Schematic line map** with train positions estimated from the timetable
- **City map** (OpenStreetMap): nearest station, distance, walking time and "leave now and you'll catch the HH:MM train"
- Full per-station **timetable** grouped by hour, auto-scrolled to now
- **Station search** with Persian/Arabic normalization (ی/ي, ک/ك, ZWNJ)
- **Trip planner**: walk, wait, ride time, stop count — all labelled as estimates
- **Automations** (local notifications only, no server): leave-now reminder, destination alert one stop before arrival, auto-select nearest station, last-train reminder, daily commute shortcut
- Light/dark theme, Persian/Latin digits, Persian/English UI, full RTL
- **In-app updater** from GitHub Releases with SHA-256 verification (Android)
- Privacy: location is processed on device only; nothing is sent to any server

### Build

Requires Flutter stable (Dart 3).

```bash
flutter pub get
flutter gen-l10n          # also runs automatically on pub get
flutter analyze
flutter test
flutter run               # or: flutter build apk / flutter build web
```

### Project structure

```
lib/
  app/        app widget, router, providers, settings
  core/       theme tokens, l10n helpers, Persian digits/search, widgets
  data/       models, JSON parsing, repositories (assets, GitHub releases)
  domain/     pure Dart: schedule engine, holidays, geo, trip planner,
              reminders, semver/update selection (no Flutter imports)
  features/   one folder per screen
  l10n/       ARB files (fa is the template)
data/         timetable, station coordinates, holiday list
```

### Releases & signing

Pushing a tag `vX.Y.Z` (or `vX.Y.Z-beta.N` for the beta channel) runs
[`release.yml`](.github/workflows/release.yml): it builds split-per-ABI and
universal APKs plus a web bundle, writes `<file>.sha256` and `checksums.txt`,
and publishes a GitHub Release. The in-app updater refuses to install an APK
without a matching checksum.

For a properly signed release, add these repository secrets:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. Locally you can use `android/key.properties`
(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`; git-ignored).
**Without them, release APKs are signed with the debug key** — fine for
testing, but users cannot later upgrade to a differently signed build without
uninstalling.

### Data sources

- Timetable: official posters of the Tabriz Urban Railway Organization (Mehr 1404) — see [`data/README.md`](data/README.md)
- Station coordinates and line shape: [OpenStreetMap](https://www.openstreetmap.org/relation/6168103), © OpenStreetMap contributors, ODbL
- Official holidays 1404–1405: [`data/iran-holidays.json`](data/iran-holidays.json)

> ⚠️ **Needs verification:** station coordinates come from OSM and are not officially verified (OSM lists *Salar-e Melli* as "Meydan-e Qotb"; it was matched by route order). Lunar holiday dates are computed and may be off by ±1 day — check them against the official calendar before each release.

### Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md).

### License

[MIT](LICENSE) © 2026 Ehsan Fazli ([@TssHack](https://github.com/tsshack)).
The Vazirmatn font is licensed under the [SIL Open Font License 1.1](assets/fonts/vazirmatn/OFL.txt).
