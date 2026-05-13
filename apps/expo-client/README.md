# Sign2Text App

This folder contains the current Expo-based iOS app prototype for sign-language-to-text interaction.

Canonical path:
- `/home/haojun/projects/sign2text.app/apps/expo-client`

Compatibility path:
- `/home/haojun/projects/sign2text.app/Sign2text`

## Current State

- The app UI exists and already includes camera, translation display, and service-layer placeholders.
- The current service implementation is still image-oriented and Roboflow-style, not connected to SLRT Online.
- The confirmed working SLRT Online inference path currently lives in `/home/haojun/projects/SLRT/Online/CSLR` and runs on the GPU server, not on-device.

## Important Limitation

The current app is not yet doing real-time SLRT inference.

Right now the app:
- captures still photos with `expo-camera`
- sends single-frame payloads
- expects one-shot text/object-detection-like responses

SLRT Online instead requires:
- a continuous frame stream
- per-session temporal buffering
- sliding-window inference over frame sequences
- gloss decoding
- an optional gloss-to-text stage for natural-language output

## Development Commands

```bash
cd /home/haojun/projects/sign2text.app/apps/expo-client
npm install
npx expo start
```

## Integration Docs

Read these files before changing the app/backend boundary:

- `task.md`: product and implementation roadmap
- `SLRT_ONLINE_APP_INTEGRATION.md`: detailed architecture and step-by-step instructions for connecting this app to SLRT Online

## Current Files To Care About

- `components/CameraView.tsx`: current camera capture logic
- `components/SignLanguageDetector.tsx`: current translation screen orchestration
- `services/signLanguageService.ts`: current API client abstraction
- `services/types.ts`: service contract that should be expanded for streaming sessions

## Recommended Direction

For a prototype:
- keep the Expo UI
- add a backend inference service next to SLRT Online
- send low-rate frames or short clips to that backend

For real-time production-like behavior:
- move from still-photo polling to continuous frame streaming
- likely use a dev build plus a frame-processing camera stack instead of simple `expo-camera` polling
