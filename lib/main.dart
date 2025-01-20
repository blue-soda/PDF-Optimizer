import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'PDF Optimizer',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: MyHomePage(),
      ),
    );
  }
}


class MyAppState extends ChangeNotifier {
  MyAppState() {
    _initialize();
  }

  String? _pdfPath; // 存储上传的 PDF 文件路径
  String? get pdfPath => _pdfPath;

  String? _rawImagePath; // 原始图片路径
  String? get rawImagePath => _rawImagePath;

  String? _optimizedImagePath; // 优化后的图片路径
  String? get optimizedImagePath => _optimizedImagePath;

  String? _optimizedPdfPath; // 优化后的pdf路径
  String? get optimizedPdfPath => _optimizedPdfPath;

  bool _isOutputting = false;
  bool get isOutputting => _isOutputting;

  bool _isTransforming = false;
  bool get isTransforming => _isTransforming;

  bool _isOptimizing = false;
  bool get isOptimizing => _isOptimizing;

  void setOutputStatus(bool status) {
    _isOutputting = status;
    notifyListeners();
  }

  void setTransformStatus(bool status) {
    _isTransforming = status;
    notifyListeners();
  }

  void setOptimizeStatus(bool status) {
    _isOptimizing = status;
    notifyListeners();
  }

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;
  
  void setDeleteStatus(bool status) {
    _isDeleting = status;
    notifyListeners();
  }

  Future<void> _initialize() async {
    await copyAssetsToDocumentsDirectory();
    //print('Assets copied successfully!');
  }

  // 上传 PDF 文件
  Future<void> uploadPDF() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      _pdfPath = result.files.single.path;
      setTransformStatus(true);
      optimizePDF('', 'test');
      notifyListeners();
    }
  }


  // 调用 Python 脚本进行优化
  Future<void> optimizePDF(String option, String mode) async {
    if (_pdfPath == null) {
      //print("No PDF file uploaded.");
      return;
    }

    // Python 脚本路径
    //String pythonScriptPath = await rootBundle.loadString('assets/python/main.py');
    //String pythonScriptPath = "assets/python/main.py";
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String pythonScriptPath = path.join(appDocDir.path, 'pdf_optimizer', 'main.py');
    //String pythonScriptPath = '${appDocDir.path}/pdf_optimizer/main.py';
    //print(pythonScriptPath);

    // 调用 Python 脚本
    setOptimizeStatus(true);
    ProcessResult result = await Process.run(
      "python",
      [pythonScriptPath, "--input", _pdfPath!, "--mode", mode, "--option", option],
    );

    if (result.exitCode != 0) {
      //print("Error: ${result.stderr}");
      return;
    }
    setTransformStatus(false);
    setOptimizeStatus(false);

    // 解析 Python 脚本的输出
    String output = result.stdout.toString().trim();
    List<String> lines = output.split("\n");

    if (lines.length >= 2) {
      if (mode == 'test'){
        // 提取最后两行
        String rawImageLine = lines[lines.length - 2];
        String optimizedImageLine = lines[lines.length - 1];

        // 提取原始图片路径
        String rawImagePath = rawImageLine.replaceFirst("test Mode: Raw image path = ", "").trim();
        // 提取优化后的图片路径
        String optimizedImagePath = optimizedImageLine.replaceFirst("test Mode: Optimized image path = ", "").trim();

        _rawImagePath = rawImagePath;
        _optimizedImagePath = optimizedImagePath;
        //print('raw_image:$rawImagePath');
        //print('optimized_image:$optimizedImagePath');
        notifyListeners();
      }
      else if (mode == 'output'){
        // 提取最后一行
        String optimizedPdfLine = lines[lines.length - 1];
        // 提取优化后的PDF路径
        String optimizedPdfPath = optimizedPdfLine.replaceFirst("Output Mode: Optimized PDF saved to ", "").trim();

        _optimizedPdfPath = optimizedPdfPath;
        //print('optimized_pdf:$_optimizedPdfPath');
        notifyListeners();
      }
    } else {
      //print("Unexpected output from Python script: $output");
    }
  }
  // void sharePDF(String path) async {
  //   await Share.shareXFiles(
  //     [XFile(path)],
  //     text: 'Here is the optimized PDF!',
  //   );
  // }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = UploadPage(
          onUploadSuccess: () {
            // 上传成功后切换到优化界面
            setState(() {
              selectedIndex = 1;
            });
          },
        );
        break;
      case 1:
        page = OptimizePage();
        break;
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 800, // 仅在宽度足够时扩展
                  minExtendedWidth: 150, // 最小扩展宽度
                  minWidth: 60, // 最小宽度
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.upload),
                      label: Text('Upload PDF'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune),
                      label: Text('Optimize'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: page,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UploadPage extends StatefulWidget {
  final VoidCallback onUploadSuccess; // 回调函数
  const UploadPage({required this.onUploadSuccess, super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  // 清除缓存的方法

  void clearCache(BuildContext context) async {
    var appState = context.read<MyAppState>();
    appState.setTransformStatus(true);
    appState.setDeleteStatus(true); // 禁用按钮
    //print('Cache deleting...');
    //String workdirPath = 'assets/python/workdir';//await rootBundle.loadString('assets/python/workdir');
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String workdirPath = path.join(appDocDir.path, 'pdf_optimizer', 'workdir');
    //String workdirPath = '${appDocDir.path}/pdf_optimizer/workdir';
    final directory = Directory(workdirPath);
    //print(workdirPath);

    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true); // 递归删除目录及其内容
      }

      if (!context.mounted) return; // 检查上下文是否仍然有效

      // 显示 SnackBar 并等待其完全消失
      await ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(content: Text('Cache cleared')),
          )
          .closed; // 等待 SnackBar 完全消失
    } catch (e) {
      if (!context.mounted) return; // 检查上下文是否仍然有效
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      //print('Cache deleted.');
      if (context.mounted) {
        appState.setDeleteStatus(false); // 重新启用按钮
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer , // 使用主题背景色
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (appState.pdfPath != null)
                  Text(
                    'PDF Uploaded: ${appState.pdfPath}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface , // 使用主题文本颜色
                    ),
                  ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await appState.uploadPDF();
                    if (appState.pdfPath != null) {
                      // 上传成功后切换到优化界面
                      widget.onUploadSuccess();
                    }
                  },
                  child: Text('Upload PDF'),
                ),
              ],
            ),
          ),
          // 右上角的清除缓存按钮
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: Icon(Icons.delete),
              color: appState.isDeleting
                  ? Colors.grey // 禁用时显示灰色
                  : Theme.of(context).colorScheme.onSurface, // 使用主题图标颜色
              onPressed: appState.isDeleting
                  ? null // 禁用按钮
                  : () => clearCache(context),
            ),
          ),
        ],
      ),
    );
  }
}

class OptimizePage extends StatefulWidget {
  const OptimizePage({super.key});

  @override
  State<OptimizePage> createState() => _OptimizePageState();
}

class _OptimizePageState extends State<OptimizePage> {
  // 所有可用的优化选项
  final List<String> availableOptions = [
    'enhance_text',
    'median_filt',
    'bilateral_filt',
    'gaussian_blur',
    'sharpen',
    'super_resolve',
  ];

  // 每个优化选项支持的参数
  final Map<String, List<String>> optionParameters = {
    'enhance_text': ['factor'], 
    'median_filt': ['ksize'],
    'bilateral_filt': ['d', 'sigmaColor', 'sigmaSpace'],
    'gaussian_blur': ['ksize'],
    'sharpen': ['kernel'],
    'super_resolve': [],
  };

  // 每个选项的描述和参数提示
  final Map<String, String> optionDescriptions = {
    'enhance_text': 'Enhance Text Contrast: Improves the visibility of text by increasing contrast.\n'
                    'Recommended "factor" value: 1.5 to 3.0 (higher values increase contrast). Default value = 2.',
    'median_filt': 'Median Filter: Removes noise (e.g., salt-and-pepper noise) while preserving edges.\n'
                   'Recommended "ksize" value: 3, 5, or 7 (odd values, higher values increase smoothing).',
    'bilateral_filt': 'Bilateral Filter: Reduces noise while preserving edges by considering both spatial and intensity differences.\n'
                      'Recommended "d" value: 9 (filter diameter).\n'
                      'Recommended "sigmaColor" and "sigmaSpace" values: 75 (higher values increase smoothing).',
    'gaussian_blur': 'Gaussian Blur: Smooths the image by applying a Gaussian kernel, effective for reducing Gaussian noise.\n'
                     'Recommended "ksize" value: 3, 5, or 7 (odd values, higher values increase blurring). Default value = 3.',
    'sharpen': 'Sharpen: Enhances edges and details in the image.\n'
               'Recommended "kernel" value: 1 to 3. Default value = 1\n'
               '1: Strong sharpening (enhances edges and details significantly).\n'
               '2: Strong sharpening with slightly less intensity than kernel 1.\n'
               '3: Moderate sharpening (enhances edges while preserving smooth areas).\n'
               '4: Moderate sharpening for slight enhancement of details.\n'
               '5: Mild sharpening for subtle edge enhancement.',
    'super_resolve': 'Super Resolution: Increases the resolution of the image using deep learning models(RealESRGAN_x4).\n'
                     'No parameters required. Very slow compared with other methods.',
  };

  // 流水线上的优化选项
  final List<String> pipelineOptions = [];

  // 生成 option 字符串
  String get optionString => pipelineOptions.join(', ');

  // 显示参数选择对话框
  void _showParameterDialog(String option, int index) {
    final parameters = optionParameters[option] ?? [];

    // if (parameters.isEmpty) {
    //   // 如果无参数，直接返回
    //   return;
    // }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Parameters for $option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 显示选项的描述
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  optionDescriptions[option] ?? 'No description available.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
              ),
              // 显示参数输入框
              ...parameters.map((param) {
                return ListTile(
                  title: Text('$param:'),
                  subtitle: TextField(
                    decoration: InputDecoration(
                      hintText: 'Enter value for $param',
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        pipelineOptions[index] = '$option($param=$value)';
                      });
                      Navigator.pop(context);
                    },
                  ),
                );
              })//.toList(),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();

    // 获取屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 动态调整字号和组件大小
    final textScaleFactor = screenWidth / 1600;
    final buttonHeight = screenHeight * 0.04;
    final chipPadding = EdgeInsets.symmetric(
      horizontal: screenWidth * 0.01,
      vertical: screenHeight * 0.005,
    );
    final pipelineHeight = buttonHeight * 1.2;

    return Column(
      children: [
        // 上部分：优化流程选择
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.01),
            child: Column(
              children: [
                Text(
                  'Select Optimization Option:',
                  style: TextStyle(
                    fontSize: 16 * textScaleFactor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: screenHeight * 0.001),

                // 流水线区域
                Container(
                  height: pipelineHeight,
                  margin: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DragTarget<String>(
                    onAcceptWithDetails: (details) {
                      setState(() {
                        final data = details.data;
                        pipelineOptions.add(data);
                      });
                    },
                    builder: (context, candidateData, rejectedData) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          for (var i = 0; i < pipelineOptions.length; i++)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenWidth * 0.01,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  final option = pipelineOptions[i].split('(')[0];
                                  _showParameterDialog(option, i);
                                },
                                child: Chip(
                                  label: Text(
                                    pipelineOptions[i],
                                    style: TextStyle(
                                      fontSize: 12 * textScaleFactor,
                                    ),
                                  ),
                                  backgroundColor: Colors.yellow[100],
                                  onDeleted: () {
                                    setState(() {
                                      pipelineOptions.removeAt(i);
                                    });
                                  },
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // 可拖拽的优化选项
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: screenWidth * 0.02,
                      runSpacing: screenHeight * 0.01,
                      children: [
                        for (var option in availableOptions)
                          Draggable<String>(
                            data: option,
                            feedback: Material(
                              child: Container(
                                padding: chipPadding,
                                decoration: BoxDecoration(
                                  color: Colors.yellow[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 12 * textScaleFactor,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Container(
                              padding: chipPadding,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 12 * textScaleFactor,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            child: Container(
                              padding: chipPadding,
                              decoration: BoxDecoration(
                                color: Colors.yellow[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 12 * textScaleFactor,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // 按钮区域
                Row(
                  children: [
                    // 左侧占位空间
                    Expanded(
                      child: Container(), // 空容器占位
                    ),
                    // 优化按钮（居中）
                    ElevatedButton(
                      onPressed: () async {
                        if (pipelineOptions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Please select at least one optimization option.')),
                          );
                          return;
                        }
                        //print(optionString);
                        await appState.optimizePDF(optionString, 'test');
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(buttonHeight, buttonHeight),
                      ),
                      child: Builder(
                        builder: (context) {
                          if (appState.isTransforming) {
                            return Text(
                              'Converting PDF To Image...',
                              style: TextStyle(fontSize: 14 * textScaleFactor),
                            );
                          } else if (appState.isOptimizing) {
                            return Text(
                              'Optimizing Image...',
                              style: TextStyle(fontSize: 14 * textScaleFactor),
                            );
                          } else {
                            return Text(
                              'Optimize Image',
                              style: TextStyle(fontSize: 14 * textScaleFactor),
                            );
                          }
                        },
                      ),
                    ),
                    // 右侧占位空间
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end, // 将 Output PDF 按钮推到最右侧
                        children: [
                          // 输出按钮
                          ElevatedButton(
                            onPressed: appState.isOutputting
                                ? null // 禁用按钮
                                : () async {
                                    if (appState.pdfPath == null) {
                                      // 使用当前的 BuildContext
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('No PDF file uploaded.')),
                                        );
                                      }
                                      return;
                                    }

                                    // 设置输出状态为 true
                                    appState.setOutputStatus(true);

                                    try {
                                      //print("Output PDF mode triggered.");
                                      await appState.optimizePDF(optionString, 'output');

                                      // 输出完成后显示 SnackBar
                                      if (appState.optimizedPdfPath != null && context.mounted) {
                                        _showPdfPathSnackBar(context, appState.optimizedPdfPath!);
                                      }
                                    } catch (e) {
                                      // 处理错误
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to optimize PDF: $e')),
                                        );
                                      }
                                    } finally {
                                      // 恢复输出状态
                                      if (context.mounted) {
                                        appState.setOutputStatus(false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(buttonHeight, buttonHeight),
                            ),
                            child: appState.isOutputting
                                ? Text(
                                    'Optimizing pdf...',
                                    style: TextStyle(fontSize: 14 * textScaleFactor),
                                  )
                                : Text(
                                    'Output PDF',
                                    style: TextStyle(fontSize: 14 * textScaleFactor),
                                  ),
                          ),
                        ],
                      ),
                    ),

                  ],
                ),
              ],
            ),
          ),
        ),

        // 下部分：展示优化前和优化后的图片
        Expanded(
          flex: 8,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.001),
                  color: Colors.grey[200],
                  child: Column(
                    children: [
                      Text(
                        'Before Optimization',
                        style: TextStyle(
                          fontSize: 14 * textScaleFactor,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.001),
                      Expanded(
                        child: appState.rawImagePath != null
                            ? GestureDetector(
                                onTap: () {
                                  _showImageDialog(context, File(appState.rawImagePath!));
                                },
                                child: Image.file(
                                  File(appState.rawImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Text('No raw image yet.'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.001),
                  color: Colors.grey[300],
                  child: Column(
                    children: [
                      Text(
                        'After Optimization',
                        style: TextStyle(
                          fontSize: 14 * textScaleFactor,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.001),
                      Expanded(
                        child: appState.optimizedImagePath != null
                            ? GestureDetector(
                                onTap: () {
                                  _showImageDialog(context, File(appState.optimizedImagePath!));
                                },
                                child: Image.file(
                                  File(appState.optimizedImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Center(
                                child: Text('No optimized image yet.'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// 显示放大图片的对话框
void _showImageDialog(BuildContext context, File imageFile) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.8,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4,
            child: Image.file(
              imageFile,
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    },
  );
}

// 显示 PDF 路径的 SnackBar
void _showPdfPathSnackBar(BuildContext context, String pdfPath) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('PDF saved to: $pdfPath'),
      duration: Duration(seconds: 5), // 显示 5 秒
      action: SnackBarAction(
        label: 'Copy',
        onPressed: () {
          // 复制路径到剪贴板
          Clipboard.setData(ClipboardData(text: pdfPath));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Path copied to clipboard!')),
          );
        },
      ),
    ),
  );
}

/// 递归复制所有 assets 资源到应用文档目录
Future<void> copyAssetsToDocumentsDirectory() async {
  try {
    // 获取应用文档目录
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    // 定义 assets 的根目录
    const String assetsRoot = 'assets';

    // 递归复制 assets 资源
    await _copyAssetsRecursive(assetsRoot, appDocPath);
  } catch (e) {
    //print('Failed to copy assets: $e');
  }
}

/// 递归复制 assets 资源
Future<void> _copyAssetsRecursive(String assetPath, String targetPath) async {
  try {
    // 获取 assetPath 下的所有文件和子目录
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = Map<String, dynamic>.from(
        const JsonDecoder().convert(manifestContent));

    // 过滤出以 assetPath 开头的资源
    final assets = manifest.keys
        .where((key) => key.startsWith(assetPath))
        .toList();

    for (final asset in assets) {
      // 构建目标文件路径
      final relativePath = asset.substring(assetPath.length + 1);
      //final targetFilePath = '$targetPath/$relativePath';
      final targetFilePath = path.join(targetPath, relativePath);
      // 创建目标目录（如果不存在）
      final targetFile = File(targetFilePath);
      final targetDir = targetFile.parent;
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 加载资源文件并写入目标文件
      final byteData = await rootBundle.load(asset);
      await targetFile.writeAsBytes(byteData.buffer.asUint8List());

      //print('Copied: $asset -> $targetFilePath');
    }
  } catch (e) {
    //print('Failed to copy asset: $assetPath, error: $e');
  }
}
