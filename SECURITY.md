# Security Policy

## Supported Versions

The latest commit on `main` is the supported development version.

## Reporting A Vulnerability

Please open a private security advisory on GitHub if you find a vulnerability.

Do not include sensitive screenshots, access tokens, certificates, or private keys in public issues.

## Security Notes

- The app is local-first and does not upload screenshots.
- Screen Recording permission is required for capture.
- Development signing scripts create local-only signing material and do not write certificates into the repository.
- Release builds should be signed and notarized with an Apple Developer ID certificate before distribution.
