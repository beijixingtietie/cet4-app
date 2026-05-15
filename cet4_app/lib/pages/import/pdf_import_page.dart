import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_parser_service.dart';
import '../../models/word.dart';
import '../../models/question.dart';
import '../../database/db_helper.dart';

enum ImportType { vocabulary, questionBank, listening }

class PdfImportPage extends StatefulWidget {
  final ImportType initialType;
  const PdfImportPage({super.key, this.initialType = ImportType.vocabulary});

  @override
  State<PdfImportPage> createState() => _PdfImportPageState();
}

class _PdfImportPageState extends State<PdfImportPage> {
  late ImportType _type;
  final DbHelper _dbHelper = DbHelper();

  // 文件状态
  String? _fileName;

  // 解析结果
  List<Word> _extractedWords = [];
  List<Question> _extractedQuestions = [];

  // UI 状态
  bool _isPicking = false;
  bool _isParsing = false;
  String? _error;
  bool _replaceExisting = true;
  bool _importDone = false;
  int _importedCount = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  // ========== 文件选择 & 解析 ==========

  Future<void> _pickAndParsePdf() async {
    setState(() { _isPicking = true; _error = null; });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isPicking = false);
        return;
      }

      final file = result.files.first;
      if (file.bytes == null || file.bytes!.isEmpty) {
        setState(() {
          _error = '无法读取文件内容，请重试';
          _isPicking = false;
        });
        return;
      }

      setState(() {
        _fileName = file.name;
        _isPicking = false;
        _isParsing = true;
        _importDone = false;
      });

      await _parsePdf(file.bytes!);
    } catch (e) {
      setState(() {
        _error = '文件选择失败: $e';
        _isPicking = false;
      });
    }
  }

  Future<void> _parsePdf(Uint8List bytes) async {
    try {
      if (_type == ImportType.vocabulary) {
        _extractedWords = PdfParserService.extractWords(bytes);
        _extractedQuestions = [];
      } else {
        _extractedQuestions = PdfParserService.extractQuestions(
          bytes,
          _type == ImportType.listening ? '2017-2025' : '2017-2020',
        );
        _extractedWords = [];
      }

      final itemCount = _type == ImportType.vocabulary
          ? _extractedWords.length
          : _extractedQuestions.length;

      setState(() {
        _isParsing = false;
        if (itemCount == 0) {
          _error = '未能从PDF中提取到数据。请确认：\n'
              '1. PDF文件格式正确\n'
              '2. 不是扫描版PDF（扫描版无法提取文字）\n'
              '3. 内容结构与标准四级词书/真题PDF一致';
        }
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _error = 'PDF解析失败: $e';
      });
    }
  }

  // ========== 导入到数据库 ==========

  Future<void> _performImport() async {
    setState(() { _error = null; });

    try {
      if (_type == ImportType.vocabulary) {
        if (_replaceExisting) {
          await _dbHelper.delete('words');
        }
        final jsonList = _extractedWords.map((w) => w.toJson()).toList();
        await _dbHelper.batchInsert('words', jsonList);
        _importedCount = jsonList.length;
      } else {
        if (_replaceExisting) {
          await _dbHelper.delete('questions');
        }
        final jsonList = _extractedQuestions.map((q) => q.toDbMap()).toList();
        await _dbHelper.batchInsert('questions', jsonList);
        _importedCount = jsonList.length;
      }

      setState(() { _importDone = true; });
    } catch (e) {
      setState(() { _error = '导入失败: $e'; });
    }
  }

  // ========== UI ==========

  @override
  Widget build(BuildContext context) {
    final itemCount = _type == ImportType.vocabulary
        ? _extractedWords.length
        : _extractedQuestions.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入PDF数据'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Step 1: 类型选择
            _buildSectionTitle('1. 选择导入类型'),
            const SizedBox(height: 8),
            _buildTypeSelector(),
            const SizedBox(height: 24),

            // Step 2: 文件选择
            _buildSectionTitle('2. 选择PDF文件'),
            const SizedBox(height: 8),
            _buildFilePicker(),
            const SizedBox(height: 24),

            // Step 3: 解析结果
            if (_isParsing) ...[
              _buildSectionTitle('3. 正在解析...'),
              const SizedBox(height: 16),
              const Center(
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('正在提取PDF内容，请稍候...'),
                ]),
              ),
            ] else if (_error != null && _extractedWords.isEmpty && _extractedQuestions.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ] else if (itemCount > 0) ...[
              _buildSectionTitle('3. 解析结果 ($itemCount 条)'),
              const SizedBox(height: 8),
              _buildPreviewList(),
              const SizedBox(height: 16),

              // 导入选项
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('替换现有数据'),
                      subtitle: const Text('清除后导入', style: TextStyle(fontSize: 12)),
                      value: true,
                      groupValue: _replaceExisting,
                      onChanged: (v) => setState(() => _replaceExisting = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('追加到现有数据'),
                      subtitle: const Text('保留已有数据', style: TextStyle(fontSize: 12)),
                      value: false,
                      groupValue: _replaceExisting,
                      onChanged: (v) => setState(() => _replaceExisting = v!),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 导入按钮
              ElevatedButton.icon(
                onPressed: _importDone ? null : _performImport,
                icon: _importDone
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.cloud_upload),
                label: Text(_importDone ? '导入完成 ($_importedCount 条)' : '开始导入'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _importDone ? Colors.green : null,
                  foregroundColor: _importDone ? Colors.white : null,
                ),
              ),

              if (_importDone) ...[
                const SizedBox(height: 12),
                Text(
                  '数据已成功导入，请返回上一页查看。',
                  style: TextStyle(color: Colors.green[700], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else if (_fileName != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '未提取到数据。这可能是因为PDF为扫描版或不支持的格式。',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_error != null && itemCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.orange)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _buildTypeChip('词汇', ImportType.vocabulary, Icons.book),
        const SizedBox(width: 8),
        _buildTypeChip('真题', ImportType.questionBank, Icons.quiz),
        const SizedBox(width: 8),
        _buildTypeChip('听力', ImportType.listening, Icons.headphones),
      ],
    );
  }

  Widget _buildTypeChip(String label, ImportType type, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : null),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _type = type;
            _fileName = null;
            _extractedWords = [];
            _extractedQuestions = [];
            _error = null;
            _importDone = false;
          });
        },
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _isPicking ? null : _pickAndParsePdf,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: _fileName != null ? Colors.green : Colors.grey[300]!,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12),
          color: _fileName != null ? Colors.green[50] : Colors.grey[50],
        ),
        child: Column(
          children: [
            Icon(
              _fileName != null ? Icons.picture_as_pdf : Icons.upload_file,
              size: 48,
              color: _fileName != null ? Colors.green : Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              _fileName ?? '点击选择PDF文件',
              style: TextStyle(
                fontSize: 14,
                color: _fileName != null ? Colors.green[700] : Colors.grey[600],
              ),
            ),
            if (_fileName != null)
              Text(
                '点击重新选择',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewList() {
    final itemCount = _type == ImportType.vocabulary
        ? _extractedWords.length
        : _extractedQuestions.length;
    final previewCount = itemCount.clamp(0, 10);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: previewCount + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == previewCount && itemCount > previewCount) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '... 还有 ${itemCount - previewCount} 条数据',
                style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
            );
          }

          if (_type == ImportType.vocabulary) {
            final word = _extractedWords[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.blue[100],
                child: Text('${index + 1}', style: const TextStyle(fontSize: 11)),
              ),
              title: Text(word.word, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(word.meaning, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          } else {
            final q = _extractedQuestions[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: _questionTypeColor(q.type),
                child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
              title: Text(q.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(q.content, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }
        },
      ),
    );
  }

  Color _questionTypeColor(String type) {
    switch (type) {
      case '听力': return Colors.blue;
      case '选词填空': return Colors.green;
      case '长篇阅读': return Colors.orange;
      case '仔细阅读': return Colors.purple;
      case '翻译': return Colors.red;
      case '写作': return Colors.teal;
      default: return Colors.grey;
    }
  }
}
