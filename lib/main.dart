import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

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
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final ImagePicker _picker = ImagePicker();

  List<XFile> images = [];
  String? voicePath;
  String? musicPath;

  String aspectRatio = '16:9';
  String resolution = '1080p';
  int fps = 30;

  bool exporting = false;
  double progress = 0;
  String status = 'Готово к работе';

  final Map<String, String> resolutions = {
    '720p': '1280:720',
    '1080p': '1920:1080',
    '1440p': '2560:1440',
    '4K': '3840:2160',
  };

  Future<void> pickImages() async {
    try {
      final List<XFile> picked = await _picker.pickMultiImage(
        imageQuality: 95,
      );

      if (picked.isNotEmpty) {
        setState(() {
          images = picked;
          status = 'Выбрано изображений: ${images.length}';
        });
      }
    } catch (e) {
      showError('Не удалось открыть галерею: $e');
    }
  }

  Future<void> pickVoice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'flac',
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          voicePath = result.files.single.path!;
          status = 'Озвучка добавлена';
        });
      }
    } catch (e) {
      showError('Не удалось выбрать озвучку: $e');
    }
  }

  Future<void> pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp3',
          'wav',
          'm4a',
          'aac',
          'ogg',
          'flac',
        ],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          musicPath = result.files.single.path!;
          status = 'Музыка добавлена';
        });
      }
    } catch (e) {
      showError('Не удалось выбрать музыку: $e');
    }
  }

  Future<double> getAudioDuration(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final information = session.getMediaInformation();

      if (information != null) {
        final durationString = information.getDuration();

        if (durationString != null) {
          return double.tryParse(durationString) ?? 0;
        }
      }
    } catch (_) {}

    return 0;
  }

  String getVideoSize() {
    if (aspectRatio == '9:16') {
      switch (resolution) {
        case '720p':
          return '720:1280';
        case '1080p':
          return '1080:1920';
        case '1440p':
          return '1440:2560';
        case '4K':
          return '2160:3840';
      }
    }

    if (aspectRatio == '1:1') {
      switch (resolution) {
        case '720p':
          return '720:720';
        case '1080p':
          return '1080:1080';
        case '1440p':
          return '1440:1440';
        case '4K':
          return '2160:2160';
      }
    }

    return resolutions[resolution] ?? '1920:1080';
  }

  Future<void> exportVideo() async {
    if (images.isEmpty) {
      showError('Сначала добавь изображения');
      return;
    }

    if (voicePath == null) {
      showError('Сначала добавь озвучку');
      return;
    }

    setState(() {
      exporting = true;
      progress = 0.05;
      status = 'Подготавливаем видео...';
    });

    try {
      final directory = await getTemporaryDirectory();

      final workDirectory = Directory(
        '${directory.path}/long_video_work',
      );

      if (await workDirectory.exists()) {
        await workDirectory.delete(recursive: true);
      }

      await workDirectory.create(recursive: true);

      final voiceDuration = await getAudioDuration(voicePath!);

      if (voiceDuration <= 0) {
        throw Exception('Не удалось определить длину озвучки');
      }

      final secondsPerImage = voiceDuration / images.length;

      setState(() {
        progress = 0.15;
        status =
            'Длина озвучки: ${voiceDuration.toStringAsFixed(1)} сек.';
      });

      final List<String> imageFiles = [];

      for (int i = 0; i < images.length; i++) {
        final source = File(images[i].path);

        final extension = images[i].path.toLowerCase().endsWith('.png')
            ? 'png'
            : 'jpg';

        final destination =
            '${workDirectory.path}/image_$i.$extension';

        await source.copy(destination);
        imageFiles.add(destination);

        setState(() {
          progress = 0.15 + ((i + 1) / images.length) * 0.25;
          status = 'Подготавливаем изображение ${i + 1}/${images.length}';
        });
      }

      final concatFile = File(
        '${workDirectory.path}/images.txt',
      );

      final buffer = StringBuffer();

      for (int i = 0; i < imageFiles.length; i++) {
        final safePath = imageFiles[i].replaceAll("'", "'\\''");

        buffer.writeln("file '$safePath'");
        buffer.writeln(
          'duration ${secondsPerImage.toStringAsFixed(4)}',
        );
      }

      final lastPath =
          imageFiles.last.replaceAll("'", "'\\''");

      buffer.writeln("file '$lastPath'");

      await concatFile.writeAsString(buffer.toString());

      final outputDirectory =
          await getApplicationDocumentsDirectory();

      final outputPath =
          '${outputDirectory.path}/LongVideo_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final size = getVideoSize();

      final audioPath =
          voicePath!.replaceAll("'", "'\\''");

      final command = [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        "'${concatFile.path}'",
        '-i',
        "'$audioPath'",
        '-vf',
        "scale=$size:force_original_aspect_ratio=decrease,"
            "pad=$size:(ow-iw)/2:(oh-ih)/2",
        '-r',
        '$fps',
        '-c:v',
        'libx264',
        '-preset',
        'veryfast',
        '-pix_fmt',
        'yuv420p',
        '-c:a',
        'aac',
        '-b:a',
        '192k',
        '-shortest',
        "'$outputPath'",
      ].join(' ');

      setState(() {
        progress = 0.45;
        status = 'Создаём видео...';
      });

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getOutput();
        throw Exception(
          'FFmpeg ошибка.\n${logs ?? 'Неизвестная ошибка'}',
        );
      }

      setState(() {
        progress = 0.95;
        status = 'Сохраняем видео...';
      });

      if (musicPath != null) {
        final music = musicPath!.replaceAll("'", "'\\''");

        final finalOutput =
            '${outputDirectory.path}/LongVideo_Final_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final musicCommand = [
          '-y',
          '-i',
          "'$outputPath'",
          '-i',
          "'$music'",
          '-filter_complex',
          '[1:a]volume=0.15[music];'
              '[0:a][music]amix=inputs=2:duration=first:dropout_transition=2[a]',
          '-map',
          '0:v',
          '-map',
          '[a]',
          '-c:v',
          'copy',
          '-c:a',
          'aac',
          '-shortest',
          "'$finalOutput'",
        ].join(' ');

        final musicSession =
            await FFmpegKit.execute(musicCommand);

        final musicCode =
            await musicSession.getReturnCode();

        if (ReturnCode.isSuccess(musicCode)) {
          try {
            await File(outputPath).delete();
          } catch (_) {}

          setState(() {
            progress = 1;
            status = 'Видео готово!';
          });

          showSuccess(finalOutput);
          return;
        }
      }

      setState(() {
        progress = 1;
        status = 'Видео готово!';
      });

      showSuccess(outputPath);
    } catch (e) {
      setState(() {
        status = 'Ошибка';
      });

      showError('$e');
    } finally {
      setState(() {
        exporting = false;
      });
    }
  }

  void showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void showSuccess(String path) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Видео готово 🎉'),
          content: Text(
            'Файл сохранён:\n\n$path',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        bottom: 10,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: exporting ? null : onPressed,
      ),
    );
  }

  Widget settingDropdown<T>({
    required String title,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Expanded(
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: title,
          border: const OutlineInputBorder(),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text('$item'),
              ),
            )
            .toList(),
        onChanged: exporting ? null : onChanged,
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
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle('Медиа'),

              actionButton(
                icon: Icons.photo_library,
                title: 'Изображения',
                subtitle: images.isEmpty
                    ? 'Выбрать фотографии'
                    : '${images.length} изображений выбрано',
                onPressed: pickImages,
              ),

              actionButton(
                icon: Icons.mic,
                title: 'Озвучка',
                subtitle: voicePath == null
                    ? 'MP3, WAV, M4A и другие'
                    : 'Озвучка добавлена',
                onPressed: pickVoice,
              ),

              actionButton(
                icon: Icons.music_note,
                title: 'Фоновая музыка',
                subtitle: musicPath == null
                    ? 'Необязательно'
                    : 'Музыка добавлена',
                onPressed: pickMusic,
              ),

              sectionTitle('Видео'),

              Row(
                children: [
                  settingDropdown<String>(
                    title: 'Формат',
                    value: aspectRatio,
                    items: const [
                      '16:9',
                      '9:16',
                      '1:1',
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          aspectRatio = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  settingDropdown<String>(
                    title: 'Разрешение',
                    value: resolution,
                    items: const [
                      '720p',
                      '1080p',
                      '1440p',
                      '4K',
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          resolution = value;
                        });
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  settingDropdown<int>(
                    title: 'FPS',
                    value: fps,
                    items: const [
                      24,
                      30,
                      60,
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          fps = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white24,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        aspectRatio == '16:9'
                            ? 'YouTube Long'
                            : aspectRatio == '9:16'
                                ? 'YouTube Shorts'
                                : 'Квадрат',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              sectionTitle('Автомонтаж'),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Автоматическая синхронизация',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Фотографии автоматически '
                        'распределяются по длине озвучки.',
                        style: TextStyle(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              if (exporting) ...[
                LinearProgressIndicator(
                  value: progress,
                ),
                const SizedBox(height: 10),
                Text(status),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: exporting ? null : exportVideo,
                  icon: const Icon(Icons.movie_creation),
                  label: Text(
                    exporting
                        ? 'Создание видео...'
                        : 'СОЗДАТЬ ВИДЕО',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}                         
