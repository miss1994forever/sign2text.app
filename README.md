# Sign2Text Workspace

This folder now uses a role-based top-level layout.

## Canonical Structure

```text
sign2text.app/
├── apps/
│   ├── expo-client/      # Active Expo / React Native client
│   └── ios-native/       # Native Swift / Xcode app
├── backend/
│   └── sign2text-ml/     # FastAPI + SLRT inference service
├── research/
│   └── srtp-SLR/         # Literature notes, papers, notebooks
├── Sign2text -> apps/expo-client
├── sign2text-app -> apps/ios-native
├── sign2text-ml -> backend/sign2text-ml
└── srtp-SLR -> research/srtp-SLR
```

## Canonical Paths

- Expo client: `/home/haojun/projects/sign2text.app/apps/expo-client`
- Native iOS app: `/home/haojun/projects/sign2text.app/apps/ios-native`
- Backend service: `/home/haojun/projects/sign2text.app/backend/sign2text-ml`
- Research archive: `/home/haojun/projects/sign2text.app/research/srtp-SLR`

## Compatibility Paths

The older top-level names are still present as symlinks so existing scripts and notes continue to work:

- `Sign2text`
- `sign2text-app`
- `sign2text-ml`
- `srtp-SLR`

Use the canonical paths for new work.