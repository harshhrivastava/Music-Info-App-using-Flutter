import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:spotify_clone/constants/urls.dart';

class SpotifyService {
  final Dio dio;
  String? accessToken;

  SpotifyService({
    required this.dio,
  }) {
    dio.interceptors.add(
      LogInterceptor(
        request: true,
        error: true,
        requestHeader: true,
        responseHeader: true,
        requestBody: true,
        responseBody: true,
        logPrint: (Object object) {
          debugPrint(object.toString());
        },
      )
    );
  }

  Future<bool> fetchAccessToken() async {
    try {
      await dotenv.load(fileName: "lib/.env");
      final String clientId = dotenv.env['CLIENT_ID']!;
      final String clientSecret = dotenv.env['CLIENT_SECRET']!;
      final response = await dio.post(
        accessTokenUrl,
        data: {
          "grant_type": "client_credentials",
          "client_id": clientId,
          "client_secret": clientSecret,
        },
        options: Options(
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
        ),
      );
      accessToken = response.data["access_token"];
      dio.interceptors.add(
          InterceptorsWrapper(
              onRequest: (options, handler) {
                options.headers["Authorization"] = "Bearer $accessToken";
                handler.next(options);
              }
          )
      );
      return true;
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
    return false;
  }

  Future<Map<String, dynamic>> search(String query) async {
    Map<String, dynamic> results = <String, dynamic>{"response": null, "error": null};
    try {
      final response = await dio.get(
        searchUrl,
        queryParameters: {
          "q": query,
          "type": "artist,album,track",
          "limit": 5,
        },
      );
      results.update("response", (value) => response.data);
    } on DioException catch(e) {
      debugPrint(e.toString());
      if(e.response?.statusCode == 401) {
        final bool status = await fetchAccessToken();
        if(status) {
          return await search(query);
        }
      } else {
        results.update("error", (value) => e.toString());
      }
    } on Exception catch(e) {
      debugPrint(e.toString());
      results.update("error", (value) => e.toString());
    }
    return results;
  }

  Future<Map<String, dynamic>> fetchData(String type, String id, String? request) async {
    Map<String, dynamic> results = <String, dynamic>{"response": null, "error": null};
    try {
      final url = buildUrl(type, id, request);
      final response = await dio.get(
        url,
        queryParameters: (request == "top-tracks" || request == "tracks") ? {
          "market": "IN",
        } : null,
      );
      results.update("response", (value) => response.data);
    } on DioException catch(e) {
      debugPrint(e.toString());
      if(e.response?.statusCode == 401) {
        final bool status = await fetchAccessToken();
        if(status) {
          return await fetchData(type, id, request);
        }
      } else {
        results.update("error", (value) => e.toString());
      }
    } on Exception catch(e) {
      debugPrint(e.toString());
      results.update("error", (value) => e.toString());
    }
    return results;
  }
}