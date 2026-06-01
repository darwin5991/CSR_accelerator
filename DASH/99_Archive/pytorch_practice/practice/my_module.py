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



def Test(model, test_DL, DEVICE):
    model.eval() # test mode로 전환
    with torch.no_grad(): #model.eval과 같이 항상 해야 함
        rcorrect = 0
        num=len(test_DL.dataset)
        cnt=0
        for x_batch, y_batch in test_DL:
            x_batch = x_batch.to(DEVICE)
            y_batch = y_batch.to(DEVICE)
            # inference
            y_hat = model(x_batch)
            # corrects accumulation
            pred = y_hat.argmax(dim=1)
            corrects_b = torch.sum(pred == y_batch).item() # torch.eq(pred, y_batch).sum().item()
            rcorrect += corrects_b
            cnt+=1
            # print(f"Batch {cnt}/{len(test_DL)} processed")
        accuracy_e = rcorrect/len(test_DL.dataset)*100
    # print(f"Test accuracy: {rcorrect}/{len(test_DL.dataset)} ({accuracy_e:.1f} %)")
    return rcorrect, round(accuracy_e,1)


# Pruning Granularity,Pruning Criterion 를 주어지면
# 모든 layer, 모든 Pruning Ratio를 비교하는 함
# The process of Sensitivity Analysis
# def PSA(model, Granularity, Pruning_Criterion):
def PSA(model,test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() > 1]
    layers=len(weight_param_list)
    org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())

    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        results[target_name]=[]
        weight_tensor=original_param.data.clone()

        # criterion
        l1_mag=torch.abs(weight_tensor)
        # granularity
        val,idx= torch.sort(l1_mag.flatten())

        # ratio: 0%~95%
        for j in range(20):
            ratio=j/20.0
            n_prune = int(weight_tensor.numel() * ratio)

            # pruning 마스크 생성
            pruning_mask_flat=torch.ones_like(l1_mag.flatten(), dtype=torch.float32)
            pruning_mask_flat[idx[:n_prune]]=0
            pruning_mask=pruning_mask_flat.reshape(l1_mag.shape)

            with torch.no_grad():
                # pruning weight 생성
                pruned_weight=weight_tensor*pruning_mask
                # pruning 적용
                params_dict[target_name].copy_(pruned_weight)

            _, acc = Test(pruned_model, test_DL, DEVICE)
            results[target_name].append({'ratio': ratio, 'acc': acc})

            print(f'Progress: {100*(i*20+j)/(layers*20.0):.2f}%')

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)

    return results,org_acc


def plot_sensitivity(psa_results, org_acc=None):
    plt.figure(figsize=(12, 8))

    for layer_name, data in psa_results.items():
        ratios = [item['ratio'] for item in data]
        accs = [item['acc'] for item in data]

        plt.plot(ratios, accs, marker='o', markersize=4, label=layer_name, alpha=0.7)
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize='small', ncol=2)
    plt.grid(True, which='both', linestyle='--', alpha=0.5)

    plt.xlabel('Pruning Ratio (Sparsity)', fontsize=12)
    plt.ylabel('Accuracy', fontsize=12)

    plt.tight_layout()
    plt.show()

def plot_sensitivity_subplots(psa_results, org_acc=None):
    layer_names = list(psa_results.keys())
    num_layers = len(layer_names)
    layers_per_plot = 6
    num_plots = math.ceil(num_layers / layers_per_plot)

    # 전체 Figure 크기 설정 (세로로 길게 배치)
    fig, axes = plt.subplots(num_plots, 1, figsize=(12, 5 * num_plots), sharex=True)

    # axes가 하나일 경우 리스트로 변환
    if num_plots == 1:
        axes = [axes]

    for i in range(num_plots):
        start_idx = i * layers_per_plot
        end_idx = min(start_idx + layers_per_plot, num_layers)

        ax = axes[i]

        # 원본 정확도 가이드라인 (입력되었을 경우만)
        if org_acc is not None:
            ax.axhline(y=org_acc, color='r', linestyle='--', alpha=0.5, label='Baseline')

        # 6개씩 레이어 플로팅
        for j in range(start_idx, end_idx):
            name = layer_names[j]
            data = psa_results[name]
            ratios = [item['ratio'] for item in data]
            accs = [item['acc'] for item in data]

            ax.plot(ratios, accs, marker='o', markersize=4, label=name)

        ax.set_title(f'Sensitivity Analysis: Layers {start_idx} to {end_idx-1}', fontsize=13)
        ax.set_ylabel('Accuracy')
        ax.grid(True, which='both', linestyle='--', alpha=0.5)
        ax.legend(loc='lower left', fontsize='small', ncol=2)

    axes[-1].set_xlabel('Pruning Ratio (Sparsity)', fontsize=12)

    plt.tight_layout()
    plt.show()

def PSA_NM(model, test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() > 1]
    layers=len(weight_param_list)
    _, org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())
    N,M= 3,4

    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        weight_tensor=original_param.data.clone()
        # print(target_name, original_param.shape)
        # criterion
        l1_mag=torch.abs(weight_tensor)

        # granularity
        # print(i)
        # print(target_name)
        val,idx= torch.sort(l1_mag.view(-1,M))
        group=weight_tensor.view(-1,M).shape[0]
        # print(group)
        # print(idx.shape)

        # pruning 마스크 생성
        pruning_mask_flat=torch.ones_like(weight_tensor.view(-1,M), dtype=torch.float32)
        for g in range(group):
            # print(g,idx[g][:N])
            pruning_mask_flat[g][idx[g][:N]]=0
        pruning_mask=pruning_mask_flat.reshape(weight_tensor.shape)

        with torch.no_grad():
            # pruning weight 생성
            pruned_weight=weight_tensor*pruning_mask
            # pruning 적용
            params_dict[target_name].copy_(pruned_weight)

        # print(weight_tensor.shape,torch.sum(weight_tensor == 0).item(),torch.sum(pruned_weight == 0).item())

        acc = Test(pruned_model, test_DL, DEVICE)
        results[target_name]=acc
        print(f'Progress: {100*(i+1)/(layers):.2f}%')

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)

    return results,org_acc





def PSA_vector(model,test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() == 4]
    layers=len(weight_param_list)
    _, org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())

    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        results[target_name]=[]
        weight_tensor=original_param.data.clone()

        # criterion
        l1_mag=torch.abs(weight_tensor)
        # granularity
        val,idx= torch.sort(torch.sum(l1_mag.view(-1,3),dim=1))

        # ratio: 0%~95%
        for j in range(20):
            ratio=j/20.0
            # group=idx.shape[0]
            n_prune = int(idx.shape[0] * ratio)

            # pruning 마스크 생성
            pruning_mask=torch.ones_like(l1_mag.view(-1,3), dtype=torch.float32)
            pruning_mask[idx[:n_prune]]=0
            pruning_mask=pruning_mask.reshape(l1_mag.shape)


            with torch.no_grad():
                # pruning weight 생성

                # print(pruning_mask.shape, weight_tensor.shape)
                pruned_weight=weight_tensor*pruning_mask
                # pruning 적용
                params_dict[target_name].copy_(pruned_weight)

            _, acc = Test(pruned_model, test_DL, DEVICE)
            results[target_name].append({'ratio': ratio, 'acc': acc})

            print(f'Progress: {100*(i*20+j)/(layers*20.0):.2f}%')

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)

    return results,org_acc


def PSA_kernel(model,test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() == 4]
    layers=len(weight_param_list)
    _, org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())

    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        results[target_name]=[]
        weight_tensor=original_param.data.clone()

        # criterion
        l1_mag=torch.abs(weight_tensor)
        # granularity
        val,idx= torch.sort(torch.sum(l1_mag.view(-1,9),dim=1))

        # ratio: 0%~95%
        for j in range(20):
            ratio=j/20.0
            # group=idx.shape[0]
            n_prune = int(idx.shape[0] * ratio)

            # pruning 마스크 생성
            pruning_mask=torch.ones_like(l1_mag.view(-1,9), dtype=torch.float32)
            pruning_mask[idx[:n_prune]]=0
            pruning_mask=pruning_mask.reshape(l1_mag.shape)


            with torch.no_grad():
                # pruning weight 생성

                # print(pruning_mask.shape, weight_tensor.shape)
                pruned_weight=weight_tensor*pruning_mask
                # pruning 적용
                params_dict[target_name].copy_(pruned_weight)

            _, acc = Test(pruned_model, test_DL, DEVICE)
            results[target_name].append({'ratio': ratio, 'acc': acc})

            print(f'Progress: {100*(i*20+j)/(layers*20.0):.2f}%')

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)

    return results,org_acc

def PSA_channel(model,test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() == 4]
    layers=len(weight_param_list)
    _, org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())

    pbar = tqdm(total=layers * 20, desc="Sensitivity Analysis")

    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        results[target_name]=[]
        weight_tensor=original_param.data.clone()

        # criterion
        l1_mag=torch.abs(weight_tensor)
        # granularity
        val,idx= torch.sort(torch.sum(l1_mag.view(l1_mag.shape[0],l1_mag.shape[1]*l1_mag.shape[2]*l1_mag.shape[3]),dim=1))

        # ratio: 0%~95%
        for j in range(20):
            ratio=j/20.0
            # group=idx.shape[0]
            n_prune = int(idx.shape[0] * ratio)

            # pruning 마스크 생성
            pruning_mask=torch.ones_like(l1_mag.view(l1_mag.shape[0],l1_mag.shape[1]*l1_mag.shape[2]*l1_mag.shape[3]), dtype=torch.float32)
            pruning_mask[idx[:n_prune]]=0
            pruning_mask=pruning_mask.reshape(l1_mag.shape)


            with torch.no_grad():
                # pruning weight 생성

                # print(pruning_mask.shape, weight_tensor.shape)
                pruned_weight=weight_tensor*pruning_mask
                # pruning 적용
                params_dict[target_name].copy_(pruned_weight)

            pbar.set_description(f"Layer {i+1}/{layers} [{target_name}]")

            _, acc = Test(pruned_model, test_DL, DEVICE)
            results[target_name].append({'ratio': ratio, 'acc': acc})

            # print(f'Progress: {100*(i*20+j)/(layers*20.0):.2f}%', end='\r', flush=True)
            
            pbar.update(1)
            pbar.set_postfix(ratio=f"{ratio:.2f}", acc=f"{acc:.2f}")

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)
    pbar.close() # 작업 완료 후 닫기
    return results,org_acc

def PSA_scaling(model,test_DL, DEVICE):
    weight_param_list = [p for p in model.named_parameters() if 'weight' in p[0] and p[1].dim() == 1]
    layers=len(weight_param_list)
    _, org_acc=Test(model, test_DL, DEVICE)
    results = {}

    pruned_model = copy.deepcopy(model)
    params_dict = dict(pruned_model.named_parameters())
    pbar = tqdm(total=layers * 20, desc="Sensitivity Analysis")
    for i in range(layers):
        target_name, original_param = weight_param_list[i]
        results[target_name]=[]
        weight_tensor=original_param.data.clone()

        # criterion
        l1_mag=torch.abs(weight_tensor)
        # granularity
        val,idx= torch.sort(l1_mag,dim=0)

        # ratio: 0%~95%
        for j in range(20):
            ratio=j/20.0
            # group=idx.shape[0]
            n_prune = int(idx.shape[0] * ratio)

            # pruning 마스크 생성
            pruning_mask=torch.ones_like(l1_mag, dtype=torch.float32)
            pruning_mask[idx[:n_prune]]=0
            pruning_mask=pruning_mask.reshape(l1_mag.shape)


            with torch.no_grad():
                # pruning weight 생성

                # print(pruning_mask.shape, weight_tensor.shape)
                pruned_weight=weight_tensor*pruning_mask
                # pruning 적용
                params_dict[target_name].copy_(pruned_weight)

            pbar.set_description(f"Layer {i+1}/{layers} [{target_name}]")
            _, acc = Test(pruned_model, test_DL, DEVICE)
            results[target_name].append({'ratio': ratio, 'acc': acc})

            # print(f'Progress: {100*(i*20+j)/(layers*20.0):.2f}%', end='\r', flush=True)
            pbar.update(1)
            pbar.set_postfix(ratio=f"{ratio:.2f}", acc=f"{acc:.2f}")

        with torch.no_grad():
            # pruning 복구
            params_dict[target_name].copy_(weight_tensor)
    pbar.close()
    return results,org_acc




def plot_nm_sensitivity(results, org_acc, n_m_str="2:4"):
    # 데이터 준비
    layer_names = list(results.keys())
    accuracies = list(results.values())

    # 그래프 크기 설정
    plt.figure(figsize=(14, 7))

    # 1. 원본 정확도 가이드라인 (Baseline)
    plt.axhline(y=org_acc, color='r', linestyle='--', linewidth=2, label=f'Original Acc ({org_acc:.4f})')

    # 2. 레이어별 정확도 막대 그래프
    # 정확도 하락이 큰 레이어를 시각적으로 강조하기 위해 막대 그래프 사용
    bars = plt.bar(layer_names, accuracies, color='skyblue', alpha=0.8, label=f'Pruned Acc ({n_m_str})')

    # 그래프 세부 설정
    plt.title(f'N:M Sparsity ({n_m_str}) Sensitivity Analysis by Layer', fontsize=16)
    plt.xlabel('Layer Name', fontsize=12)
    plt.ylabel('Accuracy', fontsize=12)

    # X축 레이블이 겹치지 않도록 회전
    plt.xticks(rotation=45, ha='right')

    # Y축 범위를 정확도 근처로 제한하여 차이를 극대화 (예: 최저 정확도의 90% 수준부터)
    min_acc = min(accuracies + [org_acc])
    plt.ylim(min_acc * 0.98, max(accuracies + [org_acc]) * 1.02)

    # 그리드 및 레이아웃 설정
    plt.grid(axis='y', linestyle=':', alpha=0.6)
    plt.legend(loc='lower left')

    # 각 막대 위에 정확도 값 표시 (선택 사항)
    for bar in bars:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval, f'{yval:.3f}',
                 va='bottom', ha='center', fontsize=9, rotation=0)

    plt.tight_layout()
    plt.show()


