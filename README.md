# PDF Optimizer

**PDF Optimizer** is a cross-platform application built with Flutter and Python, designed to optimize text-based PDF files. It uses Python scripts to enhance images, reduce noise, apply super-resolution, and recombine the optimized images into a PDF file.

---

## Features

- **PDF Upload**: Upload PDF files and extract images from them.
- **Image Optimization**: Offers multiple image optimization options, including:
  - Text enhancement (`enhance_text`)
  - Median filtering (`median_filt`)
  - Bilateral filtering (`bilateral_filt`)
  - Gaussian blur (`gaussian_blur`)
  - Sharpening (`sharpen`)
  - Super-resolution (`super_resolve`)
- **Custom Optimization Pipeline**: Drag and drop to customize the optimization workflow.
- **Optimization Preview**: Compare images before and after optimization in real-time.
- **Export Optimized PDF**: Save the optimized images as a new PDF file.

---

## Tech Stack

- **Flutter**: For building the cross-platform user interface.
- **Python**: For image processing and PDF optimization logic.
- **PyMuPDF (fitz)**: For extracting images from PDFs.
- **OpenCV**: For image processing (filtering, sharpening, etc.).
- **Real-ESRGAN**: For image super-resolution (model source: [Real-ESRGAN](https://github.com/sberbank-ai/Real-ESRGAN.git)).

---

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/blue-soda/pdf-optimizer.git
cd pdf-optimizer
```

### 2. Install Flutter Dependencies
Ensure you have the Flutter SDK installed, then run the following command to install dependencies:
```bash
flutter pub get
```

### 3. Install Python Dependencies
install Python dependencies:
```bash
pip install -r requirements.txt
```

---
## Running the Project
### 1. Run the Flutter App
In the project root directory, run the following command to start the Flutter app:
```bash
flutter run
```

### 2. Using the App
#### Upload PDF: Click the "Upload PDF" button to select a PDF file for optimization.

#### Select Optimization Options: Drag and drop optimization options into the pipeline area and configure parameters.

#### Optimize Images: Click the "Optimize Image" button to view the before-and-after comparison of the images.

#### Output PDF: Click the "Output PDF" button to save the optimized images as a new PDF file.
---

## Optimization Options

| Option Name      | Description                                                          | Example Parameters          |
|------------------|----------------------------------------------------------------------|-----------------------------|
| `enhance_text`   | Enhances text contrast for better readability.                       | `factor=2.0`                |
| `gaussian_blur`  | Applies Gaussian blur to smooth images and reduce Gaussian noise.    | `ksize=3`                   |
| `sharpen`        | Sharpens images to enhance edges and details.                        | `kernel=1`                  |
| `median_filt`    | Applies median filtering to remove noise (e.g., salt-and-pepper).    | `ksize=5`                   |
| `bilateral_filt` | Applies bilateral filtering to reduce noise while preserving edges.  | `d=9, sigmaColor=75, sigmaSpace=75` |
| `super_resolve`  | Applies super-resolution using Real-ESRGAN to increase image resolution. | No parameters required      |

## License

This project is open-source under the MIT License. See the [LICENSE](LICENSE) file for details.