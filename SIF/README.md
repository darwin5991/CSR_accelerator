# Data-Adaptive Hybrid Architecture: Design of CSR Format SpMV and  FPGA-based Comparative Performance Analysis
> **[2026 POLARIS Semiconductor Innovation Festival (SIF)](https://polargate.disu.ac.kr/contest/SIF2026/winner?sc=y)**
> Team-SRAM Orchestra (SRAM 오케스트라)
>

## Introduction
Sparse Matrix-Vector Multiplication (SpMV)을 가속하기 위해 설계된 FPGA 기반 하드웨어 가속기입니다.

AI 모델의 대형화로 연산량과 메모리 접근 병목이 심화되어 모델 경량화(Pruning)와 양자화(Quantization)가 필요합니다. 프루닝 방식으로는 하드웨어 가속에 유리한 구조적(Structured) 방법이 널리 쓰이지만, 블록 단위 제거로 인해 모델 표현력이 저하되어 압축률과 정확도 측면에서 한계가 있습니다.

본 프로젝트는 비구조적(Unstructured) 프루닝 결과를 CSR(Compressed Sparse Row) 포맷으로 변환해 저장 용량을 줄이고 zero‑skipping을 활용하는 하드웨어 가속기를 목표로 합니다.

한편, CSR은 희소도가 낮을 때 인덱스·메모리 오버헤드로 성능이 오히려 저하될 수 있습니다. 이에 입력 희소도에 따라 CSR과 Dense를 선택하는 데이터 적응형 하이브리드 아키텍처와, 이를 단일 SRAM으로 지원하는 메모리 인터페이스를 제안합니다.


##





