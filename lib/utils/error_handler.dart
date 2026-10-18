import 'package:flutter/foundation.dart';
import '../services/log_service.dart';

/// 统一异常处理工具类
/// 用于 Service 层统一捕获和处理异常，避免重复的 try-catch 代码
class ErrorHandler {
  // 私有构造函数，防止实例化
  ErrorHandler._();

  /// 统一处理异步操作的异常
  /// 
  /// [operation] 要执行的异步操作
  /// [action] 操作名称，用于日志记录
  /// [defaultValue] 发生异常时返回的默认值（可选）
  /// [silent] 是否静默处理异常（不抛出），默认为 true
  /// [logError] 是否记录错误日志，默认为 true
  /// 
  /// 返回操作结果，如果发生异常且提供了 defaultValue 则返回默认值
  static Future<T> handle<T>(
    Future<T> Function() operation, {
    required String action,
    T? defaultValue,
    bool silent = true,
    bool logError = true,
  }) async {
    try {
      return await operation();
    } catch (e, stack) {
      // 记录错误日志（仅记录根本原因，避免重复日志）
      if (logError) {
        // 提取原始异常信息，避免层层嵌套
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ') && errorMsg.contains('操作失败:')) {
          // 如果已经是包装后的异常，只记录最简日志
          debugPrint('$action 失败: ${_extractRootCause(errorMsg)}');
        } else {
          // 首次捕获异常，记录完整日志
          LogService().logRuntime('$action 失败: $e\n堆栈跟踪: $stack');
        }
      }

      // 如果提供了默认值，返回默认值
      if (defaultValue != null) {
        return defaultValue;
      }

      // 如果设置为静默模式且没有默认值，抛出异常
      if (!silent) {
        rethrow;
      }

      // 静默模式下没有默认值，抛出异常（避免重复包装）
      // 如果已经是包装后的异常，直接重新抛出，不再嵌套包装
      if (e is Exception && e.toString().contains('操作失败:')) {
        rethrow;
      }
      
      throw Exception('$action 操作失败: $e');
    }
  }

  /// 提取异常的根本原因（去除层层包装）
  static String _extractRootCause(String error) {
    // 提取最内层的异常信息
    final matches = RegExp(r'DioException.*?(?=\n|$)').allMatches(error);
    if (matches.isNotEmpty) {
      return matches.last.group(0) ?? error;
    }
    return error;
  }

  /// 同步操作的异常处理
  /// 
  /// [operation] 要执行的同步操作
  /// [action] 操作名称，用于日志记录
  /// [defaultValue] 发生异常时返回的默认值（可选）
  /// [silent] 是否静默处理异常（不抛出），默认为 true
  /// [logError] 是否记录错误日志，默认为 true
  static T handleSync<T>(
    T Function() operation, {
    required String action,
    T? defaultValue,
    bool silent = true,
    bool logError = true,
  }) {
    try {
      return operation();
    } catch (e, stack) {
      // 记录错误日志（仅记录根本原因，避免重复日志）
      if (logError) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ') && errorMsg.contains('操作失败:')) {
          debugPrint('$action 失败: ${_extractRootCause(errorMsg)}');
        } else {
          LogService().logRuntime('$action 失败: $e\n堆栈跟踪: $stack');
        }
      }

      // 如果提供了默认值，返回默认值
      if (defaultValue != null) {
        return defaultValue;
      }

      // 如果设置为静默模式且没有默认值，抛出异常
      if (!silent) {
        rethrow;
      }

      // 静默模式下没有默认值，抛出异常（避免重复包装）
      if (e is Exception && e.toString().contains('操作失败:')) {
        rethrow;
      }
      
      throw Exception('$action 操作失败: $e');
    }
  }
}
