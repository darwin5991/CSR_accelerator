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


#evaluate
def Test(model, test_DL, DEVICE, print_acc=False):
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
    if print_acc:
        print(f"Test accuracy: {rcorrect}/{len(test_DL.dataset)} ({accuracy_e:.1f} %)")
    return rcorrect, round(accuracy_e,1)


#path define
def get_paths(path=".", print_paths=False):
    
    model_dir = os.path.join(path, 'download')
    root=os.path.join(path, 'data','test')
    os.makedirs(root, exist_ok=True)
    checkpoint_dir = os.path.join(path, 'checkpoints')
    output_dir = './saved_results'
    output_dir=os.path.join(checkpoint_dir,output_dir)
    
    save_path = os.path.join(checkpoint_dir, 'pruned_model.pth')
    quant_save_path = os.path.join(checkpoint_dir, "quanted_model.pth")

    if print_paths:
        print(f"작업 경로: {path}")
        print(os.listdir(model_dir))
        print(os.listdir(root))
        print(os.listdir(checkpoint_dir))
        print(os.listdir(output_dir))

    return model_dir, root, checkpoint_dir, output_dir, save_path, quant_save_path

#dataloader
def load_data(root, batch_size=128, train_size=45000, val_size=5000):
    transform_train = transforms.Compose([
        transforms.RandomCrop(32, padding=4),
        transforms.RandomHorizontalFlip(),
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010))
    ])
    transform_test = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.4914, 0.4822, 0.4465), (0.2023, 0.1994, 0.2010))
    ])


    full_train_DS = datasets.CIFAR10(root=root, train=True, download=True, transform=transform_train)
    test_DS = datasets.CIFAR10(root=root, train=False, download=True, transform=transform_test)

    train_DS, val_DS = random_split(full_train_DS, [train_size, val_size])

    train_DL=torch.utils.data.DataLoader(train_DS, batch_size=batch_size, shuffle=True)
    val_DL = torch.utils.data.DataLoader(val_DS, batch_size=batch_size, shuffle=False)
    test_DL=torch.utils.data.DataLoader(test_DS, batch_size=batch_size, shuffle=False)
    
    
    return train_DL, val_DL, test_DL, test_DS


