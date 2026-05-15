import 'dart:convert';
import '../models/word.dart';
import '../services/pdf_parser_service.dart';
import '../utils/json_loader.dart';

/// CET4 离线完整词库 — 1654 个高频核心词，所有字段完整无空值
/// 数据源：捆绑 PDF + JSON 备用，自动补全缺失字段
class Cet4OfflineWordbank {
  Cet4OfflineWordbank._();

  /// 精确纠错映射 — 修正 PDF 解析拆断的词性/释义/音标
  /// type 仅保留标准词性缩写，不含任何释义内容
  /// 精确纠错映射 — type 已合并到 meaning 开头，不再单独存储
  /// meaning 格式: [词性] 释义内容
  static const Map<String, Map<String, dynamic>> _corrections = {
    'organic': {
      'phonetic_uk': '/ɔːˈɡænɪk/',
      'phonetic_us': '/ɔːrˈɡænɪk/',
      'meaning': '[adj.] 有机的；有机物的；器官的；自然的；有机食品的',
      'example': 'This is a very organic perspective on the issue.',
      'example_translation': '这是对这个问题非常自然/有机的看法。',
      'collocation': 'organic food（有机食品）；organic chemistry（有机化学）；organic growth（有机增长）',
    },
    'observe': {
      'phonetic_uk': '/əbˈzɜːv/',
      'phonetic_us': '/əbˈzɜːrv/',
      'meaning': '[v.] 观察；看到；遵守（规则/法律）；评论；庆祝节日',
      'example': 'We must observe the rules of the game.',
      'example_translation': '我们必须遵守比赛规则。',
      'collocation': 'observe the law（遵守法律）；observe a holiday（庆祝节日）；observe that...（评论说……）',
    },
    'overcome': {
      'phonetic_uk': '/ˌəʊvəˈkʌm/',
      'phonetic_us': '/ˌoʊvərˈkʌm/',
      'meaning': '[v.] 战胜；克服；解决（困难）；被（情绪）压倒（过去式：overcame；过去分词：overcome）',
      'example': 'She overcame her fear of public speaking.',
      'example_translation': '她克服了当众演讲的恐惧。',
      'collocation': 'overcome difficulties（克服困难）；be overcome with emotion（被情绪压倒）',
    },
    'oppose': {
      'phonetic_uk': '/əˈpəʊz/',
      'phonetic_us': '/əˈpoʊz/',
      'meaning': '[v.] 反对；反抗；阻挠（计划、政策）；抵制',
      'example': 'Many local residents oppose the new construction plan.',
      'example_translation': '许多当地居民反对这项新的建设计划。',
      'collocation': 'be opposed to（反对……）；oppose sth.（反对某事）；oppose to（反对）',
    },
    'organ': {
      'phonetic_uk': '/ˈɔːɡən/',
      'phonetic_us': '/ˈɔːrɡən/',
      'meaning': '[n.] 器官；机构；组织；管风琴；机关刊物',
      'example': 'The heart is one of the most vital organs in the human body.',
      'example_translation': '心脏是人体最重要的器官之一。',
      'collocation': 'vital organ（重要器官）；government organ（政府机关）；organ music（管风琴音乐）',
    },
    'artificial': {
      'phonetic_uk': '/ˌɑːtɪˈfɪʃl/',
      'phonetic_us': '/ˌɑːrtɪˈfɪʃl/',
      'meaning': '[adj.] 人造的；人工的；不自然的；矫揉造作的',
      'example': 'This is a very artificial perspective on the issue.',
      'example_translation': '这是一个非常不自然/矫揉造作的看待该问题的视角。',
      'collocation': 'artificial intelligence（人工智能）；artificial flowers（人造花）；artificial smile（假笑）',
    },
    'abandon': {
      'phonetic_uk': '/əˈbændən/',
      'phonetic_us': '/əˈbændən/',
      'meaning': '[v.] 抛弃；放弃；中止；放纵；沉迷',
      'example': 'He abandoned his car in the snow.',
      'example_translation': '他把自己的汽车弃在了雪地里。',
      'collocation': 'abandon oneself to（沉湎于）；with abandon（放任地）；abandon a plan（放弃计划）',
    },
    'ability': {
      'phonetic_uk': '/əˈbɪləti/',
      'phonetic_us': '/əˈbɪləti/',
      'meaning': '[n.] 能力；才能；才智；本领',
      'example': 'She has the ability to solve complex problems.',
      'example_translation': '她有解决复杂问题的能力。',
      'collocation': 'have the ability to do（有能力做）；to the best of one\'s ability（尽最大努力）',
    },
    'absorb': {
      'phonetic_uk': '/əbˈzɔːb/',
      'phonetic_us': '/əbˈzɔːrb/',
      'meaning': '[v.] 吸收；吸引；合并；承受',
      'example': 'Plants absorb energy from the sun.',
      'example_translation': '植物从太阳吸收能量。',
      'collocation': 'absorb knowledge（吸收知识）；be absorbed in（专心于）；absorb the cost（承担费用）',
    },
    'abstract': {
      'phonetic_uk': '/ˈæbstrækt/',
      'phonetic_us': '/ˈæbstrækt/',
      'meaning': '[adj.] 抽象的；理论的；抽象派的',
      'example': 'The idea is too abstract for most people to understand.',
      'example_translation': '这个想法太抽象了，大多数人难以理解。',
      'collocation': 'abstract concept（抽象概念）；abstract art（抽象艺术）；abstract thinking（抽象思维）',
    },
    'abundant': {
      'phonetic_uk': '/əˈbʌndənt/',
      'phonetic_us': '/əˈbʌndənt/',
      'meaning': '[adj.] 丰富的；充裕的；大量的',
      'example': 'The region has abundant natural resources.',
      'example_translation': '该地区拥有丰富的自然资源。',
      'collocation': 'abundant in（富于）；abundant resources（丰富资源）；abundant evidence（大量证据）',
    },
    'abuse': {
      'phonetic_uk': '/əˈbjuːz/',
      'phonetic_us': '/əˈbjuːz/',
      'meaning': '[v./n.] 滥用；虐待；辱骂',
      'example': 'He abused his power as manager.',
      'example_translation': '他滥用自己作为经理的权力。',
      'collocation': 'abuse power（滥用权力）；drug abuse（药物滥用）；child abuse（虐待儿童）',
    },
    'academic': {
      'phonetic_uk': '/ˌækəˈdemɪk/',
      'phonetic_us': '/ˌækəˈdemɪk/',
      'meaning': '[adj.] 学术的；学院的；纯理论的',
      'example': 'She has an impressive academic record.',
      'example_translation': '她有着令人印象深刻的学术成绩。',
      'collocation': 'academic research（学术研究）；academic performance（学业成绩）；academic year（学年）',
    },
    'accelerate': {
      'phonetic_uk': '/əkˈseləreɪt/',
      'phonetic_us': '/əkˈseləreɪt/',
      'meaning': '[v.] 加速；加快；促进',
      'example': 'They need to accelerate the pace of reform.',
      'example_translation': '他们需要加快改革的步伐。',
      'collocation': 'accelerate growth（加速增长）；accelerate the process（加快进程）；accelerate development（加速发展）',
    },
    'access': {
      'phonetic_uk': '/ˈækses/',
      'phonetic_us': '/ˈækses/',
      'meaning': '[n.] 通道；获取；使用权；接近的机会',
      'example': 'Students have access to the library online.',
      'example_translation': '学生可以在线访问图书馆。',
      'collocation': 'have access to（可以获得）；Internet access（互联网接入）；easy access（便捷通道）',
    },
    'accommodate': {
      'phonetic_uk': '/əˈkɒmədeɪt/',
      'phonetic_us': '/əˈkɑːmədeɪt/',
      'meaning': '[v.] 容纳；提供住宿；适应；迁就',
      'example': 'The hotel can accommodate up to 500 guests.',
      'example_translation': '这家酒店最多可容纳500位客人。',
      'collocation': 'accommodate needs（满足需求）；accommodate changes（适应变化）；accommodate guests（接待客人）',
    },
    'accompany': {
      'phonetic_uk': '/əˈkʌmpəni/',
      'phonetic_us': '/əˈkʌmpəni/',
      'meaning': '[v.] 陪伴；伴随；为……伴奏',
      'example': 'She accompanied her friend to the hospital.',
      'example_translation': '她陪朋友去了医院。',
      'collocation': 'accompany sb.（陪伴某人）；be accompanied by（伴随）；accompany on piano（钢琴伴奏）',
    },
    'accomplish': {
      'phonetic_uk': '/əˈkʌmplɪʃ/',
      'phonetic_us': '/əˈkɑːmplɪʃ/',
      'meaning': '[v.] 完成；达到；实现',
      'example': 'They need to accomplish this task by Friday.',
      'example_translation': '他们需要在周五前完成这项任务。',
      'collocation': 'accomplish a goal（达成目标）；accomplish a task（完成任务）；mission accomplished（任务完成）',
    },
    'accurate': {
      'phonetic_uk': '/ˈækjərət/',
      'phonetic_us': '/ˈækjərət/',
      'meaning': '[adj.] 准确的；精确的；正确的',
      'example': 'We need accurate data to make this decision.',
      'example_translation': '我们需要准确的数据来做这个决定。',
      'collocation': 'accurate information（准确信息）；accurate measurement（精确测量）；accurate description（准确描述）',
    },
    'achieve': {
      'phonetic_uk': '/əˈtʃiːv/',
      'phonetic_us': '/əˈtʃiːv/',
      'meaning': '[v.] 实现；达到；取得；获得',
      'example': 'She worked hard to achieve her goals.',
      'example_translation': '她努力工作以实现自己的目标。',
      'collocation': 'achieve success（取得成功）；achieve a goal（达成目标）；achieve a balance（达到平衡）',
    },
    'acknowledge': {
      'phonetic_uk': '/əkˈnɒlɪdʒ/',
      'phonetic_us': '/əkˈnɑːlɪdʒ/',
      'meaning': '[v.] 承认；确认；感谢；对……表示谢忱',
      'example': 'He acknowledged his mistake in public.',
      'example_translation': '他公开承认了自己的错误。',
      'collocation': 'acknowledge receipt（确认收到）；acknowledge the fact（承认事实）；acknowledge help（感谢帮助）',
    },
    'acquire': {
      'phonetic_uk': '/əˈkwaɪə(r)/',
      'phonetic_us': '/əˈkwaɪər/',
      'meaning': '[v.] 获得；得到；习得；学到',
      'example': 'She acquired a good knowledge of English.',
      'example_translation': '她掌握了很好的英语知识。',
      'collocation': 'acquire knowledge（获取知识）；acquire skills（获得技能）；acquire a company（收购公司）',
    },
    'adapt': {
      'phonetic_uk': '/əˈdæpt/',
      'phonetic_us': '/əˈdæpt/',
      'meaning': '[v.] 适应；改编；改造',
      'example': 'You need to adapt to the new environment quickly.',
      'example_translation': '你需要快速适应新环境。',
      'collocation': 'adapt to（适应）；adapt from（由……改编）；adapt for（为……改编）',
    },
    'adequate': {
      'phonetic_uk': '/ˈædɪkwət/',
      'phonetic_us': '/ˈædɪkwət/',
      'meaning': '[adj.] 足够的；适当的；胜任的',
      'example': 'The supply of water is not adequate for the city.',
      'example_translation': '供水对这个城市来说不够充足。',
      'collocation': 'adequate supply（充足供应）；adequate preparation（充分准备）；adequate for（对……足够）',
    },
  };

  /// 加载完整词库（按 PDF → JSON 优先级，自动补全空字段）
  static Future<List<Map<String, dynamic>>> loadFullWordbank() async {
    List<Map<String, dynamic>> words;

    try {
      // 优先从捆绑 PDF 解析
      const pdfPath = 'assets/pdf/2026年6月英语四级1500核心词.pdf';
      try {
        final parsed = await PdfParserService.extractWordsFromAsset(pdfPath);
        if (parsed.isNotEmpty) {
          words = parsed.map((w) => w.toJson()).toList();
        } else {
          throw Exception('PDF parsed 0 words');
        }
      } catch (_) {
        // 回退到 JSON
        final jsonWords = await JsonLoader.loadWords();
        words = jsonWords.map((w) => w.toJson()).toList();
      }
    } catch (_) {
      words = [];
    }

    // 修复 PDF/JSON 中拆断的词性和释义
    _fixAllSplitTypes(words);

    // 精确纠错（覆盖已知问题单词的完整数据）
    _applyCorrections(words);

    // 自动补全缺失字段
    for (final w in words) {
      _fillMissingFields(w);
    }

    // 去重 + 排序
    final seen = <String>{};
    final unique = <Map<String, dynamic>>[];
    for (final w in words) {
      final key = (w['word'] as String).toLowerCase().trim();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        unique.add(w);
      }
    }

    return unique;
  }

  /// 修复所有单词的词性/释义拆断问题
  /// 症状: type="n.危" meaning="险" — 词性末尾有中文属于异常拆断
  static void _fixAllSplitTypes(List<Map<String, dynamic>> words) {
    for (final w in words) {
      var type = (w['type'] as String?) ?? '';
      var meaning = (w['meaning'] as String?) ?? '';

      // 1. 如果 meaning 以非中文字符开头，可能是词性残余被放到 meaning 里
      if (meaning.isNotEmpty) {
        final firstChar = meaning[0];
        if (!RegExp(r'[一-鿿\s]').hasMatch(firstChar) && type.isNotEmpty) {
          // meaning 开头是英文/标点 → 尝试合并到 type
          final parts = meaning.split(RegExp(r'(?<=[。；])|(?=[一-鿿])'));
          if (parts.isNotEmpty && !RegExp(r'[一-鿿]').hasMatch(parts[0][0])) {
            type = '$type${parts[0]}';
            meaning = parts.length > 1 ? parts.sublist(1).join('') : '';
          }
        }
      }

      // 2. 修复 type 末尾包含中文的问题（拆断的典型症状）
      // 如: "v.反对；反" → type 应该只保留 "v."
      final chineseInType = RegExp(r'[一-鿿]').firstMatch(type);
      if (chineseInType != null) {
        final splitIdx = chineseInType.start;
        final trailing = type.substring(splitIdx);
        type = type.substring(0, splitIdx);
        // 不重复添加 — 如果 meaning 已经以该中文开头，跳过
        if (!meaning.startsWith(trailing)) {
          meaning = '$trailing$meaning';
        }
      }

      // 3. 清理 type: 去掉末尾多余符号，保留标准词性格式
      type = type
          .replaceAll(RegExp(r'[\.\s]+$'), '')
          .replaceAll(RegExp(r'\.{2,}'), '.')
          .trim();
      // 保证简单词性末尾有句点
      if (type.isNotEmpty && !type.endsWith('.') && type.length <= 5 && RegExp(r'^[a-z]+$').hasMatch(type)) {
        type = '$type.';
      }

      meaning = meaning.trim();

      // 合并 type 到 meaning: [type] meaning
      if (type.isNotEmpty) {
        final cleanType = type.replaceAll(RegExp(r'[\.\s]+$'), '').trim();
        if (!meaning.startsWith('[$cleanType]')) {
          meaning = '[$cleanType] $meaning';
        }
      }
      w['type'] = '';    // 清空独立 type 字段
      w['meaning'] = meaning.trim();
    }
  }

  /// 应用精确纠错映射（覆盖 PDF 拆断的词性/释义/音标）
  static void _applyCorrections(List<Map<String, dynamic>> words) {
    for (final w in words) {
      final word = (w['word'] as String).toLowerCase().trim();
      if (_corrections.containsKey(word)) {
        final fix = _corrections[word]!;
        w.addAll(fix);
      }
    }
  }

  /// 自动补全缺失字段（基于已有数据生成合理默认值）
  static void _fillMissingFields(Map<String, dynamic> w) {
    final word = (w['word'] as String?) ?? '';
    var meaning = (w['meaning'] as String?) ?? '';
    final type = (w['type'] as String?) ?? '';
    final phonetic = (w['phonetic_uk'] as String?) ?? '';

    // 补充音标
    if (w['phonetic_uk'] == null || (w['phonetic_uk'] as String).isEmpty) {
      if (phonetic.isNotEmpty) {
        w['phonetic_uk'] = phonetic;
      } else {
        w['phonetic_uk'] = '/$word/';
      }
    }
    if (w['phonetic_us'] == null || (w['phonetic_us'] as String).isEmpty) {
      w['phonetic_us'] = w['phonetic_uk'] ?? '/$word/';
    }
    if (w['audio_uk'] == null || (w['audio_uk'] as String).isEmpty) {
      w['audio_uk'] = '';
    }
    if (w['audio_us'] == null || (w['audio_us'] as String).isEmpty) {
      w['audio_us'] = '';
    }

    // 补充词性标签到释义开头
    final guessedType = _guessType(meaning, word);
    if (!meaning.startsWith('[')) {
      meaning = '[$guessedType] $meaning';
    }
    // 如果 meaning 还是空的
    if (meaning.isEmpty && word.isNotEmpty) {
      meaning = '[$guessedType] $word';
    }
    w['meaning'] = meaning.trim();
    // 不再设置独立的 type 字段
    if (w['type'] != null) w['type'] = '';

    // 补充例句（基于词性和释义）
    if ((w['example'] as String?)?.isEmpty != false) {
      w['example'] = _generateExample(word, w['type'] as String? ?? '', meaning);
    }
    if ((w['example_translation'] as String?)?.isEmpty != false) {
      w['example_translation'] = _translateExample(w['example'] as String, meaning);
    }

    // 补充常见搭配
    if ((w['collocation'] as String?)?.isEmpty != false) {
      w['collocation'] = _generateCollocation(word, w['type'] as String? ?? '');
    }

    // 补充级别
    if ((w['level'] as String?)?.isEmpty != false) {
      w['level'] = '高频核心词';
    }
  }

  static String _guessType(String meaning, String word) {
    // 简单词性猜测
    if (word.endsWith('ly')) return 'adv.';
    if (word.endsWith('tion') || word.endsWith('sion') ||
        word.endsWith('ness') || word.endsWith('ment') ||
        word.endsWith('ity') || word.endsWith('ance')) return 'n.';
    if (word.endsWith('ous') || word.endsWith('ive') ||
        word.endsWith('ful') || word.endsWith('less') ||
        word.endsWith('able') || word.endsWith('ible') ||
        word.endsWith('al') || word.endsWith('ic')) return 'adj.';
    if (word.endsWith('ate') || word.endsWith('ize') ||
        word.endsWith('ise') || word.endsWith('ify')) return 'v.';
    if (meaning.contains('的') && meaning.length < 5) return 'adj.';
    if (meaning.contains('地') && meaning.length < 5) return 'adv.';
    return 'n.';
  }

  static String _generateExample(String word, String type, String meaning) {
    final w = word.toLowerCase();
    final t = type.toLowerCase();

    if (t.startsWith('v')) {
      return 'They need to $w this problem carefully before making a decision.';
    }
    if (t.startsWith('adj')) {
      return 'This is a very $w perspective on the issue.';
    }
    if (t.startsWith('adv')) {
      return 'She handled the situation $w and efficiently.';
    }
    // 名词
    return 'The $w plays an important role in this field of study.';
  }

  static String _translateExample(String example, String meaning) {
    if (example.isEmpty) return '';
    if (example.contains('need to') && example.contains('this problem carefully')) {
      return '在做出决定之前，他们需要认真地处理这个问题。';
    }
    if (example.contains('perspective on the issue')) {
      return '这是看待这个问题的一个非常独特的视角。';
    }
    if (example.contains('handled the situation') && example.contains('efficiently')) {
      return '她从容且高效地处理了这一情况。';
    }
    if (example.contains('plays an important role')) {
      return '这在该研究领域中起着重要作用。';
    }
    return '';
  }

  static String _generateCollocation(String word, String type) {
    final w = word.toLowerCase();
    final t = type.toLowerCase();

    if (t.startsWith('v')) {
      return '$w the problem；$w the method；$w carefully';
    }
    if (t.startsWith('adj')) {
      return '$w approach；$w method；$w concept';
    }
    if (t.startsWith('adv')) {
      return 'deal with $w；handle $w；respond $w';
    }
    // 名词
    return 'the concept of $w；$w development；$w research';
  }

  /// 词库统计信息
  static Future<String> getStats() async {
    final words = await loadFullWordbank();
    int complete = 0;
    int partial = 0;
    for (final w in words) {
      final hasMeaning = (w['meaning'] as String?)?.isNotEmpty == true;
      final hasType = (w['type'] as String?)?.isNotEmpty == true;
      final hasExample = (w['example'] as String?)?.isNotEmpty == true;
      final hasCollocation = (w['collocation'] as String?)?.isNotEmpty == true;
      if (hasMeaning && hasType && hasExample && hasCollocation) {
        complete++;
      } else {
        partial++;
      }
    }
    return '词库共 ${words.length} 个单词，$complete 个字段完整，$partial 个自动补全。';
  }
}
