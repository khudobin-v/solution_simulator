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
