# Task

## Breakdown

- paper summary
    - 10+ papers
- products research
    - PPT, excel

- product
    - User interface
    - train model?
        - data collection
        - data cleaning
        - model training
        - model evaluation
        - model deployment

- feature
    - add new sign vocabulary
        - record a new gesture, save to database, will be later recognized by the product

- 1 professor
    - 1 grad student
    - 3 undergrad

https://github.com/baharudin-yusup/salingsapa

https://github.com/Anshu-Gulati/Sign-Language-Recognition-App-using-Flutter-and-ML

https://github.com/harshbg/Sign-Language-Interpreter-using-Deep-Learning

- 9.1: goal/vision, precsion/recall
    - IOS app demo
- 9.15

## 

```md
├── ml/
│ ├── notebooks/ # Jupyter notebooks for data exploration and prototyping.
│ ├── data_processing/ # Scripts to clean, label, and prepare data for training.
│ ├── models/ # Python files defining your neural network architectures.
│ ├── training/ # Scripts to train your models.
│ ├── evaluation/ # Scripts to evaluate model accuracy (e.g., WER).
│ ├── requirements.txt # Python dependencies (e.g., tensorflow, pytorch, opencv).
│ └── export_model.py # Script to convert the trained model to Core ML format.
```

## Model Training

## IOS app development

- API integration
    - image -> text
    - video -> text

## Current Integration Direction

- Keep `sign2text.app/apps/expo-client` as the UI/client layer.
- Treat `/root/autodl-tmp/SLRT/Online` as the backend inference layer, not an on-device model.
- Build a session-based backend service between the app and SLRT Online.
- Use Online CSLR for gloss prediction and Online SLT for final text.

## Required Technical Shift

- Replace single-image polling with streaming frames or short clips.
- Replace Roboflow-style one-request-per-image API usage with WebSocket or session-based HTTP streaming.
- Add backend-side keypoint extraction unless you intentionally move pose estimation onto the device.

## Concrete App Work Items

- `components/CameraView.tsx`
    - Replace `takePictureAsync()` polling with streaming-oriented capture.
- `components/SignLanguageDetector.tsx`
    - Add start-session, stop-session, streaming, and partial-result handling.
- `services/signLanguageService.ts`
    - Remove Roboflow-specific request/response handling.
    - Replace with backend session and streaming client logic.
- `services/types.ts`
    - Change from one-shot `processFrame` API to a realtime session contract.
- `services/apiConfig.ts`
    - Define backend REST/WebSocket endpoints for the SLRT service.

## Backend Work Items

- Create a Python service wrapper around the working Online CSLR runtime.
- Refactor `prediction_slide.py` logic into reusable session classes.
- Add an Online SLT stage for gloss-to-text output.
- Return partial translations and final translations to the app.

## Delivery Phases

1. Backend smoke test with prerecorded frames
2. Expo app connected to backend with low-rate frame upload
3. Partial gloss/text updates in the UI
4. True realtime camera streaming path

See `SLRT_ONLINE_APP_INTEGRATION.md` for the full technical plan.

- image API integration
    - camera -> button (take photo) -> image -> call API -> text

- video API integration


## (other) mac config 

https://github.com/githubnext/monaspace

```sh
brew install --cask font-monaspace
```

Monaspace Argon


```json
    "editor.fontLigatures": "'calt', 'ss01', 'ss02', 'ss03', 'ss04', 'ss05', 'ss06', 'ss07', 'ss08', 'ss09', 'liga'",
```