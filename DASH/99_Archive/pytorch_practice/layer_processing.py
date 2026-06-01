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

import memory_prep as mp

def prepare_layer_input(images, input_sub, device="cpu"):
    images = images.to(device)
    if input_sub is None:
        return images
    return input_sub(images)


def get_layer_params(layer_idx, layer_params):
    params = layer_params[layer_idx]
    return {
        "S_in": params["S_in"],
        "Z_in": params["Z_in"],
        "S_out": params["S_out"],
        "Z_out": params["Z_out"],
        "S_w": params["S_w"],
        "S_b": params["S_b"],
        "q_w": params["q_w"],
        "q_b": params["q_b"],
        "q_bias": params["q_bias"],
        "Scale_factor": params["Scale_factor"],
    }


def quantize_layer_input(layer_input, s_in, z_in):
    return torch.floor(layer_input / s_in) + z_in


def compute_layer_forward(layer_input, q_w, q_bias, scale_factor, z_out, device="cpu"):
    output_tmp = layer_input.to(device) @ q_w.t().to(device)
    output_tmp = output_tmp + q_bias.to(device)
    output_tmp = nn.ReLU()(output_tmp)
    output = torch.floor(output_tmp * scale_factor * (2 ** (-16))) + z_out
    return {
        "output_tmp": output_tmp,
        "output": output,
    }

def _compute_single_pe_outputs(
    input_splits,
    weight_splits,
    bias_splits,
    pe_index,
    scale_factor,
    z_out,
    q_min=None,
    q_max=None,
    device="cpu",
):
    # pe_index 기반 순환 순서: [pe, pe+1, pe+2, pe+3] % 4
    input_order = [((pe_index + step) % 4) for step in range(4)]

    mac_stages = []
    acc = None

    for input_idx in input_order:
        partial = input_splits[input_idx].to(device) @ weight_splits[pe_index][input_idx].t().to(device)
        if acc is None:
            acc = partial
        else:
            acc = partial + acc[0].to(device)
        mac_stages.append(acc)

    bias_added = mac_stages[-1] + bias_splits[pe_index].to(device)
    relu_out = nn.ReLU()(bias_added)
    requant_out = torch.floor(relu_out * scale_factor * (2 ** (-16))) + z_out

    if q_min is not None and q_max is not None:
        clamped_out = torch.clamp(requant_out, q_min, q_max).to(torch.int8)
    else:
        clamped_out = requant_out

    return {
        "mac_stage0": mac_stages[0],
        "mac_stage1": mac_stages[1],
        "mac_stage2": mac_stages[2],
        "mac_stage3": mac_stages[3],
        "bias_added": bias_added,
        "relu_out": relu_out,
        "requant_out": requant_out,
        "clamped_out": clamped_out,
    }

def compute_pe_outputs(input_splits, weight_splits, bias_splits, scale_factor, z_out, q_min=None, q_max=None, device="cpu"):
    pe_outputs = {}

    for pe_index in range(4):
        pe_outputs[f"PE{pe_index}"] = _compute_single_pe_outputs(
            input_splits=input_splits,
            weight_splits=weight_splits,
            bias_splits=bias_splits,
            pe_index=pe_index,
            scale_factor=scale_factor,
            z_out=z_out,
            q_min=q_min,
            q_max=q_max,
            device=device,
        )

    return pe_outputs
def encode_layer_memory(layer_input, output_tensor, q_w, q_bias, bit_width=8, split_size=128):
    input_splits = mp.split_input_data(layer_input, split_size=split_size)
    output_splits = mp.split_output_data(output_tensor, split_size=split_size)
    weight_splits = mp.split_weight_matrix(q_w, r_split=split_size, c_split=split_size)
    bias_splits = mp.split_bias_vector(q_bias, split_size=split_size)

    input_encoded_hex = []
    qw_data_mem_hex = []
    row_num_mem_hex = []
    q_bias_mem_hex = []
    weight_csr = []

    for pe_index in range(4):
        input_encoded = mp.encode_vector(input_splits[pe_index][0].tolist(), bit_width)
        input_encoded_hex.append(mp.bin_list_to_hex(input_encoded, width_hex=2))

        val_list, col_idx_list, row_num_list, nnzs = mp.csr_gen(weight_splits[pe_index])
        qw_data_mem, row_num_mem = mp.encode_csr(val_list, col_idx_list, row_num_list)
        qw_data_mem_hex.append(mp.bin_list_to_hex(qw_data_mem, width_hex=4))
        row_num_mem_hex.append(mp.bin_list_to_hex(row_num_mem, width_hex=2))

        q_bias_encoded = mp.encode_vector(bias_splits[pe_index].tolist(), 32)
        q_bias_mem_hex.append(mp.bin_list_to_hex(q_bias_encoded, width_hex=8))

        weight_csr.append({
            "val": val_list,
            "col_idx": col_idx_list,
            "row_num": row_num_list,
            "nnz": nnzs,
        })


    output_encoded_hex = []
    for pe_index in range(4):
        output_encoded = mp.encode_vector(output_splits[pe_index][0].tolist(), 32)
        output_encoded_hex.append(mp.bin_list_to_hex(output_encoded, width_hex=8))

    return {
        # "input_splits": input_splits,
        # "output_splits": output_splits,
        # "weight_splits": weight_splits,
        # "bias_splits": bias_splits,
        "input_encoded_hex": input_encoded_hex,
        "qw_data_mem_hex": qw_data_mem_hex,
        "row_num_mem_hex": row_num_mem_hex,
        "output_encoded_hex": output_encoded_hex,
        "q_bias_mem_hex": q_bias_mem_hex,
        "weight_csr": weight_csr,
    }


def write_layer_memory_files(encoded_data, sim_dir, layer_idx=0):
    os.makedirs(sim_dir, exist_ok=True)

    for pe_index in range(4):
        with open(os.path.join(sim_dir, f"input_mem_{pe_index}.mem"), "w", encoding="utf-8") as handle:
            handle.write("\n".join(encoded_data["input_encoded_hex"][pe_index]) + "\n")

        with open(os.path.join(sim_dir, f"qw_data_mem_{pe_index}.mem"), "w", encoding="utf-8") as handle:
            handle.write("\n".join(encoded_data["qw_data_mem_hex"][pe_index]) + "\n")

        with open(os.path.join(sim_dir, f"row_num_mem_{pe_index}.mem"), "w", encoding="utf-8") as handle:
            handle.write("\n".join(encoded_data["row_num_mem_hex"][pe_index]) + "\n")

        with open(os.path.join(sim_dir, f"q_bias_mem_{pe_index}.mem"), "w", encoding="utf-8") as handle:
            handle.write("\n".join(encoded_data["q_bias_mem_hex"][pe_index]) + "\n")

        with open(os.path.join(sim_dir, f"output_tmp_mem_{pe_index}.mem"), "w", encoding="utf-8") as handle:
            handle.write("\n".join(encoded_data["output_encoded_hex"][pe_index]) + "\n")

    # return  [os.path.join(sim_dir, f"input_mem_{i}.mem") for i in range(4)] + \
    #         [os.path.join(sim_dir, f"qw_data_mem_{i}.mem") for i in range(4)] + \
    #         [os.path.join(sim_dir, f"row_num_mem_{i}.mem") for i in range(4)] + \
    #         [os.path.join(sim_dir, f"q_bias_mem_{i}.mem") for i in range(4)] + \
    #         [os.path.join(sim_dir, f"output_tmp_mem_{layer_idx}.mem")]

def process_layer_to_memory(
    images,
    input_sub,
    layer_idx,
    layer_params,
    quanted_sub_layers,
    sim_dir,
    device="cpu",
    split_size=128,
    bit_width=8,
):
    layer_input = prepare_layer_input(images, input_sub, device=device)
    params = get_layer_params(layer_idx, layer_params)

    input_q = quantize_layer_input(layer_input, params["S_in"], params["Z_in"])
    forward_result = compute_layer_forward(
        input_q,
        quanted_sub_layers[layer_idx].weight,
        quanted_sub_layers[layer_idx].bias,
        params["Scale_factor"],
        params["Z_out"],
        device=device,
    )

    output_tensor = forward_result["output"]

    input_splits = mp.split_input_data(input_q, split_size=split_size)
    output_splits = mp.split_output_data(output_tensor, split_size=split_size)
    weight_splits = mp.split_weight_matrix(params["q_w"], r_split=split_size, c_split=split_size)
    bias_splits = mp.split_bias_vector(params["q_bias"], split_size=split_size)

    pe_outputs = compute_pe_outputs(
        input_splits=input_splits,
        weight_splits=weight_splits,
        bias_splits=bias_splits,
        scale_factor=params["Scale_factor"],
        z_out=params["Z_out"],
        q_min=None,
        q_max=None,
        device=device,
    )

    encoded_data = encode_layer_memory(
        layer_input=input_q,
        output_tensor=output_tensor,
        q_w=params["q_w"],
        q_bias=params["q_bias"],
        bit_width=bit_width,
        split_size=split_size,
    )

    file_paths = write_layer_memory_files(encoded_data, sim_dir, layer_idx=layer_idx)


    #1) 레이어 입력과 출력, 각 단계별 결과 등 원시 데이터 저장 (디버깅용)
    raw_debug = {
        "input": layer_input,                 # input_sub 통과 후 입력
        "input_q": input_q,                  # 양자화 입력
        "output_tmp": forward_result["output_tmp"],
        "output": output_tensor,
    }

    #2) PE별 초기값/고정값 디버그 정보
    pe_static_debug = {}
    pe_static_debug["Scale_factor"]=params["Scale_factor"]
    #3) PE별 stage 결과 디버그 정보
    pe_stage_debug = {}

    for pe_idx in range(4):
        pe_key = f"PE{pe_idx}"
        pe_stage_values = pe_outputs[pe_key]

        pe_static_debug[pe_key] = {
            "input": input_splits[pe_idx],
            "output": output_splits[pe_idx],
            "weight_splits": weight_splits[pe_idx],
            "bias": bias_splits[pe_idx],
            "weight_csr": encoded_data["weight_csr"],
        }

        pe_stage_debug[pe_key] = pe_stage_values

    # return params, raw_debug, pe_static_debug, pe_stage_debug, encoded_data, file_paths
    return raw_debug, pe_static_debug, pe_stage_debug, encoded_data


class Dbg:
    def __init__(self, pe_static_debug, pe_stage_debug):
        self.s = pe_static_debug
        self.p = pe_stage_debug

    def _t(self, x):
        if isinstance(x, torch.Tensor):
            return x.detach().cpu()
        return torch.tensor(x)
    
    def _vec(self, x):
        t = self._t(x)
        if t.dim() == 2:
            return t[0]
        return t
    
    def _take10(self, x, idx=0):
        v = self._vec(x)
        st = idx * 10
        ed = st + 10
        return v[st:ed]
    
    # nnz 출력: 요청한 형태
    def n(self):
        csr_all = self.s["PE0"]["weight_csr"]
        for pe in range(4):
            print(csr_all[pe]["nnz"])
    
    # pe_static_debug 10개씩 출력
    # key: input, output, bias
    def s10(self, pe=0, key="input", idx=0):
        pe_key = f"PE{pe}"
        print(f"{pe_key}.{key}[{idx*10}:{idx*10+10}]")
        print(self._take10(self.s[pe_key][key], idx))
    
    # weight_splits 확인
    def w10(self, pe=0, split=0, row=0, idx=0):
        pe_key = f"PE{pe}"
        w = self._t(self.s[pe_key]["weight_splits"][split])[row]
        st = idx * 10
        ed = st + 10
        print(f"{pe_key}.weight_splits[{split}][row {row}][{st}:{ed}]")
        print(w[st:ed])
    
    # pe_stage_debug 10개씩 출력
    # stage: mac_stage0, mac_stage1, mac_stage2, mac_stage3, bias_added, relu_out, requant_out, clamped_out
    def p10(self, pe=0, stage="mac_stage0", idx=0):
        pe_key = f"PE{pe}"
        print(f"{pe_key}.{stage}[{idx*10}:{idx*10+10}]")
        print(self._take10(self.p[pe_key][stage], idx))
    
    # 곱/누적 상세 추적
    # stage: 0~3 (mac_stage0~3), row: 출력 row index
    def m(self, pe=0, stage=0, row=0, max_items=None):
        pe_key = f"PE{pe}"
        csr = self.s[pe_key]["weight_csr"][pe]
        input_order = [((pe + k) % 4) for k in range(4)]
        in_idx = input_order[stage]
    
        row_num_list = csr["row_num"][stage]
        val = csr["val"][stage]
        col = csr["col_idx"][stage]
    
        n = int(row_num_list[row])
        st = int(sum(row_num_list[:row]))
        ed = st + n
    
        inp = self._vec(self.s[f"PE{in_idx}"]["input"])
    
        print(f"PE{pe}, stage{stage}, row{row}")
        print(f"input_split={in_idx}, row_num={n}")
    
        acc = 0
        cnt = 0
        for i in range(st, ed):
            v = int(val[i])
            c = int(col[i])
            iv = int(inp[c].item())
            mul = v * iv
            acc += mul
            print(f"[{cnt}] col={c}, val={v}, in={iv}, mul={mul}, acc={acc}")
            cnt += 1
            if max_items is not None and cnt >= max_items:
                break
    
        return acc        