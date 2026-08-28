# app-ads.txt Hosting

The repo contains `app-ads.txt` with:

```text
google.com, pub-9412242686563958, DIRECT, f08c47fec0942fa0
```

## Required Hosting

Host this file at the root of the developer website listed in App Store Connect and AdMob:

```text
https://YOUR-DEVELOPER-DOMAIN.com/app-ads.txt
```

It is not enough for the file to exist in the app repo. Google must be able to crawl it from the public developer domain.

## Verification

1. Publish the file.
2. Open the exact public URL in a browser.
3. Confirm the line matches the repo exactly.
4. Wait for AdMob to recrawl.
5. Confirm AdMob no longer reports app-ads.txt warnings.
