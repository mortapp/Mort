# MORT Device Biometrics Limitations

## What is implemented

The SwiftUI app uses Apple's `LocalAuthentication` framework through `DeviceAuthenticationService` and `BiometricReauthenticationService`. It distinguishes Face ID, Touch ID, Optic ID, unavailable hardware, denied use, failed match, cancellation, lockout, and device-passcode fallback. A successful result grants a short-lived, one-action approval; failure clears approval and keeps the sensitive action blocked.

The intended protected actions include private-address reveal, payment preference changes, verification settings, incident records, account deletion/data export, session revocation, arrival confirmation, and proof confirmation.

## Hard boundary

Device authentication proves only that the operating system accepted an enrolled device owner/authenticator for that prompt. It does not reveal or establish legal name, age, address, school, government identity, criminal history, or document ownership. MORT receives no fingerprint, face template, image, or biometric material. The backend records only trusted-server audit metadata with `identity_effect = false`.

Required copy: "Face ID protects this MORT account on this device." Never state that Face ID or Touch ID verified identity.

Flutter Web does not access Face ID or Touch ID. It shows this limitation and keeps native-sensitive actions unavailable. Swift source passed static audit on Windows, but it has not been compiled in Xcode or tested on a physical iPhone.

Reference: [Apple LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
