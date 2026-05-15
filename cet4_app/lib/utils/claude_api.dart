import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ClaudeApiService {
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const int defaultMaxTokens = 2048;
  static const double defaultTemperature = 0.7;

  final String apiKey;
  final String baseUrl;
  final String model;
  final Dio _dio = Dio();
  final Map<String, String> _cache = {};
  final Map<String, CancelToken> _cancelTokens = {};

  ClaudeApiService({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    int timeoutSeconds = 60,
  }) {
    // 去掉尾部斜杠防止双斜杠
    final cleanUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    _dio.options.baseUrl = cleanUrl;
    _dio.options.connectTimeout = Duration(seconds: timeoutSeconds);
    _dio.options.receiveTimeout = Duration(seconds: timeoutSeconds * 2);
    _dio.options.sendTimeout = Duration(seconds: timeoutSeconds);
  }

  /// 发送普通请求（非流式） — OpenAI 兼容格式
  Future<String> sendMessage(
    String prompt, {
    String systemPrompt = "",
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
    bool useCache = true,
    bool responseFormatJson = false,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = '$baseUrl|$model|$systemPrompt|$prompt|$responseFormatJson';
    if (useCache && _cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final data = <String, dynamic>{
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'messages': [
          if (systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      };
      if (responseFormatJson) {
        data['response_format'] = {'type': 'json_object'};
      }

      final response = await _dio.post(
        '/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: data,
        cancelToken: cancelToken,
      );

      final result =
          response.data['choices'][0]['message']['content'] as String;

      if (useCache) {
        _cache[cacheKey] = result;
      }

      return result;
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('API调用失败: ${e.toString()}');
    }
  }

  /// 发送流式请求（SSE 打字机效果） — OpenAI 兼容格式
  Stream<String> sendMessageStream(
    String prompt, {
    String systemPrompt = "",
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
    String? requestId,
  }) {
    final controller = StreamController<String>();
    final cancelToken = CancelToken();

    if (requestId != null) {
      _cancelTokens[requestId] = cancelToken;
    }

    _dio
        .post(
      '/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        responseType: ResponseType.stream,
      ),
      cancelToken: cancelToken,
      data: {
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'stream': true,
        'messages': [
          if (systemPrompt.isNotEmpty)
            {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': prompt},
        ],
      },
    )
        .then((response) {
      response.data.stream.listen(
        (data) {
          try {
            final lines = String.fromCharCodes(data).split('\n');
            for (final line in lines) {
              if (line.startsWith('data: ')) {
                final jsonData = line.substring(6);
                if (jsonData.trim() == '[DONE]') {
                  controller.close();
                  return;
                }
                final event = jsonDecode(jsonData);
                final delta = event['choices']?[0]?['delta'];
                if (delta != null && delta['content'] != null) {
                  controller.add(delta['content'] as String);
                }
              }
            }
          } catch (e) {
            debugPrint('解析流式响应失败: $e');
          }
        },
        onError: (e) {
          if (e is DioException && e.type == DioExceptionType.cancel) {
            controller.close();
          } else {
            controller.addError(_handleDioError(e));
            controller.close();
          }
        },
        onDone: () {
          controller.close();
          if (requestId != null) {
            _cancelTokens.remove(requestId);
          }
        },
      );
    }).catchError((e) {
      if (e is DioException && e.type == DioExceptionType.cancel) {
        controller.close();
      } else {
        controller.addError(_handleDioError(e));
        controller.close();
      }
    });

    return controller.stream;
  }

  /// 取消正在进行的请求
  void cancelRequest(String requestId) {
    if (_cancelTokens.containsKey(requestId)) {
      _cancelTokens[requestId]!.cancel();
      _cancelTokens.remove(requestId);
    }
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
  }

  /// 处理Dio错误
  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络连接后重试';
      case DioExceptionType.sendTimeout:
        return '发送请求超时，请检查网络连接后重试';
      case DioExceptionType.receiveTimeout:
        return '接收响应超时，请检查网络连接后重试';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        if (statusCode == 401) {
          String? serverMsg;
          if (responseData is Map) {
            final error = responseData['error'];
            if (error is Map) {
              serverMsg = error['message']?.toString();
            }
          }
          return 'API密钥无效 (401)${serverMsg != null ? ": $serverMsg" : ""}。请到个人中心检查API密钥是否正确';
        } else if (statusCode == 403) {
          return 'API权限不足，请检查您的账户权限';
        } else if (statusCode == 429) {
          return '请求过于频繁，请稍后再试';
        } else if (statusCode == 500) {
          return '服务器内部错误，请稍后再试';
        } else {
          return 'API调用失败: ${responseData?['error']?['message'] ?? '未知错误'}';
        }
      case DioExceptionType.cancel:
        return '请求已取消';
      default:
        return '网络错误，请检查网络连接后重试';
    }
  }
}
