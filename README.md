<!-- # CSR_Accelerator

MLP 및 행렬 연산을 가속하기 위한 프로젝트

각 폴더의 06_docs 폴더의 자료를 참고해주세요.

SIF 프로젝트에서 csr 형태를 이용하여 희소 행렬의 연산을 가속하는 가속기를 설계

DASH Lab 프로젝트에서는 pruning과 quantization을 적용하여 CNN 모델을 경량화 하는 프로젝트를 진행
이후 경량화 한 모델을 csr 가속기에서 연산할 수 있도록 설계 및 구현



## SIF 프로젝트
2025.11~2026.01 

'ASIC 설계' 과목 프로젝트를 발전 시켰음
기존 프로젝트는 8비트 unsigned 정수 32x32 행렬 GEMM 연산
sram 3개

32x32 행렬 , 32x1 벡터 곱 연산 하는 가속기
csr 형식으로 sparse 행렬 표현

CSR 형식은 행렬의 non-zero 원소들을 저장하는 방식
행렬의 각 행마다 non-zero 원소의 값과 열 인덱스를 저장
0인 값은 곱셈에서 무시(zero skipping)

하지만 CSR 형식은 행렬의 sparsity가 높을 때 효율적이지만, 낮을 때는 오히려 메모리 사용량이 증가할 수 있음
sparsity에 따라서 dense 형식과 CSR 형식 중에서 선택적으로 사용할 수 있도록 설계
단일 sram으로 csr과 dense 형식 모두 지원하도록 설계

fpga에도 구현
uart 모듈

MAC은 1개
확장해서 50x50 행렬 곱까지 해봤음





## DASH Lab

2025.12~2026.02 

Dash Lab 학부연구생 인턴 프로젝트
Pruning and quantization을 적용한 CNN 모델을 NPU에서 실행하기 위한 프로젝트입니다.

CIFAR-10 데이터셋
VGG-16 모델
baseline 정확도 94.16% 

다양한 pruning과 quantization 방법을 적용하면서 비교

8비트 linear quantization 적용
pruning은 unstructured pruning 적용 

cnn layer는 pytorch에서 pruning과 quantization 적용하지 않은 output 사용
FC layer(MLP)만 pruning과 quantization 적용

적용 후 정확도 94.07%
전체 layer 적용해도 정확도 얼마 차이 안남(기억은 안 나요)

512x512 행렬 곱까지 가속 가능
MAC 4개 (조금 애매함)

행렬을 128x128의 sub-matrix로 나누어서 처리
 -->
# CSR_Accelerator

MLP 및 행렬 연산을 가속하기 위한 프로젝트입니다. 상세 자료는 각 폴더의 `06_docs`를 참고해 주세요.

---

## 1. 프로젝트 개요 및 당면 과제

### 1) 통합 및 체계화 필요성

* **현황:** SIF 프로젝트(가속기 구조 설계)와 DASH Lab 프로젝트(모델 경량화 및 매핑)를 병합하여 진행 중.
* **문제점:** 양 프로젝트의 연산 사양과 데이터 흐름이 파편화되어 있어 구조적 체계화가 시급함.
* **해결 방향:** 하드웨어 아키텍처와 소프트웨어 매핑 파이프라인의 인터페이스를 단일 프레임워크로 통합 및 구조화.

### 2) 기능 확장 목표 (CNN Layer 가속 지원)

* **현황:** 현재 가속기는 FC 레이어(MLP)의 행렬-벡터 곱 연산만 가속 가능.
* **목표:** 합성곱 레이어(CNN Layer) 연산까지 처리할 수 있도록 아키텍처 확장.
* **구현 방안:** 2D Convolution 연산을 행렬 곱 형태로 변환하는 im2col(Image to Column) 배열 변환기 모듈 또는 CNN 전용 데이터 패스 설계 추가.

---

## 2. SIF 프로젝트 (희소 행렬 가속기 설계)

* **수행 기간:** 2025.11 ~ 2026.01
* **기반 활동:** 학부 'ASIC 설계' 과목 프로젝트 발전 (기존: SRAM 3개 기반, 8-bit Unsigned 32x32 GEMM)

### 1) 하드웨어 사양

* 32x32 행렬과 32x1 벡터 곱 연산 수행.
* 최대 50x50 행렬 곱 연산까지 확장 가능성 검념.
* 1개의 MAC(Multiply-Accumulate) 연산기 사용.
* UART 모듈 포함, FPGA 상에서 동작 검증 완료.

### 2) CSR 및 하이브리드 아키텍처

* **CSR 형식 도입:** Non-zero 원소의 값과 열 인덱스만 저장하여 0인 값의 연산을 건너뛰는 Zero Skipping 구현.
* **하이브리드 모드:** 희소도(Sparsity)가 낮을 때 CSR 형식의 메모리 오버헤드가 커지는 문제를 해결하기 위해, Dense 형식과 CSR 형식을 선택적으로 지원.
* **메모리 최적화:** 단일 SRAM으로 두 형식(CSR/Dense)을 모두 처리하도록 통합.

---

## 3. DASH Lab 프로젝트 (모델 경량화 및 매핑)

* **수행 기간:** 2025.12 ~ 2026.02
* **기반 활동:** DASH Lab 학부연구생 인턴십

### 1) 모델 경량화 결과

* **대상:** CIFAR-10 데이터셋 기반 VGG-16 모델.
* **기법:** 8-bit Linear Quantization 및 Unstructured Pruning 적용 (FC 레이어에 집중 적용).
* **정확도:** Baseline 94.16%에서 경량화 후 94.07%로 유지하며 데이터 크기 축소.

### 2) 가속기 확장 및 타일링

* 최대 512x512 행렬 곱 연산 가속 지원.
* 대용량 행렬을 128x128 크기의 서브 행렬(Sub-matrix)로 분할 처리하는 타일링 기법 적용.
* 4개의 MAC 연산기 활용 구조 확장.
