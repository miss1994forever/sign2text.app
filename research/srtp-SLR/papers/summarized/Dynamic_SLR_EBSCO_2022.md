# Dynamic Sign Language Recognition Based on Real-Time Videos

## Basic Information
- Publisher/Date/Title: EBSCO, 2022, Dynamic Sign Language Recognition Based on Real-Time Videos
- Authors & Affiliations: Al-Mohimeed, Bushra A.; Al-Harbi, Hessa O.; Al-Dubayan, Ghadah S.; Al-Shargabi, Amal A. (College of Computer, Qassim University)

## Contributions & Features
1. Real-time video-based sign language recognition
2. ConvLSTM architecture for spatiotemporal feature learning

## Task
Develop a real-time sign language recognition system for Saudi Sign Language using ConvLSTM architecture

## Challenges
1. Computational resource limitations
2. Data scale constraints
3. Real-time processing requirements

## Methods
1. ConvLSTM Architecture:
   - Two ConvLSTM layers (3x3 kernel, 64 filters)
   - Replaced FC layers with convolution layers
   - Dropout, flatten, and dense layers
   - SoftMax activation for classification
2. Training Configuration:
   - 35 epochs
   - Batch size of 8
   - Learning rate of 0.001

## Data
1. Dataset:
   - Based on 2018 Saudi Deaf Association dictionary
   - 35 dynamic gestures (health/disease domain)
   - 3454 total videos (~98 per class)
2. Experiment Setup:
   - 6 classes selected
   - 585 videos (468 training, 117 testing)
3. Collection Method:
   - Smartphone camera recording
   - Various lighting conditions
   - Different backgrounds and locations
   - Multiple age groups

## Evaluation
1. Model Performance:
   - 70% average accuracy across 6 classes
   - Metrics: accuracy, precision, recall, F1-score
2. Confusion Matrix Analysis:
   - Detailed performance per class

## Limitations
1. Limited Class Coverage:
   - Only tested on 6 out of 35 classes
   - Computational resource constraints
2. Dataset Scale:
   - Limited data volume for real-world applications
3. Future Expansion:
   - Need to cover all Saudi Sign Language dictionary domains

## Reference
Based on 2018 Saudi Deaf Association dictionary
