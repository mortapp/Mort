# MORT Location Threat Model

## Protected data

- Teen current or historical coordinates
- Adult residential coordinates
- Exact job address and access instructions
- Temporary safety-location context
- Search area, timestamps, and movement-derived risk signals

## Current architecture

Public jobs expose only authored general-area fields. The new mobile lookup is user initiated, requests only foreground access, resolves one current position to city/state through the platform geocoder, then discards raw coordinates. Manual city/state search always remains available. Existing temporary safety shares are backend-authorized, coarse, time-limited records; they are off by default and can be stopped. Android requests no background-location permission.

## Threats and controls

| Threat | Current control | Residual risk / next gate |
|---|---|---|
| Poster tracks a teen | no live teen coordinates in feed or poster queries | rerun RLS and device traffic inspection before public pilot |
| Teen enumerates a residence | exact job location remains in restricted backend flow | dedicated anti-enumeration RPC/rate limits are still required for radius search |
| Permission coercion | manual city/state remains first-class | UX/device test with denied and permanently denied states |
| Background surveillance | no Android background permission; no continuous stream | verify merged manifests every release |
| Stale or inaccurate geocoder result | area is editable and used only as coarse filter | show broad-area uncertainty in future radius UI |
| Mock/spoofed location | no automatic fraud conclusion | future signals must be private, appealable, and combined with other evidence |
| Sensitive app-switcher snapshot | privacy cover on lifecycle change; Android secure flag on sensitive routes | physical-device screenshot and recents testing pending |
| Location retained in logs | raw coordinates are not logged or sent by area lookup | inspect crash/analytics tooling before adding any provider |

## Explicit non-claims

Location does not prove identity, attendance, work completion, payment, fraud, or safety. MORT does not currently provide emergency dispatch, continuous guardian tracking, a public map of residences, or a PostGIS radius-search guarantee.
