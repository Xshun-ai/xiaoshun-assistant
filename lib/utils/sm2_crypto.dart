import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dart_sm/dart_sm.dart';

/// SM2 国密加密工具类
///
/// 提供符合国密标准的 SM2 加密功能，采用 C1C2C3 模式
class Sm2Crypto {
  /// 使用 SM2 算法对密码进行加密
  ///
  /// 采用 C1C2C3 模式，符合国密标准和接口文档要求。
  ///
  /// [publicKey] 公钥字符串，支持 Hex 或 Base64 格式
  /// [plaintext] 待加密的明文
  /// 返回 Base64 编码的密文
  static String encrypt(String publicKey, String plaintext) {
    // 1. 处理公钥：自动识别 HEX 或 Base64 格式，统一转为 HEX 字符串供加密库使用
    final trimmed = publicKey.trim();
    List<int> pubBytes;

    // 如果是 130 位 Hex 字符串且以 04 开头，则认为是未压缩的 Hex 公钥
    if (RegExp(r'^[0-9a-fA-F]{130}$').hasMatch(trimmed) &&
        trimmed.startsWith('04')) {
      pubBytes = _hexToBytes(trimmed);
      debugPrint('DEBUG: 检测到 HEX 格式公钥');
    } else {
      // 否则尝试 Base64 解码
      try {
        pubBytes = base64Decode(trimmed.replaceAll(RegExp(r'\s'), ''));
        debugPrint('DEBUG: 检测到 Base64 格式公钥');
      } catch (e) {
        throw Exception('公钥格式无法识别: 既不是有效的 HEX 也不是 Base64');
      }
    }

    // 转换为 Hex 字符串传递给 dart_sm 库
    final pubHex = pubBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('');

    // 2. 执行加密：使用 C1C2C3 模式
    // dart_sm 库的 encrypt 方法返回 Hex 字符串（不带 04 前缀）
    final out = SM2.encrypt(plaintext, pubHex, cipherMode: C1C2C3);

    // 3. 处理加密结果：统一转换为字节数组
    List<int> cipherBytes;
    try {
      // dart_sm 返回的是 Hex 字符串
      cipherBytes = _hexToBytes(out);
      debugPrint('DEBUG: 加密结果识别为 Hex 格式');
    } catch (_) {
      // 防御性编程：如果返回了 Base64
      try {
        cipherBytes = base64Decode(out.replaceAll(RegExp(r'\s'), ''));
        debugPrint('DEBUG: 加密结果识别为 Base64 格式');
      } catch (e) {
        throw Exception('加密结果格式无法识别');
      }
    }

    // 4. 验证密文格式：首字节必须是 0x04
    if (cipherBytes.isEmpty) {
      throw Exception('加密结果为空');
    }

    final firstByte = cipherBytes.first;
    debugPrint('DEBUG: 密文首字节: 0x${firstByte.toRadixString(16)}');

    if (firstByte != 0x04) {
      debugPrint('DEBUG: 首字节不是 0x04，自动添加 0x04 前缀');
      cipherBytes = [0x04, ...cipherBytes];
    }

    // 5. 返回最终结果：Base64 编码
    return base64Encode(cipherBytes);
  }

  /// 将 Hex 字符串转换为字节数组
  static List<int> _hexToBytes(String hex) {
    final sanitized = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final result = <int>[];
    for (var i = 0; i < sanitized.length; i += 2) {
      final byte = int.parse(sanitized.substring(i, i + 2), radix: 16);
      result.add(byte);
    }
    return result;
  }
}
