import numpy as np
from PIL import Image, ImageEnhance
import cv2
import multiprocessing
import torch
import tqdm
from pdf import load_images_from_disk
import os
import random

def threshold_image(image):
    """二值化图像"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)
    _, thresholded = cv2.threshold(image, 127, 255, cv2.THRESH_BINARY)
    return thresholded


def sharpen_image(image, kernel = 1):
    """锐化图像"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)

    kernel1 = np.array([[-1, -1, -1],
                       [-1,  9, -1],
                       [-1, -1, -1]])

    kernel2 = np.array([[ 0, -1,  0],
                       [-1,  5, -1],
                       [ 0, -1,  0]])
    
    kernel3 = np.array([[ -0.5, -0.75,  -0.5],
                       [-0.75,  6, -0.75],
                       [ -0.5, -0.75,  -0.5]])

    kernel4 = np.array([[ 0, -0.5,  0],
                       [-0.5,  3, -0.5],
                       [ 0, -0.5,  0]]) 

    kernel5 = np.array([[ 0, -0.25,  0],
                       [-0.25,  2, -0.25],
                       [ 0, -0.25,  0]])

    kernels = [kernel1, kernel2, kernel3, kernel4, kernel5]
    
    sharpened = cv2.filter2D(image, -1, kernels[kernel - 1])
    
    return sharpened#Image.fromarray(sharpened)


def super_resolve(image):
    """应用超分辨率处理"""

    try:
        from RealESRGAN import RealESRGAN
        if isinstance(image, np.ndarray):
            image = Image.fromarray(image)
        device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
        model = RealESRGAN(device, scale=4)
        model.load_weights('RealESRGAN_x4/RealESRGAN_x4.pth', download=True)
        image = image.convert('RGB')
        sr_image = model.predict(image)
        return np.array(sr_image)
    
    except Exception as e:
        print(f'Super Resolve Error:{e}.')
        if not isinstance(image, np.ndarray):
            return np.array(image)


def bilateral_filter(image, d=9, sigmaColor=75, sigmaSpace=75):
    """降噪：使用双边滤波"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)
    
    # 双边滤波，用于去除噪声并保留边缘
    denoised = cv2.bilateralFilter(image, d=d, sigmaColor=sigmaColor, sigmaSpace=sigmaSpace)
    
    return denoised#Image.fromarray(denoised)


def enhance_text(image, factor=2.0):
    """文本增强：增强图像对比度"""
    if isinstance(image, np.ndarray):
        image = Image.fromarray(image)
    enhancer = ImageEnhance.Contrast(image)
    enhanced_image = enhancer.enhance(factor)  # 增强对比度，值可以调整
    
    return np.array(enhanced_image)#enhanced_image


def gaussian_blur_image(image, ksize=3, sigma = 0):
    """高斯模糊：去噪与平滑"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)
    
    blurred = cv2.GaussianBlur(image, (ksize, ksize), sigma)
    
    return blurred#Image.fromarray(blurred)


def median_blur_image(image, ksize=5):
    """中值滤波：去除噪声，平滑图像"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)

    filtered = cv2.medianBlur(image, ksize)
    
    return filtered#Image.fromarray(filtered)


def conv_filter(image):
    """卷积滤波：去除毛刺并平滑图像"""
    if not isinstance(image, np.ndarray):
        image = np.array(image)

    kernel = np.array([[1, 1, 1], 
                       [1, -6, 1], 
                       [1, 1, 1]])  # 较强的去噪卷积核
    filtered = cv2.filter2D(image, -1, kernel)
    
    return filtered#Image.fromarray(filtered)


def process_image(image, 
    option = "enhance_text"):
    #image = enhance_text(image)
    #:enhance = True, median_filt = True, denoise = True, gaussian_blur = True, shappen = True, conv = True):
    """对 PDF 进行优化，包含去噪、二值化、锐化处理"""    
    image = np.array(image, dtype=np.uint8)

    operation_map = {
        "enhance_text": enhance_text,
        "median_filt": median_blur_image,
        "bilateral_filt": bilateral_filter,
        "gaussian_blur": gaussian_blur_image,
        "sharpen": sharpen_image,
        "conv_filt": conv_filter,
        "super_resolve": super_resolve,
    }
    operations = [op.strip() for op in option.split(",")]

    for op in operations:
        # 提取操作名称和参数
        if "(" in op:
            op_name = op.split("(")[0].strip()
            params = op.split("(")[1].rstrip(")").strip()
            # 解析参数
            kwargs = {}
            for param in params.split(","):
                key, value = param.split("=")
                kwargs[key.strip()] = eval(value.strip())  # 将字符串转换为值
        else:
            op_name = op.strip()
            kwargs = {}

        # 获取对应的函数
        if op_name in operation_map:
            func = operation_map[op_name]
            # 调用函数并更新图像
            image = func(image, **kwargs) if kwargs else func(image)

    return Image.fromarray(image)


def optimize_image(args):
    """
    优化单张图像。
    """
    image, image_file_name, option, processed_dir = args
    image = process_image(image, option)
    image_path = os.path.join(processed_dir, image_file_name)
    image.save(image_path)
    return image_file_name  # 返回文件名以便主进程跟踪


def optimize_all_image(raw_dir, processed_dir, option, workers=4):
    """
    优化所有图像。
    """
    if not os.path.exists(processed_dir):
        os.makedirs(processed_dir)

    # 获取 PNG 文件总数
    image_files = [f for f in os.listdir(raw_dir) if f.endswith(".png")]
    total_images = len(image_files)

    # 准备任务参数
    tasks = [(image, image_file_name, option, processed_dir) 
             for image, image_file_name in load_images_from_disk(raw_dir)]

    # 使用 multiprocessing.Pool 并行处理
    with multiprocessing.Pool(workers) as pool:
        # 使用 tqdm 显示进度条
        with tqdm.tqdm(total=total_images, desc="Processing Images") as pbar:
            # 使用 imap_unordered 并行处理任务
            for result in pool.imap_unordered(optimize_image, tasks):
                pbar.update(1)  # 实时更新进度条

    print('Image optimization completed and images saved.')

def optimize_random_image(raw_dir, processed_dir, option):
    """
    调试模式：随机选择一张图片进行优化，并返回原始图片路径和优化后的图片路径。
    """
    # 获取所有原始图片
    raw_images = list(load_images_from_disk(raw_dir))
    if not raw_images:
        raise ValueError("No images found in the raw directory.")

    # 随机选择一张图片
    image, image_file_name = random.choice(raw_images)
    print(f"Selected image for debugging: {image_file_name}")

    # 优化图片
    optimized_image = optimize_image((image, image_file_name, option, processed_dir))

    # 返回原始图片路径和优化后的图片路径
    raw_image_path = os.path.join(raw_dir, image_file_name)
    optimized_image_path = os.path.join(processed_dir, image_file_name)
    return raw_image_path, optimized_image_path
