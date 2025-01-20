import os
import multiprocessing
from PIL import Image
import fitz  # PyMuPDF
import tqdm
from more_itertools import divide
def extract_image(args):
    """
    将 PDF 的某一页转换为图像并保存。
    """
    pdf_path, pages, output_dir, dpi, target_width, worker_id = args
    # 在子进程中打开 PDF 文档
    pages = list(pages)
    doc = fitz.open(pdf_path)
    
    # 为每个工作进程创建一个独立的进度条
    with tqdm.tqdm(total=len(pages), desc=f"Worker {worker_id}", position=worker_id) as pbar:
        for page_num in pages:
            page = doc.load_page(page_num)
            pix = page.get_pixmap(dpi=dpi)
            
            # 将图像转换为 PIL Image 对象
            img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)

            # 计算新的高度，保持原始宽高比
            aspect_ratio = img.height / img.width
            target_height = int(target_width * aspect_ratio)

            # 调整图像尺寸
            img = img.resize((target_width, target_height), Image.Resampling.LANCZOS)
            
            # 保存每一页为独立的图像文件
            img_path = os.path.join(output_dir, f"page_{page_num + 1}.png")
            img.save(img_path)
            
            # 更新当前工作进程的进度条
            pbar.update(1)
    
    doc.close()
    #return len(pages)  # 返回处理页数以便主进程跟踪


def pdf_to_images_batch(pdf_path, output_dir, dpi=96, target_width=1920, workers=4):
    """
    将 PDF 转换为图像并逐页保存为文件。每一页图像单独保存。
    目标是将图像调整为固定宽度，保持原始宽高比。
    """
    print("Converting Pages to Images...")
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # 打开 PDF 文档
    doc = fitz.open(pdf_path)
    total_pages = doc.page_count
    doc.close()  # 关闭文档，避免资源占用

    # 将页码分成若干块
    page_chunks = list(divide(workers, range(total_pages)))
    # 准备任务参数
    tasks = [(pdf_path, chunk, output_dir, dpi, target_width, i) for i, chunk in enumerate(page_chunks)]

    # 使用 multiprocessing.Pool 并行处理
    with multiprocessing.Pool(workers) as pool:
        # 使用 imap 并行处理任务
        for result in pool.imap(extract_image, tasks):
            pass  # 主进程不需要更新进度条

    print('PDF conversion completed and images saved.')


def load_images_from_disk(source_dir):
    """
    从磁盘加载保存的图像文件。
    """

    img_files = [f for f in os.listdir(source_dir) if f.endswith(".png")]
    img_files.sort(key=lambda x: int(x.split('_')[1].split('.')[0]))  # img_files like page_1.png

    for img_file in img_files:
        img_path = os.path.join(source_dir, img_file)
        if os.path.isfile(img_path) and img_file.endswith(".png"):
            img = Image.open(img_path)
            yield img, img_file

def images_to_pdf(images, output_pdf_path, resolution=96):
    """将处理后的图像列表保存为 PDF 文件"""
    images[0].save(output_pdf_path, save_all=True, append_images=images[1:], resolution=resolution)

