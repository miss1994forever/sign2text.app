# How2Sign: A Large-scale Multimodal Dataset for Continuous American Sign Language

## Basic Information
- Publisher/Date/Title: IEEE, 2021, How2Sign: A Large-scale Multimodal Dataset for Continuous American Sign Language
- Authors & Affiliations: Amanda Duarte, Shruti Palaskar, Lucas Ventura, Deepti Ghadiyaram (Universitat Politècnica de Catalunya, Carnegie Mellon University)

## Contributions & Features
1. Development of How2Sign dataset (80+ hours of parallel ASL video corpus)
2. Rich annotation set including gloss labels and 2D/3D keypoints
3. Skeleton visualization and GAN-based video generation approaches

## Task
Create a comprehensive multimodal dataset for continuous ASL with parallel data and develop methods for sign language video generation

## Challenges
1. Complex Sign Features:
   - Manual features (handshape, orientation, movement, location)
   - Non-manual markers (head, mouth, eyebrows, facial grammar)
2. Co-articulation:
   - Transition handling in continuous signing
   - Grammar structure complexity
3. Data Diversity:
   - Limited vocabulary in existing datasets
   - Domain restrictions

## Methods
1. Data Collection:
   - Professional ASL interpreters
   - Multi-view recording setup
   - Panoptic Studio for 3D capture
2. Sign Generation:
   - Skeleton visualization from keypoints
   - GAN-based motion transfer (EDN method)
3. Data Processing:
   - Sentence-level segmentation
   - Automated pose estimation
   - Manual gloss annotation

## Data
1. Dataset Scale:
   - 80+ hours of multi-view ASL
   - 35,000+ sentences
   - 16,000 English word vocabulary
2. Multimodal Content:
   - RGB video
   - Depth information
   - 2D/3D keypoints
   - Audio signals
   - English transcription
   - Gloss annotation

## Evaluation
1. Classification Accuracy
2. Mean Opinion Score (MOS)
3. BLEU scores for generated videos
4. ASL user comprehension tests

## Limitations
1. Limited Diversity:
   - Restricted variety in ethnicity/race
   - Limited background/lighting conditions
2. Generation Quality:
   - Hand and facial detail limitations
   - Fast motion handling issues
3. Comprehension Gaps:
   - Generated videos lack nuanced expressions

## Reference
Dataset: [How2Sign](http://how2sign.github.io/)
