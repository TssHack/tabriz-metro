# Contributing to Tabriz Metro

Thanks for helping riders of Tabriz Metro! / از مشارکت شما سپاسگزاریم!

## Ways to help

- **Report timetable or station data errors** — open an issue with the station,
  direction, day type and the correct time (a photo of the official poster helps).
- **Verify station coordinates** in `data/stations-geo.json` (set `"verified": true`
  once checked on the ground) and the holiday list in `data/iran-holidays.json`.
- Fix bugs, improve accessibility, translations or docs.

## Development

```bash
flutter pub get
dart format lib test
flutter analyze        # must report no issues
flutter test           # must pass
```

- Keep business logic in `lib/domain/` as **pure Dart** (no Flutter imports) and
  cover it with unit tests.
- Read colors only from the theme tokens (`context.tokens`); never hardcode colors
  in widgets.
- Add every user-facing string to **both** `lib/l10n/app_fa.arb` and
  `lib/l10n/app_en.arb`.
- The UI is RTL-first: prefer `EdgeInsetsDirectional`, `AlignmentDirectional`
  and `*Dir` icons for anything with a direction.

## Commits & pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org/):
  `feat(home): …`, `fix(data): …`, `test(domain): …`, `docs: …`, `ci: …`.
- Keep PRs small and focused; fill in the PR template.
- Update `CHANGELOG.md` under **Unreleased** for user-visible changes.

## Releasing (maintainers)

1. Update `version:` in `pubspec.yaml` and move **Unreleased** notes in `CHANGELOG.md`.
2. Tag: `git tag v0.2.0 && git push origin v0.2.0` (use `v0.2.0-beta.1` for beta).
3. The `Release` workflow builds APKs + web and publishes the GitHub Release with checksums.
