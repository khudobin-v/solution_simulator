from pydantic import BaseModel, Field
from typing import List, Literal


class SimulationRequest(BaseModel):
    grid_size: int = Field(default=80, ge=10, le=200)
    steps: int = Field(default=250, ge=1, le=2000)
    geometry: Literal["circle", "square", "porous"] = "circle"
    temperature: float = Field(default=310.0)
    base_temperature: float = Field(default=300.0)
    base_rate: float = Field(default=0.08, ge=0.0, le=1.0)
    temperature_coefficient: float = Field(default=0.04)
    diffusion_rate: float = Field(default=0.15, ge=0.0, le=1.0)
    seed: int = Field(default=42)
    pore_count: int = Field(default=5, ge=1, le=30)
    # When True: stop as soon as solid_count == 0 (or steps limit reached)
    run_to_completion: bool = Field(default=False)


class StepData(BaseModel):
    step: int
    solid_cells: int
    relative_mass: float
    mean_concentration: float


class FrameData(BaseModel):
    step: int
    grid: List[List[int]]
    conc: List[List[float]]


class SimulationResponse(BaseModel):
    initial_solid_cells: int
    final_solid_cells: int
    dissolution_step: int
    series: List[StepData]
    frames: List[FrameData]
