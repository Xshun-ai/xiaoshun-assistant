import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../constants/api_urls.dart';
import '../utils/error_handler.dart';

class ScheduleTerm {
  final String id;
  final String name;
  final bool isCurrent;

  const ScheduleTerm({
    required this.id,
    required this.name,
    required this.isCurrent,
  });

  factory ScheduleTerm.fromJson(Map<String, dynamic> json) {
    final id = json['xnxq01id']?.toString() ?? '';
    return ScheduleTerm(
      id: id,
      name: json['xqmc']?.toString() ?? id,
      isCurrent: json['isdqxq']?.toString() == '1',
    );
  }
}

class ScheduleService {
  final Dio _dio;

  ScheduleService([Dio? dio]) : _dio = dio ?? _createDefaultDio();

  static Dio _createDefaultDio() {
    final dio = Dio();
    // 为教务系统API配置适当的超时时间
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    dio.options.sendTimeout = const Duration(seconds: 15);
    return dio;
  }

  /// 获取完整的课表数据（包含当前周次信息）
  ///
  /// API 行为说明：
  /// - 开学前/即将开学: week='' 返回 nowWeek="all"，等同于全量课程，无需额外请求 week=all
  /// - 开学后: week='' 返回当周课程 + 真实 nowWeek 数字 + 真实日期列表
  ///
  /// 策略：
  /// 1. 并行请求 week='' 和 week='all'
  /// 2. 检查 week='' 的 nowWeek 是否为有效数字
  ///    - 是有效数字（开学后）: 将周次和日期注入到 week=all 数据中
  ///    - 不是有效数字（开学前）: 不注入，避免污染数据
  Future<Map<String, dynamic>?> fetchFullSchedule(
    String token, {
    String? termId,
    String? periodModeId,
  }) async {
    return ErrorHandler.handle(
      () async {
        // 两个请求独立降级，避免一个接口异常导致另一份课表也无法使用。
        Object? firstError;
        final results = await Future.wait<Map<String, dynamic>?>([
          _tryFetchSchedule(
            token,
            week: '',
            termId: termId,
            periodModeId: periodModeId,
            onError: (error) => firstError ??= error,
          ),
          _tryFetchSchedule(
            token,
            week: 'all',
            termId: termId,
            periodModeId: periodModeId,
            onError: (error) => firstError ??= error,
          ),
        ]);

        final currentData = results[0];
        final allData = results[1];

        // 只要全量数据获取成功，就以全量数据为基础
        if (allData != null) {
          if (currentData != null) {
            final nowWeekStr = currentData['nowWeek']?.toString() ?? '';
            final nowWeekInt = int.tryParse(nowWeekStr);

            if (nowWeekInt != null) {
              // ====== 开学后模式 ======
              // nowWeek 是有效数字，说明 week='' 返回了真实的当周数据
              debugPrint('DEBUG: 开学后模式, 当前第 $nowWeekInt 周');

              // 1. 注入 nowWeek (当前周次)
              allData['nowWeek'] = currentData['nowWeek'];
              allData['baseWeekForDates'] = nowWeekInt;
              debugPrint('DEBUG: 已注入当前周次: ${allData['nowWeek']}');

              // 2. 注入 date 列表 (包含本周的具体日期，用于 getCurrentWeek 中的日期推算)
              final currentList = currentData['data'] as List?;
              final allList = allData['data'] as List?;

              if (currentList != null &&
                  currentList.isNotEmpty &&
                  allList != null &&
                  allList.isNotEmpty) {
                final currentDateList = currentList[0]['date'] as List?;
                // 确保日期列表有真实日期再注入
                final hasValidDate =
                    currentDateList?.any(
                      (item) => item['mxrq']?.toString().isNotEmpty == true,
                    ) ??
                    false;
                if (hasValidDate) {
                  allList[0]['date'] = currentDateList;
                  debugPrint('DEBUG: 已注入本周日期信息用于周次推算');
                }
              }
            } else {
              // ====== 开学前模式 ======
              // nowWeek 不是有效数字（如 "all"），说明 week='' 返回的是全量课程
              // 我们额外请求 week=1 获取真实的学期日期
              debugPrint(
                'DEBUG: 开学前模式 (nowWeek=$nowWeekStr), 额外请求 week=1 获取真实日期',
              );
              final week1Data = await fetchSchedule(
                token,
                week: '1',
                termId: termId,
                periodModeId: periodModeId,
              );
              if (week1Data != null) {
                final week1List = week1Data['data'] as List?;
                final allList = allData['data'] as List?;
                if (week1List != null &&
                    week1List.isNotEmpty &&
                    allList != null &&
                    allList.isNotEmpty) {
                  final dateList = week1List[0]['date'] as List?;
                  final hasValidDate =
                      dateList?.any(
                        (item) => item['mxrq']?.toString().isNotEmpty == true,
                      ) ??
                      false;
                  if (hasValidDate) {
                    allList[0]['date'] = dateList;
                    allData['baseWeekForDates'] = 1; // 记录这组日期对应的周次基准
                    debugPrint('DEBUG: 已利用 week=1 注入第一周日期信息用于后续周次日期推算');
                  }
                }
              }
            }
          }
          return allData;
        }

        // 如果全量失败但当前周成功，降级返回当前周数据（至少能看本周）
        if (currentData != null) {
          return currentData;
        }

        if (firstError != null) {
          throw firstError!;
        }
        return null;
      },
      action: '组合获取课表',
      silent: false,
    );
  }

  Future<Map<String, dynamic>?> _tryFetchSchedule(
    String token, {
    required String week,
    String? termId,
    String? periodModeId,
    void Function(Object error)? onError,
  }) async {
    try {
      return await fetchSchedule(
        token,
        week: week,
        termId: termId,
        periodModeId: periodModeId,
      );
    } catch (e) {
      onError?.call(e);
      debugPrint('DEBUG: 课表 week=$week 请求失败，继续使用其他响应: $e');
      return null;
    }
  }

  /// 获取课表数据
  ///
  /// [token] 移动端教务系统 Token
  /// [termId] 学期ID（如 "2025-2026-1"），为空则使用服务器默认学期
  /// [week] 周次（可选，默认为 'all' 获取所有周次）
  /// [retry] 当前重试次数（内部参数）
  Future<Map<String, dynamic>?> fetchSchedule(
    String token, {
    String? termId,
    String? periodModeId,
    String week = 'all',
    int retry = 0,
  }) async {
    return ErrorHandler.handle(
      () async {
        final encodedTermId = Uri.encodeQueryComponent(termId ?? '');
        final encodedPeriodModeId = Uri.encodeQueryComponent(
          periodModeId ?? '',
        );
        final url =
            '${ApiUrls.jwBaseUrl}/njwhd/student/curriculum?xnxq01id=$encodedTermId&kbjcmsid=$encodedPeriodModeId&week=$week';

        try {
          final resp = await _dio
              .post(url, options: _buildOptions(token))
              .timeout(const Duration(seconds: 10)); // 延长超时至10秒，避免网络抖动导致失败

          if (resp.statusCode == 200 && resp.data != null) {
            return resp.data as Map<String, dynamic>;
          }

          return null;
        } catch (e) {
          // 如果是500错误且未超过重试次数，进行重试
          if (e.toString().contains('500') && retry < 3) {
            // 增加重试次数到3次
            debugPrint('DEBUG: 课表请求遇到500错误，等待2秒后重试 (第${retry + 1}次)');
            await Future.delayed(const Duration(seconds: 2)); // 增加重试间隔到2秒
            return fetchSchedule(
              token,
              termId: termId,
              periodModeId: periodModeId,
              week: week,
              retry: retry + 1,
            );
          }
          rethrow; // 其他错误或超过重试次数，抛出异常
        }
      },
      action: '获取课表',
      silent: false,
    );
  }

  /// 获取可查询的学期列表。
  Future<List<ScheduleTerm>> fetchTerms(String token) async {
    return ErrorHandler.handle(() async {
      final response = await _dio.post(
        '${ApiUrls.jwBaseUrl}/njwhd/getXnxqList',
        options: _buildOptions(token),
      );
      final data = response.data;
      if (response.statusCode != 200 || data is! List) {
        throw Exception('获取课表学期列表失败');
      }
      return data
          .whereType<Map>()
          .map((item) => ScheduleTerm.fromJson(Map<String, dynamic>.from(item)))
          .where((term) => term.id.isNotEmpty)
          .toList();
    }, action: '获取课表学期列表');
  }

  /// 获取当前用户的课表节次模式 ID。
  Future<String> fetchPeriodModeId(String token) async {
    return ErrorHandler.handle(() async {
      final response = await _dio.post(
        '${ApiUrls.jwBaseUrl}/njwhd/Get_sjkbms',
        options: _buildOptions(token),
      );
      final body = response.data;
      if (response.statusCode != 200 || body is! Map) {
        throw Exception('获取课表节次模式失败');
      }
      final data = body['data'];
      if (data is! List || data.isEmpty || data.first is! Map) {
        throw Exception('课表节次模式为空');
      }
      final periodModeId = (data.first as Map)['kbjcmsid']?.toString() ?? '';
      if (periodModeId.isEmpty) {
        throw Exception('课表节次模式无效');
      }
      return periodModeId;
    }, action: '获取课表节次模式');
  }

  Options _buildOptions(String token) {
    return Options(
      contentType: 'application/x-www-form-urlencoded',
      headers: {
        'Token': token,
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
      },
    );
  }

  /// 检查课程是否在当前的周次范围内
  ///
  /// [classWeek] 课程的周次范围，如 "11-13" 或 "13"
  /// [currentWeek] 当前周次
  bool _isInCurrentWeek(String classWeek, int currentWeek) {
    try {
      // 替换掉中文逗号等可能的分隔符，统一处理
      String processedWeek = classWeek.replaceAll('，', ',');

      // 处理多个时间段的情况，如 "1-3,5-7"
      List<String> periods = processedWeek.split(',');

      for (String period in periods) {
        if (period.trim().isEmpty) continue;

        if (period.contains('-')) {
          // 范围格式："11-13"
          final parts = period.split('-');
          if (parts.length == 2) {
            final startWeek = int.tryParse(parts[0].trim()) ?? 0;
            final endWeek = int.tryParse(parts[1].trim()) ?? 0;
            if (currentWeek >= startWeek && currentWeek <= endWeek) {
              return true;
            }
          }
        } else {
          // 单一格式："13"
          final week = int.tryParse(period.trim()) ?? 0;
          if (week == currentWeek) {
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: 周次解析错误: $e, 原始周次字符串: $classWeek');
    }
    return false;
  }

  bool _containsWeek(String classWeekDetails, int currentWeek) {
    return classWeekDetails
        .split(RegExp(r'[,，\s]+'))
        .map(int.tryParse)
        .any((week) => week == currentWeek);
  }

  /// 解析今日课程
  ///
  /// [scheduleData] fetchSchedule 返回的完整数据
  /// 返回今日课程列表
  List<Map<String, String>> parseTodayCourses(
    Map<String, dynamic> scheduleData,
  ) {
    return ErrorHandler.handleSync(
      () {
        final List<Map<String, String>> todayCourses = [];

        final dataList = scheduleData['data'] as List?;
        if (dataList == null || dataList.isEmpty) return [];

        final dataItem = dataList[0]; // 通常只有一个学期/周次的数据块
        final itemList = dataItem['item'] as List?;
        final dateList = dataItem['date'] as List?;

        if (itemList == null) return [];

        if (isPreSemester(scheduleData)) {
          debugPrint('DEBUG: [今日课程] 当前处于开学前状态，今日无课程');
          return [];
        }

        // 获取今天是星期几 (1-7)
        final now = DateTime.now();
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday

        debugPrint('DEBUG: [今日课程] 今天是星期 $weekday (${now.toString()})');

        // 获取当前周次
        int currentWeek = getCurrentWeek(scheduleData);

        debugPrint('DEBUG: [今日课程] 当前周次为第 $currentWeek 周');

        // 构建星期ID到星期几的映射
        final Map<int, int> weekDayMap = {};
        if (dateList != null) {
          for (final dateItem in dateList) {
            final xqid = int.tryParse(dateItem['xqid']?.toString() ?? '') ?? 0;
            final mxrq = dateItem['mxrq']?.toString() ?? '';
            if (xqid > 0 && mxrq.isNotEmpty) {
              try {
                final apiDate = DateTime.parse(mxrq);
                weekDayMap[xqid] = apiDate.weekday;
              } catch (e) {
                debugPrint('DEBUG: [今日课程] 日期解析错误 $mxrq: $e');
              }
            }
          }
        }

        for (final item in itemList) {
          // 通过weekNoteDetail判断星期几
          final weekNoteDetail = item['weekNoteDetail']?.toString() ?? '';
          if (weekNoteDetail.isEmpty) continue;

          // weekNoteDetail格式如"105,106"，第一位表示星期几
          final courseWeekDay =
              int.tryParse(weekNoteDetail.substring(0, 1)) ?? 0;

          // 检查是否是今天的课程（星期几匹配）
          if (courseWeekDay == weekday) {
            // 检查周次是否匹配
            final classWeek = item['classWeek']?.toString() ?? '';
            final classWeekDetails = item['classWeekDetails']?.toString() ?? '';

            bool isThisWeek = false;
            if (classWeekDetails.isNotEmpty) {
              isThisWeek = _containsWeek(classWeekDetails, currentWeek);
            } else if (classWeek.isNotEmpty) {
              isThisWeek = _isInCurrentWeek(classWeek, currentWeek);
            }

            if (isThisWeek) {
              final startTime = item['startTime']?.toString() ?? '';
              final endTime =
                  item['endTIme']?.toString() ?? ''; // 注意API字段拼写 endTIme

              // 计算状态
              String status = '未开始';
              if (startTime.isNotEmpty && endTime.isNotEmpty) {
                try {
                  final startParts = startTime.split(':');
                  final endParts = endTime.split(':');
                  final startDt = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    int.parse(startParts[0]),
                    int.parse(startParts[1]),
                  );
                  final endDt = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    int.parse(endParts[0]),
                    int.parse(endParts[1]),
                  );

                  if (now.isAfter(startDt) && now.isBefore(endDt)) {
                    status = '进行中';
                  } else if (now.isAfter(endDt)) {
                    status = '已结束';
                  }
                } catch (e) {
                  debugPrint('DEBUG: [今日课程] 时间解析错误: $e');
                }
              }

              todayCourses.add({
                'time': '$startTime - $endTime',
                'course': item['courseName']?.toString() ?? '未知课程',
                'location': item['location']?.toString() ?? '未知地点',
                'status': status,
                'teacher': item['teacherName']?.toString() ?? '',
                'weeks': classWeek, // 记录周次信息
              });

              debugPrint(
                'DEBUG: [今日课程] 添加课程: ${item['courseName']} 时间: $startTime-$endTime',
              );
            } else {
              debugPrint(
                'DEBUG: [今日课程] 跳过课程 ${item['courseName']} - 周次 $classWeek 不在当前第 $currentWeek 周',
              );
            }
          }
        }

        debugPrint('DEBUG: [今日课程] 共找到 ${todayCourses.length} 门今日课程');

        // 按时间排序
        todayCourses.sort(
          (a, b) => (a['time'] ?? '').compareTo(b['time'] ?? ''),
        );

        return todayCourses;
      },
      action: '解析今日课程',
      defaultValue: [],
    );
  }

  /// 判断是否处于开学前模式
  ///
  /// 当 API 返回的 nowWeek 不是有效数字（如 "all"）时，说明处于开学前模式
  bool isPreSemester(Map<String, dynamic> scheduleData) {
    final nowWeek = scheduleData['nowWeek'];
    if (nowWeek == null) return true;
    if (int.tryParse(nowWeek.toString()) == null) return true;

    // 如果 nowWeek 是数字（如 1），进一步检查返回的日期是否在未来
    try {
      final dataList = scheduleData['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        final dateList = dataList[0]['date'] as List?;
        if (dateList != null && dateList.isNotEmpty) {
          // 找第一个有效的 mxrq (如 "2026-03-09")
          for (var item in dateList) {
            final dateStr = item['mxrq']?.toString() ?? '';
            if (dateStr.isNotEmpty) {
              final date = DateTime.tryParse(dateStr);
              if (date != null) {
                final now = DateTime.now();
                // 如果这个星期的周一都在未来的日历周，说明尚未开学
                final dateMonday = DateTime(
                  date.year,
                  date.month,
                  date.day,
                ).subtract(Duration(days: date.weekday - 1));
                final nowMonday = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).subtract(Duration(days: now.weekday - 1));
                if (dateMonday.isAfter(nowMonday)) {
                  debugPrint('DEBUG: isPreSemester=true, 因为课表日期($dateStr)在未来');
                  return true;
                }
                break;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: isPreSemester 日期检查失败: $e');
    }

    return false;
  }

  /// 获取大节列表
  List<Map<String, String>> getBigPeriods(Map<String, dynamic> scheduleData) {
    try {
      final list = scheduleData['jcdatalist'] as List?;
      if (list != null && list.isNotEmpty) {
        return list
            .map(
              (e) => {
                'name': e['DJMC']?.toString() ?? '',
                'sections': e['XJMC']?.toString() ?? '',
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint('DEBUG: 解析大节信息失败: $e');
    }
    // 默认值
    return [
      {'name': '第一大节', 'sections': '01,02'},
      {'name': '第二大节', 'sections': '03,04'},
      {'name': '第三大节', 'sections': '05,06'},
      {'name': '第四大节', 'sections': '07,08'},
      {'name': '第五大节', 'sections': '09,10'},
    ];
  }

  /// 获取本周日期列表
  ///
  /// [scheduleData] 课表数据
  /// [targetWeek] 目标周次，如果提供了且与当前周不同，会自动计算目标周的日期
  List<Map<String, String>> getWeekDates(
    Map<String, dynamic> scheduleData, {
    int? targetWeek,
  }) {
    List<Map<String, String>> result = [];
    final targetWeekToUse = targetWeek ?? getCurrentWeek(scheduleData);

    // 如果存在写入的基准周(baseWeekForDates)，优先使用它计算相较于数据中日期的差距
    final baseWeek =
        scheduleData['baseWeekForDates'] as int? ??
        getCurrentWeek(scheduleData);
    final weekDiff = targetWeekToUse - baseWeek;

    // 回退方案的差距总是相对于系统当前的（getCurrentWeek 返回基于时间的推算或 nowWeek）
    final fallbackWeekDiff = targetWeekToUse - getCurrentWeek(scheduleData);

    try {
      final dataList = scheduleData['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        final dateList = dataList[0]['date'] as List?;
        if (dateList != null && dateList.isNotEmpty) {
          final sourceDates = <int, DateTime>{};
          final weekdayNames = <int, String>{};

          for (final item in dateList) {
            final xqid = int.tryParse(item['xqid']?.toString() ?? '') ?? 0;
            if (xqid < 1 || xqid > 7) continue;
            weekdayNames[xqid] = item['xqmc']?.toString() ?? '';
            final date = DateTime.tryParse(item['mxrq']?.toString() ?? '');
            if (date != null) {
              sourceDates[xqid] = date;
            }
          }

          if (sourceDates.isNotEmpty) {
            // 源站可能省略周一日期。使用任意有效日期和 xqid 反推出该周周一。
            final anchor = sourceDates.entries.first;
            final sourceMonday = anchor.value.subtract(
              Duration(days: anchor.key - 1),
            );

            result = List.generate(7, (index) {
              final xqid = index + 1;
              final sourceDate =
                  sourceDates[xqid] ?? sourceMonday.add(Duration(days: index));
              final targetDate = sourceDate.add(Duration(days: weekDiff * 7));
              final dateStr =
                  '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
              return {
                'weekday':
                    weekdayNames[xqid] ??
                    const ['一', '二', '三', '四', '五', '六', '日'][index],
                'date': dateStr,
                'id': '$xqid',
              };
            });
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: 解析周次日期失败: $e');
    }

    // 回退方案：如果 API 没有返回有效的日期或日期为空，我们基于当前时间自己生成
    final now = DateTime.now();
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final targetMonday = currentMonday.add(
      Duration(days: fallbackWeekDiff * 7),
    );

    final xqmcList = ['一', '二', '三', '四', '五', '六', '日'];

    result = [];
    for (int i = 0; i < 7; i++) {
      final newDate = targetMonday.add(Duration(days: i));
      final y = newDate.year;
      final m = newDate.month.toString().padLeft(2, '0');
      final d = newDate.day.toString().padLeft(2, '0');

      result.add({
        'weekday': xqmcList[i],
        'date': '$y-$m-$d',
        'id': '${i + 1}',
      });
    }

    return result;
  }

  /// 获取当前周次
  ///
  /// 优先级：
  /// 1. 使用 nowWeek 字段（如果是有效数字）+ 日期偏移修正
  /// 2. 使用 data[0]['week'] 字段作为备选（开学前模式下可能有值）
  /// 3. 默认返回 1
  int getCurrentWeek(Map<String, dynamic> scheduleData) {
    int week = 0;
    final nowWeek = scheduleData['nowWeek'];
    if (nowWeek != null) {
      week = int.tryParse(nowWeek.toString()) ?? 0;
    }

    // 如果 nowWeek 解析成功（有效数字），尝试根据日期偏移修正
    if (week > 0) {
      try {
        final dataList = scheduleData['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          final dateList = dataList[0]['date'] as List?;
          if (dateList != null) {
            for (var item in dateList) {
              final dateStr = item['mxrq']?.toString() ?? '';
              if (dateStr.isNotEmpty) {
                final date = DateTime.tryParse(dateStr);
                if (date != null) {
                  final now = DateTime.now();
                  // 将日期都对齐到周一
                  final dateMonday = DateTime(
                    date.year,
                    date.month,
                    date.day,
                  ).subtract(Duration(days: date.weekday - 1));
                  final nowMonday = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(Duration(days: now.weekday - 1));

                  final diffDays = nowMonday.difference(dateMonday).inDays;
                  final diffWeeks = (diffDays / 7).round();

                  if (diffWeeks != 0) {
                    final newWeek = week + diffWeeks;
                    debugPrint(
                      'DEBUG: 根据日期推算周次: 缓存周次 $week -> 真实周次 $newWeek (差 $diffWeeks 周)',
                    );
                    return newWeek;
                  }
                }
                break; // 只要有一个有效日期即可
              }
            }
          }
        }
      } catch (e) {
        debugPrint('DEBUG: 推算周次失败: $e');
      }
      return week;
    }

    // nowWeek 无效（如 "all"、空值），尝试从 data[0]['week'] 获取
    try {
      final baseWeek = int.tryParse(
        scheduleData['baseWeekForDates']?.toString() ?? '',
      );
      if (baseWeek != null && baseWeek > 0) {
        debugPrint('DEBUG: nowWeek 无效, 使用 baseWeekForDates=$baseWeek');
        return baseWeek;
      }

      final dataList = scheduleData['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        final dataWeek = dataList[0]['week'];
        if (dataWeek != null) {
          final parsed = int.tryParse(dataWeek.toString());
          if (parsed != null && parsed > 0) {
            debugPrint('DEBUG: nowWeek 无效, 使用 data[0].week=$parsed 作为当前周次');
            return parsed;
          }
        }
      }
    } catch (e) {
      debugPrint('DEBUG: 读取 data[0].week 失败: $e');
    }

    debugPrint('DEBUG: 无法确定当前周次，默认返回 1');
    return 1;
  }

  /// 解析本周所有课程
  ///
  /// [scheduleData] fetchSchedule 返回的完整数据
  /// [targetWeek] 指定周次，如果不传则使用返回数据中的 nowWeek
  /// 返回本周课程列表，包含星期几信息
  /// 解析指定周次的课程，或解析全部课程
  ///
  /// [scheduleData] fetchSchedule 返回的完整数据
  /// [targetWeek] 指定周次。传 0 或 null 时的行为：
  ///   - 0: 返回全部课程（不按周次过滤），用于开学前模式
  ///   - null: 使用 getCurrentWeek 自动获取
  /// 返回课程列表，包含星期几信息
  List<Map<String, dynamic>> parseWeekCourses(
    Map<String, dynamic> scheduleData, {
    int? targetWeek,
  }) {
    final List<Map<String, dynamic>> weekCourses = [];

    try {
      final dataList = scheduleData['data'] as List?;
      if (dataList == null || dataList.isEmpty) return [];

      final dataItem = dataList[0];
      final itemList = dataItem['item'] as List?;

      if (itemList == null) return [];

      // targetWeek == 0 表示显示全部课程（开学前模式）
      final bool showAll = targetWeek == 0;

      // 获取当前周次（优先使用指定周次）
      int currentWeek = showAll
          ? 0
          : (targetWeek ?? getCurrentWeek(scheduleData));

      debugPrint(
        'DEBUG: [完整课表] 开始解析${showAll ? "全部" : "第 $currentWeek 周"}课程 (targetWeek: $targetWeek)',
      );

      // 获取大节配置
      final bigPeriods = getBigPeriods(scheduleData);

      for (final item in itemList) {
        // 通过weekNoteDetail判断星期几
        final weekNoteDetail = item['weekNoteDetail']?.toString() ?? '';
        if (weekNoteDetail.isEmpty) continue;

        // weekNoteDetail格式如"105,106"，第一位表示星期几
        final courseWeekDay = int.tryParse(weekNoteDetail.substring(0, 1)) ?? 0;

        final classWeek = item['classWeek']?.toString() ?? '';
        final classWeekDetails = item['classWeekDetails']?.toString() ?? '';

        bool shouldInclude = false;
        if (showAll) {
          // 全部模式：不过滤周次，所有课程都包含
          shouldInclude = true;
        } else {
          // 按周次过滤
          if (classWeekDetails.isNotEmpty &&
              _containsWeek(classWeekDetails, currentWeek)) {
            shouldInclude = _containsWeek(classWeekDetails, currentWeek);
          } else if (classWeek.isNotEmpty) {
            shouldInclude = _isInCurrentWeek(classWeek, currentWeek);
          }
        }

        if (shouldInclude) {
          final startTime = item['startTime']?.toString() ?? '';
          final endTime =
              item['endTIme']?.toString() ?? ''; // 注意API字段拼写 endTIme
          final courseName = item['courseName']?.toString() ?? '未知课程';

          // 一条课程可能跨多个大节，保留起始大节和跨度供网格合并绘制。
          final bigPeriodIndexes = <int>[];
          final parts = weekNoteDetail.split(',');
          for (final part in parts) {
            if (part.length >= 3) {
              final sec = part.substring(1); // "05" from "105"
              for (int i = 0; i < bigPeriods.length; i++) {
                final bpSections = bigPeriods[i]['sections']!.split(',');
                if (bpSections.contains(sec)) {
                  if (!bigPeriodIndexes.contains(i)) {
                    bigPeriodIndexes.add(i);
                  }
                  break;
                }
              }
            }
          }

          if (bigPeriodIndexes.isNotEmpty) {
            final sortedIndexes = [...bigPeriodIndexes]..sort();
            var runStart = sortedIndexes.first;
            var previous = runStart;
            for (final periodIndex in [
              ...sortedIndexes.skip(1),
              sortedIndexes.last + 2,
            ]) {
              if (periodIndex == previous + 1) {
                previous = periodIndex;
                continue;
              }
              weekCourses.add({
                'weekDay': courseWeekDay, // 1-7
                'startTime': startTime,
                'endTime': endTime,
                'time': '$startTime - $endTime',
                'courseCode': item['kch']?.toString() ?? '',
                'course': courseName,
                'location': item['location']?.toString() ?? '未知地点',
                'teacher': item['teacherName']?.toString() ?? '',
                'weeks': classWeek,
                'weekDetails': classWeekDetails,
                'color': _getCourseColor(courseName),
                'bigPeriodIndex': runStart,
                'bigPeriodSpan': previous - runStart + 1,
              });
              runStart = periodIndex;
              previous = periodIndex;
            }
          }
        }
      }

      debugPrint(
        'DEBUG: [完整课表] ${showAll ? "全部" : "第 $currentWeek 周"}共找到 ${weekCourses.length} 门课程',
      );

      // 按星期和时间排序
      weekCourses.sort((a, b) {
        final dayCompare = (a['weekDay'] as int).compareTo(b['weekDay'] as int);
        if (dayCompare != 0) return dayCompare;
        return (a['startTime'] as String).compareTo(b['startTime'] as String);
      });
    } catch (e) {
      debugPrint('DEBUG: 解析课程失败: $e');
    }

    return weekCourses;
  }

  /// 根据课程名称生成固定的颜色
  String _getCourseColor(String courseName) {
    final colors = [
      '0xFF5C6BC0', // Indigo
      '0xFF42A5F5', // Blue
      '0xFF26A69A', // Teal
      '0xFF66BB6A', // Green
      '0xFFFFA726', // Orange
      '0xFFEF5350', // Red
      '0xFFAB47BC', // Purple
      '0xFF8D6E63', // Brown
    ];
    if (courseName.isEmpty) return colors[0];
    final index = courseName.codeUnits.fold(0, (p, c) => p + c) % colors.length;
    return colors[index];
  }
}
