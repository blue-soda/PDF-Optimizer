import os
import json
import argparse
from enum import Enum, auto
from dataclasses import dataclass, asdict
from pdf import pdf_to_images_batch, load_images_from_disk, images_to_pdf
from optimize import optimize_all_image, optimize_random_image

def get_files(folder_path, extension='.pdf'):
    """获取指定文件夹中特定扩展名的文件列表"""
    files = [f for f in os.listdir(folder_path) if f.endswith(extension)]
    return files

class ProcessingState(Enum):
    """定义处理状态的枚举类"""
    START = auto()  # 初始状态
    RAW_IMAGES = auto()  # 已生成原始图片
    PROCESSED_IMAGES = auto()  # 已优化图片
    PROCESSED_PDF = auto()  # 已生成优化后的 PDF

@dataclass
class ProcessingStatus:
    """定义状态的数据类"""
    state: ProcessingState

def save_status(file_path, status):
    """保存状态到文件"""
    with open(file_path, "w") as f:
        json.dump(asdict(status), f, default=lambda o: o.name)

def load_status(file_path):
    """从文件加载状态"""
    # if not os.path.exists(file_path):
    #     return ProcessingStatus(state=ProcessingState.START)
    try:
        with open(file_path, "r") as f:
            data = json.load(f)
            return ProcessingStatus(state=ProcessingState[data["state"]])
    except:
        return ProcessingStatus(state=ProcessingState.START)


def optimize_pdf(input_path, output_path, file_dir, mode="test", option="enhance, median_filt, bilateral_filt, gaussian_blur, sharpen, conv_filt"):
    """
    将 PDF 转为图片并优化。
    :param input_path: 输入的 PDF 文件路径。
    :param output_path: 输出的 PDF 文件路径。
    :param file_dir: 工作目录，用于存储中间文件。
    :param mode: 工作模式，支持 "test"（调试模式）和 "output"（输出模式）。
    :param option: 优化选项。
    :return: 在调试模式下返回原始图片路径和优化后的图片路径；在输出模式下返回优化后的 PDF 路径。
    """
    flag_file = os.path.join(file_dir, 'state.txt')
    raw_dir = os.path.join(file_dir, 'raw')
    processed_dir = os.path.join(file_dir, 'processed')

    # 确保目录存在
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(processed_dir, exist_ok=True)

    # 加载或初始化状态
    status = load_status(flag_file)

    # 将 PDF 转为图片
    if status.state == ProcessingState.START:
        print('Transforming pdf to images...')
        pdf_to_images_batch(pdf_path=input_path, output_dir=raw_dir, workers=4)
        status.state = ProcessingState.RAW_IMAGES
        save_status(flag_file, status)

    print('Transformed pdf to images.')

    print('Optimizing images...')
    # 调试模式
    if mode == "test":
        if status.state == ProcessingState.RAW_IMAGES:
            raw_image_path, optimized_image_path = optimize_random_image(raw_dir, processed_dir, option)
            print('Images optimized.')
            return raw_image_path, optimized_image_path

    # 输出模式
    elif mode == "output":
        # 优化所有图片
        if status.state == ProcessingState.RAW_IMAGES:
            optimize_all_image(raw_dir, processed_dir, option=option, workers=4)
            print('Images optimized.')
            #status.state = ProcessingState.PROCESSED_IMAGES
            #save_status(flag_file, status)

        # 将处理后的图片保存为 PDF
        # if status.state == ProcessingState.PROCESSED_IMAGES:
            print('Transforming images to PDF...')
            optimized_images = [image for image, _ in load_images_from_disk(processed_dir)]
            images_to_pdf(optimized_images, output_path)
            print(f'Optimized PDF saved to {output_path}')
        #    status.state = ProcessingState.PROCESSED_PDF
            save_status(flag_file, status)

        print('Transformed images to PDF.')
        return output_path

    else:
        raise ValueError("Invalid mode. Supported modes are 'test' and 'output'.")

if __name__ == '__main__':
    # 解析命令行参数
    parser = argparse.ArgumentParser(description="Optimize PDF files.")
    parser.add_argument("--input", type=str, help="Path to the input PDF file.")
    parser.add_argument("--mode", type=str, choices=["test", "output"], default="test", help="Processing mode: test or output.")
    parser.add_argument("--option", type=str, default="enhance_text",help="Options to optimize pdf.")
    args = parser.parse_args()
    print(args)

    current_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(current_dir, 'input')
    work_dir = os.path.join(current_dir, 'workdir')

    os.makedirs(input_dir, exist_ok=True)
    os.makedirs(work_dir, exist_ok=True)

    input_pdf_path = args.input
    if not input_pdf_path:
        input_files_pdf = get_files(input_dir)
        if not input_files_pdf:
            print("No PDF files found in the input directory.")
            exit(1)
        input_pdf_path = os.path.join(input_dir, input_files_pdf[0])

    # 设置输出文件路径和工作目录
    file_dir = os.path.join(work_dir, os.path.splitext(os.path.basename(input_pdf_path))[0])
    output_dir = os.path.join(file_dir, 'output')
    os.makedirs(output_dir, exist_ok=True)
    output_pdf_path = os.path.join(output_dir, os.path.basename(input_pdf_path))
    # 确保工作目录存在
    os.makedirs(file_dir, exist_ok=True)
    option = args.option
    # 根据模式调用优化函数
    if args.mode == "test":
        raw_image_path, optimized_image_path = optimize_pdf(
            input_path=input_pdf_path,
            output_path=output_pdf_path,
            file_dir=file_dir,
            option=option,
            mode="test"
        )
        print(f"test Mode: Raw image path = {raw_image_path}")
        print(f"test Mode: Optimized image path = {optimized_image_path}")
    else:
        optimized_pdf_path = optimize_pdf(
            input_path=input_pdf_path,
            output_path=output_pdf_path,
            file_dir=file_dir,
            option=option,
            mode="output"
        )
        print(f"Output Mode: Optimized PDF saved to {optimized_pdf_path}")