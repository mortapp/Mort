# MORT Final Google Play Asset Manifest

Status: generated and machine-validated for Play Console setup. These are emulator captures from the signed release-mode Android build, not physical-device evidence.

## Brand assets

| Asset | Path | Required dimensions | Status |
| --- | --- | ---: | --- |
| App icon | `build/play/store-assets/app-icon/mort-play-icon-512.png` | 512 x 512 | Generated |
| Feature graphic | `build/play/store-assets/feature-graphic/mort-feature-graphic-1024x500.png` | 1024 x 500 | Generated |

## Screenshot narrative

| Order | Caption | Accepted release capture |
| ---: | --- | --- |
| 1 | Earn nearby. Move smart. | `01-release-launch-clean.png` |
| 2 | Clear closed-pilot access and verification limits. | `03-account-status.png` |
| 3 | Safety tools and essential teen workflows stay easy to reach. | `04-teen-home.png` |
| 4 | Discover approved local opportunities without exposing exact addresses. | `05-job-feed-final.png` |
| 5 | Review scope, schedule, location type, and payment preference. | `06-job-detail-final.png` |
| 6 | Track applications and job-context next steps. | `07-applications-final.png` |
| 7 | Report, block, and Safety Ping tools remain free. | `08-safety-center.png` |
| 8 | Keep work, pay, and safety terms in a shared job agreement. | `09-contracts.png` |

Each narrative is generated at 1080 x 1920 in `phone-large` and 720 x 1280 in `phone-small`. The allowlist excludes the prior System UI ANR capture, empty fixture feed, raw contract hash, raw agreement identifier, sign-in credentials, and developer-error screens.

## Truthful limitations

- All people, places, jobs, applications, and agreements shown are isolated synthetic review data.
- No real faces, schools, home addresses, income, conversations, incidents, credentials, or precise coordinates are included.
- Tablet screenshots are intentionally omitted because tablet support has not completed physical-device testing.
- Small and large variants are Play-sized derivatives of the same accepted release-mode emulator captures. They do not prove physical small-screen or large-screen device testing.
- Final asset acceptance and any automated Play Console transformations remain external Google Play steps.

Run `powershell -ExecutionPolicy Bypass -File .\scripts\capture-final-play-assets.ps1`, then `node .\scripts\validate-final-play-assets.mjs`.
