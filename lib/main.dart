import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const LongVideoMakerApp());
}

class LongVideoMakerApp extends StatelessWidget {
  const LongVideoMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Long Video Maker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class ProjectImage {
  final XFile file;
  String description;
  int originalIndex;

  ProjectImage({
    required this.file,
    this.description = '',
    required this.originalIndex,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();

  List<ProjectImage> images = [];

  bool aiSorting = false;
  bool showApiKey = false;

  String aspectRatio = '16:9';
  String resolution = '1080p';
  String fps = '30';
  String sortMode = 'AI';

  double imageDuration = 4.0;

  @override
  void dispose() {
    _apiKeyController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
      );

      if (picked.isEmpty) return;

      setState(() {
        for (final file in picked) {
          images.add(
            ProjectImage(
              file: file,
              originalIndex: images.length,
            ),
          );
        }
      });
    } catch (e) {
      showMessage('Ошибка выбора изображений: $e');
    }
  }

  void clearImages() {
    setState(() {
      images.clear();
    });
  }

  void shuffleImages() {
    if (images.length < 2) return;

    final copy = List<ProjectImage>.from(images);
    copy.shuffle();

    setState(() {
      images = copy;
    });
  }

  Future<String> analyzeImage(
    ProjectImage image,
    int index,
  ) async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      throw Exception('Введите OpenAI API key');
    }

    final Uint8List bytes = await image.file.readAsBytes();

    final base64Image = base64Encode(bytes);

    String mimeType = 'image/jpeg';

    final name = image.file.name.toLowerCase();

    if (name.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (name.endsWith('.webp')) {
      mimeType = 'image/webp';
    } else if (name.endsWith('.gif')) {
      mimeType = 'image/gif';
    }

    final fileName = image.file.name;

    final prompt = '''
Analyze this image for a video editing application.

Image number: $index
File name: $fileName

Describe:
1. What is visible?
2. What is happening?
3. Is this an establishing/before/process/result scene?
4. What stage of a story could this image represent?

Return ONLY one concise description in English.
Maximum 40 words.
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-5',
        'input': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'input_text',
                'text': prompt,
              },
              {
                'type': 'input_image',
                'image_url': 'data:$mimeType;base64,$base64Image',
                'detail': 'low',
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AI error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    final text = extractOutputText(data);

    if (text.isEmpty) {
      throw Exception('AI не вернул описание изображения');
    }

    return text.trim();
  }

  String extractOutputText(dynamic data) {
    final List<String> texts = [];

    void walk(dynamic value) {
      if (value is Map) {
        if (value['type'] == 'output_text' &&
            value['text'] is String) {
          texts.add(value['text']);
        }

        for (final item in value.values) {
          walk(item);
        }
      } else if (value is List) {
        for (final item in value) {
          walk(item);
        }
      }
    }

    walk(data);

    return texts.join('\n').trim();
  }

  Future<List<int>> getAiOrder() async {
    final apiKey = _apiKeyController.text.trim();

    if (apiKey.isEmpty) {
      throw Exception('Введите OpenAI API key');
    }

    final descriptions = <String>[];

    for (int i = 0; i < images.length; i++) {
      descriptions.add(
        'IMAGE_ID=$i | FILE=${images[i].file.name} | DESCRIPTION=${images[i].description}',
      );
    }

    final script = _scriptController.text.trim();

    final prompt = '''
You are an expert video editor.

I have a collection of images that are currently in random order.

Your task is to create the best chronological/story order.

VIDEO TYPE:
Long-form YouTube video.

ASPECT RATIO:
$aspectRatio

SCRIPT:
${script.isEmpty ? 'No script was provided.' : script}

IMAGES:
${descriptions.join('\n')}

Rules:
- Use every image exactly once.
- Do not invent image IDs.
- Return ONLY a JSON array of integer IMAGE_ID values.
- The first image should normally establish the scene or beginning.
- Process images should follow logically.
- Result/final images should normally be near the end.
- If a script exists, match the images to the script.
- Do not explain anything.
- Example:
[3,0,7,2,1,5,4,6]
''';

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/responses'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-5',
        'input': prompt,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AI sorting error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final text = extractOutputText(data);

    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');

    if (start == -1 || end == -1 || end <= start) {
      throw Exception('AI вернул неправильный порядок');
    }

    final jsonPart = text.substring(start, end + 1);

    final decoded = jsonDecode(jsonPart);

    if (decoded is! List) {
      throw Exception('Неверный формат AI ответа');
    }

    final result = <int>[];

    for (final item in decoded) {
      if (item is int &&
          item >= 0 &&
          item < images.length &&
          !result.contains(item)) {
        result.add(item);
      }
    }

    for (int i = 0; i < images.length; i++) {
      if (!result.contains(i)) {
        result.add(i);
      }
    }

    return result;
  }

  Future<void> aiSort() async {
    if (images.length < 2) {
      showMessage('Добавь минимум 2 изображения');
      return;
    }

    if (_apiKeyController.text.trim().isEmpty) {
      showMessage('Сначала введи OpenAI API key');
      return;
    }

    setState(() {
      aiSorting = true;
    });

    try {
      // Сначала AI анализирует изображения.
      for (int i = 0; i < images.length; i++) {
        setState(() {});

        final description = await analyzeImage(
          images[i],
          i,
        );

        images[i].description = description;
      }

      // Затем AI выстраивает их в правильный порядок.
      final order = await getAiOrder();

      final sorted = <ProjectImage>[];

      for (final index in order) {
        sorted.add(images[index]);
      }

      setState(() {
        images = sorted;
      });

      showMessage('Готово! AI отсортировал изображения.');
    } catch (e) {
      showMessage(
        'Ошибка AI:\n${e.toString()}',
        duration: const Duration(seconds: 6),
      );
    } finally {
      setState(() {
        aiSorting = false;
      });
    }
  }

  void moveImage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }

      final item = images.removeAt(oldIndex);
      images.insert(newIndex, item);
    });
  }

  void removeImage(int index) {
    setState(() {
      images.removeAt(index);
    });
  }

  void showMessage(
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  Widget buildSettingCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget buildImageCard(int index) {
    final item = images[index];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: item.file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 65,
                  height: 65,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              return Image.memory(
                snapshot.data!,
                width: 65,
                height: 65,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        title: Text(
          '${index + 1}. ${item.file.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.description.isEmpty
              ? 'Описание ещё не создано'
              : item.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'up' && index > 0) {
              moveImage(index, index - 1);
            }

            if (value == 'down' && index < images.length - 1) {
              moveImage(index, index + 2);
            }

            if (value == 'delete') {
              removeImage(index);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'up',
              child: Text('⬆ Вверх'),
            ),
            PopupMenuItem(
              value: 'down',
              child: Text('⬇ Вниз'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('🗑 Удалить'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Long Video Maker',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Очистить',
            onPressed: images.isEmpty ? null : clearImages,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // AI
            buildSettingCard(
              title: '🤖 AI-сортировка',
              child: Column(
                children: [
                  TextField(
                    controller: _apiKeyController,
                    obscureText: !showApiKey,
                    decoration: InputDecoration(
                      labelText: 'OpenAI API key',
                      hintText: 'sk-...',
                      prefixIcon: const Icon(Icons.key),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            showApiKey = !showApiKey;
                          });
                        },
                        icon: Icon(
                          showApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _scriptController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Сценарий (необязательно)',
                      hintText:
                          'Вставь сюда сценарий видео...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: aiSorting ? null : aiSort,
                      icon: aiSorting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        aiSorting
                            ? 'AI анализирует...'
                            : 'AI СОРТИРОВАТЬ',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Добавление изображений
            buildSettingCard(
              title: '🖼️ Изображения',
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed:
                          aiSorting ? null : pickImages,
                      icon: const Icon(Icons.photo_library),
                      label: const Text(
                        'ДОБАВИТЬ ФОТОГРАФИИ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              images.length < 2
                                  ? null
                                  : shuffleImages,
                          icon:
                              const Icon(Icons.shuffle),
                          label: const Text('Random'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              images.isEmpty
                                  ? null
                                  : () {
                                      setState(() {
                                        images.sort(
                                          (a, b) => a
                                              .file
                                              .name
                                              .compareTo(
                                                b.file.name,
                                              ),
                                        );
                                      });
                                    },
                          icon: const Icon(
                            Icons.sort_by_alpha,
                          ),
                          label: const Text('По имени'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Выбрано: ${images.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Формат
            buildSettingCard(
              title: '📐 Формат',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: '9:16',
                    label: Text('9:16'),
                  ),
                  ButtonSegment(
                    value: '16:9',
                    label: Text('16:9'),
                  ),
                  ButtonSegment(
                    value: '1:1',
                    label: Text('1:1'),
                  ),
                ],
                selected: {aspectRatio},
                onSelectionChanged: (value) {
                  setState(() {
                    aspectRatio = value.first;
                  });
                },
              ),
            ),

            // Разрешение
            buildSettingCard(
              title: '🖥️ Разрешение',
              child: DropdownButtonFormField<String>(
                value: resolution,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '720p',
                    child: Text('720p'),
                  ),
                  DropdownMenuItem(
                    value: '1080p',
                    child: Text('1080p Full HD'),
                  ),
                  DropdownMenuItem(
                    value: '1440p',
                    child: Text('1440p'),
                  ),
                  DropdownMenuItem(
                    value: '4K',
                    child: Text('4K'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    resolution = value;
                  });
                },
              ),
            ),

            // FPS
            buildSettingCard(
              title: '🎞️ FPS',
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: '24',
                    label: Text('24'),
                  ),
                  ButtonSegment(
                    value: '30',
 
