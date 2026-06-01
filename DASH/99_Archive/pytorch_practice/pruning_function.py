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


# do prune
def prune_model(model,org_acc,file_path,threshold_percent=10.0, DEVICE='cpu'):
    with open(file_path, 'rb') as f:
        results = torch.load(f)
    print(f"Results loaded from {file_path}")
    print("Loaded results (first layer): ", results[list(results.keys())[0]])
    print(results.keys())

    ratios = {}
    min_acceptable_acc = org_acc - threshold_percent
    
    for layer_name, data_list in results.items():
        if 'classifier' in layer_name:
            best_ratio = 0.0
            acc_at_best = org_acc
            for data in data_list:
                ratio = data['ratio']
                acc = data['acc']
                if acc >= min_acceptable_acc:
                    best_ratio = ratio
                    acc_at_best = acc
                else:
                    break
                ratios[layer_name] = best_ratio
            print(f"{layer_name:<40} | {best_ratio:.2f}       | {acc_at_best:.2f}%")
    print(results['classifier.6.weight'][15])
    print(results['classifier.6.weight'][16])
    print(results['classifier.6.weight'][17])

    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() ==2]
    masks = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())

    for layer_name, weight_param in weight_param_list:
        weight_tensor=weight_param.data.clone()
        l1_mag=torch.abs(weight_tensor)
        _, idx= torch.sort(l1_mag.flatten())

        ratio=ratios[layer_name]
        num_prune=int(weight_tensor.numel()*ratio)

        pruning_mask_flat=torch.ones_like(l1_mag.flatten(), dtype=torch.float32)
        pruning_mask_flat[idx[:num_prune]]=0
        pruning_mask=pruning_mask_flat.view_as(weight_tensor)
        masks[layer_name] = pruning_mask.to(DEVICE)

        with torch.no_grad():
            pruned_weight=weight_tensor*pruning_mask
            params_dict[layer_name].copy_(pruned_weight)

    for layer_name, weight_param in weight_param_list:
        print(layer_name)
        print(ratios[layer_name])
    print(ratios)

    return pruned_model, masks


def finetuning_pruned_model(pruned_model, train_DL, test_DL, masks, DEVICE):
    criterion = nn.CrossEntropyLoss()
    optimizer=optim.SGD(pruned_model.parameters(), lr=0.001, momentum=0.9, weight_decay=5e-4)
    EPOCH=10

    for epoch in range(EPOCH):
            pruned_model.train()
            running_loss = 0.0
            for inputs, labels in train_DL:
                inputs, labels = inputs.to(DEVICE), labels.to(DEVICE)

                optimizer.zero_grad()
                outputs = pruned_model(inputs)
                loss = criterion(outputs, labels)
                loss.backward()

                with torch.no_grad():
                    for name, param in pruned_model.named_parameters():
                        if name in masks:
                            param.grad.mul_(masks[name])
                optimizer.step()
                running_loss += loss.item()

            avg_loss = running_loss / len(train_DL)
            _, ep_acc = mf.Test(pruned_model, test_DL, DEVICE, print_acc=False)

            print(f"Epoch [{epoch+1}/{EPOCH}] | Loss: {avg_loss:.4f} | Test Acc: {ep_acc:.2f}%")
    
    return pruned_model



## call pruned model


