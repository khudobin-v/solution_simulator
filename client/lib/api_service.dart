import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  final String baseUrl;

  const ApiService({this.baseUrl = 'https://program-kappa-five.vercel.app'});

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<AuthResponse> register(String username, String password) async {
    return _authPost('/api/auth/register', {'username': username, 'password': password});
  }

  Future<AuthResponse> login(String username, String password) async {
    return _authPost('/api/auth/login', {'username': username, 'password': password});
  }

  Future<AuthResponse> _authPost(String path, Map<String, dynamic> body) async {
    final resp = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return AuthResponse.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    }
    final detail = (jsonDecode(resp.body) as Map?)?['detail'] ?? resp.statusCode;
    throw Exception('$detail');
  }

  // ── Simulation ─────────────────────────────────────────────────────────────

  Future<SimulationResult> runSimulation(SimulationRequest req) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/api/simulations'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(req.toJson()),
        );

    if (resp.statusCode == 200) {
      return SimulationResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    final detail = (jsonDecode(resp.body) as Map?)?['detail'] ?? resp.statusCode;
    throw Exception('Server error: $detail');
  }

  // ── Saved results ──────────────────────────────────────────────────────────

  Future<void> saveResult(String token, SaveResultRequest req) async {
    final resp = await http
        .post(Uri.parse('$baseUrl/api/results'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(req.toJson()))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 201) {
      final detail = (jsonDecode(resp.body) as Map?)?['detail'] ?? resp.statusCode;
      throw Exception('$detail');
    }
  }

  Future<List<SavedResult>> getResults(String token) async {
    final resp = await http
        .get(Uri.parse('$baseUrl/api/results'),
            headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      return (jsonDecode(resp.body) as List)
          .map((e) => SavedResult.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load results');
  }

  Future<void> deleteResult(String token, int id) async {
    await http
        .delete(Uri.parse('$baseUrl/api/results/$id'),
            headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 10));
  }
}
