class SimulationRequest {
  final int gridSize;
  final int steps;
  final int seed;
  final String geometry;
  final double temperature;
  final double baseTemperature;
  final double baseRate;
  final double temperatureCoefficient;
  final double diffusionRate;
  final int poreCount;
  final bool runToCompletion;

  const SimulationRequest({
    this.gridSize = 80,
    this.steps = 250,
    this.geometry = 'circle',
    this.temperature = 310.0,
    this.baseTemperature = 300.0,
    this.baseRate = 0.08,
    this.temperatureCoefficient = 0.04,
    this.diffusionRate = 0.15,
    this.seed = 42,
    this.poreCount = 5,
    this.runToCompletion = false,
  });

  Map<String, dynamic> toJson() => {
        'grid_size': gridSize,
        'steps': steps,
        'geometry': geometry,
        'temperature': temperature,
        'base_temperature': baseTemperature,
        'base_rate': baseRate,
        'temperature_coefficient': temperatureCoefficient,
        'diffusion_rate': diffusionRate,
        'seed': seed,
        'pore_count': poreCount,
        'run_to_completion': runToCompletion,
      };
}

class StepData {
  final int step;
  final int solidCells;
  final double relativeMass;
  final double meanConcentration;

  StepData.fromJson(Map<String, dynamic> j)
      : step = j['step'] as int,
        solidCells = j['solid_cells'] as int,
        relativeMass = (j['relative_mass'] as num).toDouble(),
        meanConcentration = (j['mean_concentration'] as num).toDouble();
}

class FrameData {
  final int step;
  final List<List<int>> grid;
  final List<List<double>> conc;

  FrameData.fromJson(Map<String, dynamic> j)
      : step = j['step'] as int,
        grid = (j['grid'] as List)
            .map((r) => (r as List).cast<int>())
            .toList(),
        conc = (j['conc'] as List)
            .map((r) => (r as List).map((v) => (v as num).toDouble()).toList())
            .toList();
}

class SimulationResult {
  final int initialSolidCells;
  final int finalSolidCells;
  final int dissolutionStep;
  final List<StepData> series;
  final List<FrameData> frames;

  SimulationResult.fromJson(Map<String, dynamic> j)
      : initialSolidCells = j['initial_solid_cells'] as int,
        finalSolidCells = j['final_solid_cells'] as int,
        dissolutionStep = j['dissolution_step'] as int,
        series = (j['series'] as List)
            .map((e) => StepData.fromJson(e as Map<String, dynamic>))
            .toList(),
        frames = (j['frames'] as List)
            .map((e) => FrameData.fromJson(e as Map<String, dynamic>))
            .toList();
}

// ── Auth ──────────────────────────────────────────────────────────────────────

class AuthResponse {
  final String accessToken;
  final String username;
  final int userId;

  AuthResponse.fromJson(Map<String, dynamic> j)
      : accessToken = j['access_token'] as String,
        username    = j['username'] as String,
        userId      = j['user_id'] as int;
}

// ── Saved results ─────────────────────────────────────────────────────────────

class SaveResultRequest {
  final String name;
  final String geometry;
  final int gridSize;
  final int steps;
  final double temperature;
  final double baseRate;
  final double diffusionRate;
  final int seed;
  final int poreCount;
  final int initialSolidCells;
  final int finalSolidCells;
  final int dissolutionStep;
  final double dissolvedPercent;

  const SaveResultRequest({
    required this.name,
    required this.geometry,
    required this.gridSize,
    required this.steps,
    required this.temperature,
    required this.baseRate,
    required this.diffusionRate,
    required this.seed,
    required this.poreCount,
    required this.initialSolidCells,
    required this.finalSolidCells,
    required this.dissolutionStep,
    required this.dissolvedPercent,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'geometry': geometry,
        'grid_size': gridSize,
        'steps': steps,
        'temperature': temperature,
        'base_rate': baseRate,
        'diffusion_rate': diffusionRate,
        'seed': seed,
        'pore_count': poreCount,
        'initial_solid_cells': initialSolidCells,
        'final_solid_cells': finalSolidCells,
        'dissolution_step': dissolutionStep,
        'dissolved_percent': dissolvedPercent,
      };
}

class SavedResult {
  final int id;
  final String name;
  final String geometry;
  final int gridSize;
  final int steps;
  final double temperature;
  final double baseRate;
  final double diffusionRate;
  final int seed;
  final int poreCount;
  final int initialSolidCells;
  final int finalSolidCells;
  final int dissolutionStep;
  final double dissolvedPercent;
  final String createdAt;

  SavedResult.fromJson(Map<String, dynamic> j)
      : id                 = j['id'] as int,
        name               = j['name'] as String,
        geometry           = j['geometry'] as String,
        gridSize           = j['grid_size'] as int,
        steps              = j['steps'] as int,
        temperature        = (j['temperature'] as num).toDouble(),
        baseRate           = (j['base_rate'] as num).toDouble(),
        diffusionRate      = (j['diffusion_rate'] as num).toDouble(),
        seed               = j['seed'] as int,
        poreCount          = j['pore_count'] as int,
        initialSolidCells  = j['initial_solid_cells'] as int,
        finalSolidCells    = j['final_solid_cells'] as int,
        dissolutionStep    = j['dissolution_step'] as int,
        dissolvedPercent   = (j['dissolved_percent'] as num).toDouble(),
        createdAt          = j['created_at'] as String;
}
