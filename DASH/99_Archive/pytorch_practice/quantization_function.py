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

import main_function as mf

# model 분리
def separate_classifier_model(model,num_layer=3, DEVICE='cpu'):
    input_sub=copy.deepcopy(torch.nn.Sequential(*list(model.features.children()),
                                                torch.nn.Flatten(start_dim=1)).to(DEVICE))
    sub_layers = []
    
    for i in range(num_layer):
        sub_layers.append(copy.deepcopy(list(model.classifier.children())[3*i]).to(DEVICE))
    
    return input_sub, sub_layers

def do_quantize(input_sub, sub_layers, val_DL, bit_width=8,  num_layers=3,  DEVICE='cpu'):
    q_min_=-2**(bit_width-1)
    q_max_=2**(bit_width-1)-1

    layer_params =[]
    r_in_min = [torch.tensor(float('inf')).to(DEVICE) for _ in range(num_layers)]
    r_in_max = [torch.tensor(float('-inf')).to(DEVICE) for _ in range(num_layers)]
    r_out_min = [torch.tensor(float('inf')).to(DEVICE) for _ in range(num_layers)]
    r_out_max = [torch.tensor(float('-inf')).to(DEVICE) for _ in range(num_layers)]

    with torch.no_grad():
        for images, _ in val_DL:
            curr_in = input_sub(images.to(DEVICE))
            for i in range(num_layers):
                curr_out = sub_layers[i](curr_in)
                if i!=2:
                    curr_out = nn.ReLU()(curr_out)
                r_in_min[i] = torch.min(r_in_min[i], torch.min(curr_in))
                r_in_max[i] = torch.max(r_in_max[i], torch.max(curr_in))
                r_out_min[i] = torch.min(r_out_min[i], torch.min(curr_out))
                r_out_max[i] = torch.max(r_out_max[i], torch.max(curr_out))
                curr_in = curr_out
        for i in range(num_layers):
            S_in = (r_in_max[i] - r_in_min[i]) / (q_max_ - q_min_)
            Z_in = torch.round(q_min_ - r_in_min[i] / S_in)

            S_out = (r_out_max[i] - r_out_min[i]) / (q_max_ - q_min_)
            Z_out = torch.round(q_min_ - r_out_min[i] / S_out)

            weight_tensor = sub_layers[i].weight.data
            bias_tensor= sub_layers[i].bias.data

            r_w_max= torch.max(torch.abs(weight_tensor))
            S_w= r_w_max / (q_max_+1)
            S_b= S_in * S_w

            q_w = torch.round(weight_tensor / S_w).clamp(-q_max_-1, q_max_)
            q_b = torch.round(bias_tensor / S_b)

            q_bias= q_b - Z_in * q_w.sum(dim=1)

            scale_factor=S_w*S_in / S_out
            log2_scale=torch.log2(scale_factor)
            rounded_log2_scale = torch.round(log2_scale)
            mag_scale=scale_factor/(2**(-16))
            # print(f"Layer {i}: mag_scale={mag_scale}, rounded_log2_scale={rounded_log2_scale}")
            # print(f"scale_factor={scale_factor}")
            mag_scale=torch.round(mag_scale)

            layer_params.append({
                'S_in': S_in, 'Z_in': Z_in,
                'S_out': S_out, 'Z_out': Z_out,
                'S_w': S_w,
                'S_b': S_b, 'q_w': q_w, 'q_b': q_b,
                'q_bias': q_bias,
                # 'scale_factor': scale_factor,
                # 'log2_scale': log2_scale,
                # 'rounded_log2_scale': rounded_log2_scale,
                # 'Scale_factor': 2**rounded_log2_scale
                'Scale_factor': mag_scale
            })

    quanted_sub_layers=[]
    for i in range(num_layers):
        quanted_sub_layer = copy.deepcopy(sub_layers[i])
        with torch.no_grad():
            quanted_sub_layer.weight.copy_(layer_params[i]['q_w'])
            quanted_sub_layer.bias.copy_(layer_params[i]['q_bias'])
        quanted_sub_layers.append(quanted_sub_layer)
    return layer_params, quanted_sub_layers


def test_quanted(layer_params, quanted_sub_layers, input_sub, test_DL, num_layers=3, DEVICE='cpu'):
    input_sub.eval()
    with torch.no_grad():
        rcorrect = 0
        for images, labels in test_DL:
            images = images.to(DEVICE)
            labels = labels.to(DEVICE)
            curr_in = input_sub(images)
            final_out=None
            curr_in=torch.round(curr_in / layer_params[0]['S_in']) + layer_params[0]['Z_in']
            for i in range(num_layers):
                curr_out = quanted_sub_layers[i](curr_in)
                if i!=2:
                    curr_out = nn.ReLU()(curr_out)
                curr_out= torch.round(curr_out * layer_params[i]['Scale_factor']*(2**(-16))) + layer_params[i]['Z_out']
                curr_in = curr_out
                final_out=(curr_out-layer_params[i]['Z_out'])*layer_params[i]['S_out']
            pred = curr_in.argmax(dim=1)
            corrects = torch.sum(pred == labels).item()
            rcorrect += corrects
        accuracy_e = rcorrect/len(test_DL.dataset)*100
        print(f"Test accuracy 1: {rcorrect}/{len(test_DL.dataset)} ({accuracy_e:.1f} %)")


def print_layer_params(layer_params, layer_num):
    print(f"------------Layer {layer_num+1}------------")
    for key, value in layer_params[layer_num].items():
        if key == 'q_w' or  key == 'q_b' or  key == 'q_bias':
            print(f"{key}: {value.shape}")
        else:
            print(f"{key}: {value}")

def print_layer_params_all(layer_params):
    for i in range(len(layer_params)):
        # print(f"------------Layer {i+1}------------")
        print_layer_params(layer_params, i)


## save and load
def save_quanted_objects(input_sub, quanted_sub_layers, layer_params, save_path):
    payload = {
        "input_sub_obj": input_sub,                     # nn.Sequential 객체
        "quanted_sub_layers_obj": quanted_sub_layers,   # [nn.Linear, ...]
        "layer_params": layer_params                    # 양자화 파라미터(dict list)
    }
    torch.save(payload, save_path)
    print(f"Quantized objects saved to: {save_path}")


def load_quanted_objects(save_path, device="cpu"):
    # 객체 피클 로드이므로 신뢰 가능한 파일만 로드하세요.
    payload = torch.load(save_path, map_location=device, weights_only=False)

    input_sub = payload["input_sub_obj"].to(device)
    quanted_sub_layers = [layer.to(device) for layer in payload["quanted_sub_layers_obj"]]
    layer_params = payload["layer_params"]

    input_sub.eval()
    for layer in quanted_sub_layers:
        layer.eval()

    print(f"Quantized objects loaded from: {save_path}")
    return input_sub, quanted_sub_layers, layer_params