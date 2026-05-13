# CSL-Daily vocabulary breakpoint summary

Selection rule: top-N glosses by training token frequency. This is exactly optimal for training token coverage.

## Coverage by vocabulary size

| Vocab size | Train token | Dev token | Test token | Train exact sample | Dev exact sample | Test exact sample |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 200 | 61.33% | 59.37% | 58.80% | 5.57% | 0.28% | 0.26% |
| 300 | 69.08% | 66.41% | 66.17% | 11.84% | 2.04% | 1.79% |
| 400 | 74.91% | 72.03% | 71.91% | 18.90% | 5.29% | 5.10% |
| 500 | 79.47% | 76.50% | 76.47% | 25.80% | 11.79% | 10.54% |
| 600 | 83.35% | 80.64% | 80.50% | 33.99% | 18.01% | 17.60% |
| 700 | 86.62% | 84.57% | 84.49% | 42.13% | 25.44% | 25.51% |
| 800 | 89.30% | 87.97% | 87.92% | 49.92% | 33.43% | 34.01% |
| 1000 | 93.04% | 92.87% | 93.00% | 64.15% | 55.80% | 56.89% |
| 1200 | 95.54% | 96.76% | 96.86% | 74.71% | 78.09% | 78.06% |

## Threshold scan

| Target | Smallest vocab size |
| --- | ---: |
| Dev token coverage >= 70% | 400 |
| Test token coverage >= 70% | 400 |
| Dev token coverage >= 80% | 600 |
| Test token coverage >= 80% | 600 |
| Dev exact sample coverage >= 5% | 400 |
| Test exact sample coverage >= 5% | 400 |
| Dev exact sample coverage >= 10% | 500 |
| Test exact sample coverage >= 10% | 500 |
| Dev exact sample coverage >= 20% | 700 |
| Test exact sample coverage >= 20% | 700 |
| Dev exact sample coverage >= 30% | 800 |
| Test exact sample coverage >= 30% | 800 |

## Practical reading

- 300 words is still too small for sentence-level use: dev/test exact sample coverage stays around 2%.
- 500 words is the first barely usable point for closed-vocabulary sentence filtering: dev/test exact sample coverage reaches about 10%-12%.
- 700 to 800 words is the first practical band if you want both token coverage above 84% and exact sentence coverage above 25%-30% on dev/test.
- 1000 words is the first clearly comfortable point for sentence-level work: dev/test exact sample coverage passes 55% and token coverage reaches about 93%.
- 1200 words is the first strong point if you want most held-out sentences to remain usable without aggressive OOV handling: dev/test exact sample coverage is about 78%.