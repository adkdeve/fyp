import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../../../utils/helpers/snackbar.dart';
import '../../data/repositories/repository.dart';
import '../core.dart';

final storage = Get.find<FlutterSecureStorage>();
final myRepo = Get.find<Repository>();

enum ApisSates { loading, success, empty, error }

// for List
typedef SuccessBuilder<T> = Widget Function(List<T> data);

class ApiStateWrapper<T> extends StatelessWidget {
  final Rx<ApisSates> state;
  final RxList<T> data;
  final SuccessBuilder<T> onSuccess;
  final String emptyMessage;
  final Widget? emptyMessageWidget;
  final Widget? loadingWidget;
  final String errorMessage;

  const ApiStateWrapper({
    super.key,
    required this.state,
    required this.data,
    required this.onSuccess,
    this.emptyMessage = 'No data available',
    this.errorMessage = 'Something went wrong',
    this.emptyMessageWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (state.value) {
        case ApisSates.loading:
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        case ApisSates.empty:
          return Center(child: Text(emptyMessage));
        case ApisSates.error:
          return emptyMessageWidget != null
              ? emptyMessageWidget!
              : Center(child: Text(errorMessage));
        case ApisSates.success:
          return onSuccess(data);
      }
    });
  }
}

Future<void> fetchWithState<T>({
  required Rx<ApisSates> state,
  required RxList<T> list,
  required Future<List<T>> Function() apiMethod,
}) async {
  try {
    state.value = ApisSates.loading;
    final result = await apiMethod();

    if (result.isEmpty) {
      state.value = ApisSates.empty;
    } else {
      list.assignAll(result);
      state.value = ApisSates.success;
    }
  } catch (e) {
    state.value = ApisSates.error;
    SnackBarUtils.showError(e.toString());
  }
}

Future<List<T>> fetchList<T>({
  required String url,
  required String type,
  required data,
  required FlutterSecureStorage storage,
  required Repository myRepo,
  required String rootKey,
  required T Function(Map<String, dynamic>) fromJson,
}) async {
  String? token = await storage.read(key: MyConstants.token);
  final response;

  if (token == null) throw Exception("No token found");

  final payload = data == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(data as Map);

  if (type == 'post')
    response = await myRepo.postApiWithToken(payload, url, token);
  else
    response = await myRepo.getApiWithToken(url, token);

  print(url);
  print("Root Key$rootKey");
  print(token);
  print(response);
  if (response == null) throw Exception("No response from server");

  final jsonData = jsonDecode(response);
  if (!jsonData['success']) throw Exception("Failed to load data");

  final List<dynamic> rawList = jsonData[rootKey];
  return rawList.map((e) => fromJson(e)).toList();
}

// for List Pagination

typedef LoadMoreCallback = void Function();

class ApiStatePaginationWrapper<T> extends StatelessWidget {
  final Rx<ApisSates> state;
  final RxList<T> data;
  final SuccessBuilder<T> onSuccess;
  final String emptyMessage;
  final String errorMessage;
  final bool enableLoadMore;
  final LoadMoreCallback? onLoadMore;
  final RxBool? isLoadingMore;
  final Widget? loadingWidget;

  const ApiStatePaginationWrapper({
    super.key,
    required this.state,
    required this.data,
    required this.onSuccess,
    this.emptyMessage = 'No data available',
    this.errorMessage = 'Something went wrong',
    this.enableLoadMore = false,
    this.onLoadMore,
    this.isLoadingMore,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (state.value) {
        case ApisSates.loading:
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());

        case ApisSates.empty:
          return Center(child: Text(emptyMessage));

        case ApisSates.error:
          return Center(child: Text(errorMessage));

        case ApisSates.success:
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final canLoadMore =
                  onLoadMore != null &&
                  notification is ScrollEndNotification &&
                  notification.metrics.maxScrollExtent > 0 &&
                  notification.metrics.pixels > 0 &&
                  notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 100 &&
                  !(isLoadingMore?.value ?? false);

              if (canLoadMore) {
                onLoadMore!();
              }

              return false;
            },
            child: Column(
              children: [
                Expanded(child: onSuccess(data)),
                if (isLoadingMore?.value ?? false)
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                // 80.sbh,
              ],
            ),
          );
      }
    });
  }
}

Future<void> fetchWithPagination<T>({
  required Rx<ApisSates> state,
  required RxList<T> list,
  required Future<List<T>> Function(int page, int limit) apiMethod,
  required int page,
  int limit = 10,
  bool isLoadMore = false,
}) async {
  if (!isLoadMore) state.value = ApisSates.loading;

  try {
    final result = await apiMethod(page, limit);

    if (!isLoadMore) {
      list.assignAll(result);
    } else {
      list.addAll(result);
    }

    state.value = result.isEmpty && !isLoadMore
        ? ApisSates.empty
        : ApisSates.success;
  } catch (e) {
    if (!isLoadMore) {
      state.value = ApisSates.error;
    }
    SnackBarUtils.showError(e.toString());
  }
}

Future<List<T>> fetchListPaginated<T>({
  required String url,
  required String type,
  required FlutterSecureStorage storage,
  required Repository myRepo,
  required String rootKey,
  required data,
  required T Function(Map<String, dynamic>) fromJson,
  int page = 1,
  int limit = 10,
}) async {
  String? token = await storage.read(key: MyConstants.token);

  final paginatedUrl = "$url?page=$page&limit=$limit";

  final response;

  final payload = data == null
      ? <String, dynamic>{}
      : Map<String, dynamic>.from(data as Map);

  if (type == 'post')
    response = await myRepo.postApiWithToken(payload, paginatedUrl, token!);
  else
    response = await myRepo.getApiWithToken(paginatedUrl, token);

  if (response == null) throw Exception("No response from server");

  final jsonData = jsonDecode(response);
  if (!jsonData['success']) throw Exception("Failed to load data");

  final List<dynamic> rawList = jsonData[rootKey];
  return rawList.map((e) => fromJson(e)).toList();
}

// For Single Model
typedef SuccessItemBuilder<T> = Widget Function(T data);

class ApiSingleStateWrapper<T> extends StatelessWidget {
  final Rx<ApisSates> state;
  final Rxn<T> data;
  final SuccessItemBuilder<T> onSuccess;
  final String emptyMessage;
  final String errorMessage;
  final Widget? loadingWidget;

  const ApiSingleStateWrapper({
    super.key,
    required this.state,
    required this.data,
    required this.onSuccess,
    this.emptyMessage = 'No data available',
    this.errorMessage = 'Something went wrong',
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      switch (state.value) {
        case ApisSates.loading:
          return loadingWidget ??
              const Center(child: CircularProgressIndicator());
        case ApisSates.empty:
          return Center(child: Text(emptyMessage));
        case ApisSates.error:
          return Center(child: Text(errorMessage));
        case ApisSates.success:
          return onSuccess(data.value as T);
      }
    });
  }
}

Future<void> fetchSingleWithState<T>({
  required Rx<ApisSates> state,
  required Rxn<T> item,
  required Future<T> Function() apiMethod,
}) async {
  try {
    state.value = ApisSates.loading;
    final result = await apiMethod();

    if (result == null) {
      state.value = ApisSates.empty;
    } else {
      item.value = result;
      state.value = ApisSates.success;
    }
  } catch (e) {
    state.value = ApisSates.error;
    SnackBarUtils.showError(e.toString());
  }
}

Future<T> fetchItem<T>({
  required String url,
  required FlutterSecureStorage storage,
  required Repository myRepo,
  required String rootKey,
  required T Function(Map<String, dynamic>) fromJson,
}) async {
  final token = await storage.read(key: MyConstants.token);
  final response = await myRepo.getApiWithToken(url, token);

  if (kDebugMode) {
    print(url);
    print("Root Key: $rootKey");
    print(token);
    print(response);
  }

  if (response == null) throw Exception("No response from server");

  final jsonData = jsonDecode(response);
  if (!jsonData['success']) throw Exception("Failed to load data");

  final Map<String, dynamic> rawItem = jsonData[rootKey];
  return fromJson(rawItem);
}
