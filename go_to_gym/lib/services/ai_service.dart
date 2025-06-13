import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static const String _apiKey = 'AIzaSyD5KiBhC0zq6WnpVI8-OzgAJcWO11AIlCI';

  static final _systemPrompt = '''
Kamu adalah asisten AI yang fokus menjawab **pertanyaan seputar gym dan kebugaran**, seperti:

- Latihan otot, workout routine
- Pola makan, nutrisi, protein
- Tips pemula di gym
- Alat gym dan penggunaannya
- Latihan kardio vs kekuatan
- Pemulihan otot, stretching, istirahat
- Suplemen dan motivasi fitness

🟢 Jika pengguna membuka obrolan dengan sapaan atau basa-basi ringan, tetap jawab.

🔴 Tapi jika pertanyaan **jelas-jelas tidak ada hubungannya dengan dunia gym/fitness**, balas sopan:
> "Maaf, saya hanya bisa menjawab pertanyaan yang berkaitan dengan gym dan kebugaran ya!"

🗣️ **Penting**: Jawablah dalam **bahasa yang sama** dengan pertanyaan pengguna, baik itu Bahasa Indonesia, Inggris, atau bahasa lainnya.

Jawaban harus singkat, padat, dan ramah. Maksimal 3 paragraf.
''';

  static final List<String> _gymWords = [
    'gym',
    'fitness',
    'otot',
    'workout',
    'latihan',
    'kalori',
    'protein',
    'karbohidrat',
    'lemak',
    'dumbbell',
    'barbell',
    'cardio',
    'suplemen',
    'pemanasan',
    'stretching',
    'rest',
    'diet',
    'kalistenik',
    'angkat',
    'badan',
  ];

  static Future<String> ask(String prompt) async {
    try {
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
      final content = [Content.text(_systemPrompt), Content.text(prompt)];
      final response = await model.generateContent(content);
      return response.text?.trim() ?? 'Tidak ada jawaban dari AI.';
    } catch (e) {
      return 'Terjadi error: $e';
    }
  }

  static String? detectPossibleTypos(String input) {
    final words = input.toLowerCase().split(RegExp(r'[^a-zA-Z0-9]+'));
    final suspects = words.where((word) {
      if (word.length < 4) return false;
      return !_gymWords.any((g) => _isSimilar(word, g));
    }).toList();

    // Jika ingin kembali aktifkan typo warning, buka komentar di bawah
    // if (suspects.isNotEmpty) {
    //   return "Beberapa kata mungkin salah ketik: ${suspects.take(3).join(', ')}";
    // }
    return null;
  }

  static bool _isSimilar(String a, String b) {
    return a.contains(b) || b.contains(a) || _levenshtein(a, b) <= 2;
  }

  static int _levenshtein(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;
    List<List<int>> dp = List.generate(
      len1 + 1,
      (_) => List.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) dp[i][0] = i;
    for (int j = 0; j <= len2; j++) dp[0][j] = j;

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        if (s1[i - 1] == s2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    return dp[len1][len2];
  }
}
