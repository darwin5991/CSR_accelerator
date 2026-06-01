#import
from torch import nn,optim
import torch
from torchvision import datasets, transforms
from torch.utils.data import DataLoader, random_split
import numpy as np
from matplotlib import pyplot as plt
import os
import copy
import math
import sys
from tqdm.auto import tqdm

# ============================================================================
# ENCODING 함수
# ============================================================================

def encode_vector(val, bit_width):
    """벡터 → 이진 문자열 인코딩"""
    encoded = []
    for v in val:
        data = format(int(v) & (2**bit_width - 1), f"0{bit_width}b")
        encoded.append(data)
    return encoded


def bin_list_to_hex(bin_list, width_hex=0, upper=True):
    """이진 문자열 리스트 → 16진수 변환"""
    fmt = "X" if upper else "x"
    out = []
    for b in bin_list:
        h = format(int(b, 2), fmt)
        if width_hex:
            h = h.zfill(width_hex)
        out.append(h)
    return out


def encode_csr_sub(val, col_idx, row_num):
    """단일 부분행렬 CSR 인코딩 (가중치 & 행 번호)"""
    qw_data_mem = []
    for i in range(len(val)):
        if i == 0:
            data = format(int(val[-1]) & 0xFF, "08b") + format(col_idx[i], "07b")
        else:
            data = format(int(val[i-1]) & 0xFF, "08b") + format(col_idx[i], "07b")
        qw_data_mem.append(data)
    
    row_num_mem = []
    for i in range(len(row_num)):
        data = format(row_num[i], "07b")
        row_num_mem.append(data)
    
    return qw_data_mem, row_num_mem


def encode_csr(val_list, col_idx_list, row_num_list):
    """다중 부분행렬 CSR 인코딩"""
    qw_data_mem = []
    row_num_mem = []
    for i in range(len(val_list)):
        qw_data_sub, row_num_sub = encode_csr_sub(val_list[i], col_idx_list[i], row_num_list[i])
        qw_data_mem.extend(qw_data_sub)
        row_num_mem.extend(row_num_sub)
    return qw_data_mem, row_num_mem


# ============================================================================
# 데이터 분할 함수
# ============================================================================

def split_weight_matrix(weight_matrix, r_split=128, c_split=128):
    """
    가중치 행렬을 r_split × c_split 크기의 부분행렬로 분할
    
    Args:
        weight_matrix: shape (512, 512)
        r_split: 행 분할 크기
        c_split: 열 분할 크기
    
    Returns:
        splits: 4×4 부분행렬 리스트
    """
    splits = []
    for i in range(4):
        sub_matrix = []
        for j in range(4):
            row_start = i * r_split
            row_end = (i + 1) * r_split
            col_start = j * c_split
            col_end = (j + 1) * c_split
            
            sub_matrix.append(weight_matrix[row_start:row_end, col_start:col_end])
        splits.append(sub_matrix)
    
    return splits


def split_bias_vector(bias_vector, split_size=128):
    """편향 벡터를 split_size 크기로 분할"""
    splits = []
    for i in range(4):
        row_start = i * split_size
        row_end = (i + 1) * split_size
        splits.append(bias_vector[row_start:row_end])
    return splits


def split_input_data(input_tensor, split_size=128):
    """입력을 열 방향으로 split_size 크기로 분할"""
    splits = []
    for i in range(4):
        col_start = i * split_size
        col_end = (i + 1) * split_size
        splits.append(input_tensor[:, col_start:col_end])
    return splits


def split_output_data(output_tensor, split_size=128):
    """출력을 행 방향으로 split_size 크기로 분할"""
    splits = []
    for i in range(4):
        row_start = i * split_size
        row_end = (i + 1) * split_size
        splits.append(output_tensor[:, row_start:row_end])
    return splits


# ============================================================================
# CSR 변환 함수
# ============================================================================

def csr_gen_sub(weight_submatrix):
    """
    단일 부분행렬 → CSR 포맷 변환 (Compressed Sparse Row)
    
    Args:
        weight_submatrix: shape (128, 128) 부분행렬
    
    Returns:
        val: 0이 아닌 값들 리스트
        col_idx: 각 값의 열 인덱스
        row_num: 각 행의 0이 아닌 값 개수
        nnz: 전체 0이 아닌 값 개수
    """
    val = []
    col_idx = []
    row_num = []
    
    for i in range(weight_submatrix.shape[0]):
        row = weight_submatrix[i]
        indices = torch.nonzero(row).flatten().tolist()
        values = row[indices].tolist()
        
        row_num.append(len(values))
        val.extend(values)
        col_idx.extend(indices)
    
    nnz = len(val)
    return val, col_idx, row_num, nnz


def csr_gen(weight_matrix_list):
    """
    다중 부분행렬 → CSR 포맷 변환
    
    Args:
        weight_matrix_list: 부분행렬 리스트 (일반적으로 4개)
    
    Returns:
        val_list: 값 리스트
        col_idx_list: 열 인덱스 리스트
        row_num_list: 행 번호 리스트
        nnzs: 각 부분행렬의 0이 아닌 값 개수
    """
    val_list = []
    col_idx_list = []
    row_num_list = []
    nnzs = []
    
    for j in range(len(weight_matrix_list)):
        val, col_idx, row_num, nnz = csr_gen_sub(weight_matrix_list[j])
        val_list.append(val)
        col_idx_list.append(col_idx)
        row_num_list.append(row_num)
        nnzs.append(nnz)
    
    return val_list, col_idx_list, row_num_list, nnzs