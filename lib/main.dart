import 'package:flutter/material.dart';

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
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const VideoEditorPage(),
    );
  }
}

class VideoEditorPage extends StatefulWidget {
  const VideoEditorPage({super.key});

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage> {
  String format = '9:16';
  String resolution = '1080p';
  int fps = 30;

  bool autoDuration = true;
  bool zoom = true;
  bool transitions = true;

  double voiceVolume = 100;
  double musicVolume = 20;

  int imageCount = 0;
  bool voiceAdded = false;
  bool musicAdded = false;

  String get dimensions {
    if (format == '9:16') {
      switch (resolution) {
        case '480p':
          return '270 × 480';
        case '720p':
          return '405 × 720';
        case '1440p':
          return '810 × 1440';
        case '2160p':
          return '1215 × 2160';
        default:
          return '608 × 1080';
      }
    }

    if (format == '1:1') {
      switch (resolution) {
        case '480p':
          return '480 × 480';
        case '720p':
          return '720 × 720';
        case '1440p':
          return '1440 × 1440';
        case '2160p':
          return '2160 × 2160';
        default:
          return '1080 × 1080';
      }
    }

    switch (resolution) {
      case '480p':
        return '854 × 480';
      case '720p':
        return '1280 × 720';
      case '1440p':
        return '2560 × 1440';
      case '2160p':
        return '3840 × 2160';
      default:
        return '1920 × 1080';
    }
  }

  void addImages() {
    setState(() {
      imageCount += 5;
    });

    showMessage('Изображения добавлены');
  }

  void addVoice() {
    setState(() {
      voiceAdded = true;
    });

    showMessage('Озвучка добавлена');
  }

  void addMusic() {
    setState(() {
      musicAdded = true;
    });

    showMessage('Музыка добавлена');
  }

  void createVideo() {
    if (imageCount == 0) {
      showMessage('Сначала добавь изображения');
      return;
    }

    if (!voiceAdded) {
      showMessage('Сначала добавь озвучку');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Настройки видео'),
          content: Text(
            'Формат: $format\n'
            'Разрешение: $resolution\n'
            'Размер: $dimensions\n'
            'FPS: $fps\n'
            'Изображений: $imageCount\n'
            'Авто-длительность: ${autoDuration ? "Да" : "Нет"}\n'
            'Zoom: ${zoom ? "Да" : "Нет"}\n'
            'Переходы: ${transitions ? "Да" : "Нет"}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LONG VIDEO MAKER',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.movie_creation_outlined,
              size: 70,
            ),

            const SizedBox(height: 8),

            const Text(
              'Автоматический видеомонтаж',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // IMAGES
            ElevatedButton.icon(
              onPressed: addImages,
              icon: const Icon(Icons.photo_library),
              label: Text(
                imageCount == 0
                    ? 'Добавить изображения'
                    : 'Изображения: $imageCount',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // VOICE
            ElevatedButton.icon(
              onPressed: addVoice,
              icon: const Icon(Icons.mic),
              label: Text(
                voiceAdded
                    ? 'Озвучка ✓'
                    : 'Добавить озвучку',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // MUSIC
            ElevatedButton.icon(
              onPressed: addMusic,
              icon: const Icon(Icons.music_note),
              label: Text(
                musicAdded
                    ? 'Музыка ✓'
                    : 'Добавить музыку',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // SETTINGS
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '⚙️ Настройки',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Формат',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    SegmentedButton<String>(
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
                      selected: {format},
                      onSelectionChanged: (value) {
                        setState(() {
                          format = value.first;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Разрешение',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      value: resolution,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '480p',
                          child: Text('480p'),
                        ),
                        DropdownMenuItem(
                          value: '720p',
                          child: Text('720p HD'),
                        ),
                        DropdownMenuItem(
                          value: '1080p',
                          child: Text('1080p Full HD'),
                        ),
                        DropdownMenuItem(
                          value: '1440p',
                          child: Text('1440p 2K'),
                        ),
                        DropdownMenuItem(
                          value: '2160p',
                          child: Text('2160p 4K'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            resolution = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'FPS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<int>(
                      value: fps,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 24,
                          child: Text('24 FPS'),
                        ),
                        DropdownMenuItem(
                          value: 25,
                          child: Text('25 FPS'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text('30 FPS'),
                        ),
                        DropdownMenuItem(
                          value: 50,
                          child: Text('50 FPS'),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: Text('60 FPS'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            fps = value;
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 10),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Автоматическая длительность',
                      ),
                      subtitle: const Text(
                        'Распределять изображения по озвучке',
                      ),
                      value: autoDuration,
                      onChanged: (value) {
                        setState(() {
                          autoDuration = value;
                        });
                      },
                    ),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Автоматический Zoom',
                      ),
                      value: zoom,
                      onChanged: (value) {
                        setState(() {
                          zoom = value;
                        });
                      },
                    ),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Переходы',
                      ),
                      value: transitions,
                      onChanged: (value) {
                        setState(() {
                          transitions = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    Text(
                      'Громкость голоса: '
                      '${voiceVolume.round()}%',
                    ),

                    Slider(
                      value: voiceVolume,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (value) {
                        setState(() {
                          voiceVolume = value;
                        });
                      },
                    ),

                    Text(
                      'Громкость музыки: '
                      '${musicVolume.round()}%',
                    ),

                    Slider(
                      value: musicVolume,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      onChanged: (value) {
                        setState(() {
                          musicVolume = value;
                        });
                      },
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white24,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Параметры экспорта',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$format • $resolution • '
                            '$dimensions • $fps FPS',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: createVideo,
              icon: const Icon(Icons.video_settings),
              label: const Text(
                'СОЗДАТЬ ВИДЕО',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Подходит для YouTube Long, Shorts, TikTok '
              'и квадратных видео.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
