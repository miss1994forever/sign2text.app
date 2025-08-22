# Mexican Sign Language Recognition Using Depth Camera and RNN

## Basic Information
- Publisher/Date/Title: MDPI, 2022-03-29, Automatic Recognition of Mexican Sign Language Using a Depth Camera and Recurrent Neural Networks
- Authors & Affiliations: Kenneth Mejía-Peréz, Diana-Margarita Córdova-Esparza*, Juan Terven, Ana-Marcela Herrera-Navarro, Teresa García-Ramírez, Alfonso Ramírez-Pedraza (Faculty of Informatics, Autonomous University of Queretaro)

## Contributions & Features
1. Multi-modal gesture integration (hand, upper body keypoints, face)
2. 3D action coordinates
3. Enhanced robustness through Gaussian noise injection

## Task
Develop a robust sign language recognition system using depth camera and RNN architectures

## Challenges
1. Traditional limitations:
   - Translation gloves: invasive despite low computational cost
   - RGB cameras: limited by lighting, focus, and image orientation
2. Need for robust feature extraction from multiple modalities
3. Handling temporal dependencies in gesture sequences

## Methods
1. Model Architecture:
   - Evaluated three architectures: RNN, LSTM, and GRU
   - Two-layer model with noise enhancement and dropout
2. Training:
   - 70% training, 15% validation, 15% testing
   - Cross-entropy loss with Adam optimizer
   - Early stopping (patience=100) for 300 epochs
3. Robustness Testing:
   - Created 5 additional test sets with noise (σ=10-50cm)
4. Ablation Studies:
   - Architecture variations (1-3 layers)
   - Feature combination experiments
   - Noise enhancement strategies

## Data
1. Dataset Composition:
   - 30 different gestures
   - 4 people × 25 repetitions each
   - Total 3000 samples
   - 20 consecutive frames per gesture
2. Data Collection:
   - OAK-D camera for depth information
   - DepthAI and MediaPipe for joint detection
   - 20 facial, 5 body, 21 hand points per frame
3. Coordinate Processing:
   - Normalization relative to chest position

## Evaluation
1. Performance Metrics:
   - Accuracy
   - Precision
   - Recall
2. Robustness Analysis:
   - Testing with various noise levels
   - Feature ablation results

## Limitations
1. Limited Dataset Size:
   - Only 3000 samples covering 30 gestures
   - May not fully represent MSL complexity
2. Robustness Constraints:
   - Artificial Gaussian noise may not reflect real-world conditions
3. Real-time Performance:
   - No explicit evaluation of real-time capabilities

## Reference
Code and Data: https://github.com/ICKMejia/Mexican-Sign-Language-Recognition
