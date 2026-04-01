from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from models import SimulationRequest, SimulationResponse, StepData, FrameData
from simulation import CellularAutomaton

app = FastAPI(title="Dissolution Simulation API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

FRAME_INTERVAL = 10


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.post("/api/simulations", response_model=SimulationResponse)
def run_simulation(req: SimulationRequest):
    ca = CellularAutomaton(
        grid_size=req.grid_size,
        geometry=req.geometry,
        base_rate=req.base_rate,
        temperature=req.temperature,
        base_temperature=req.base_temperature,
        temperature_coefficient=req.temperature_coefficient,
        diffusion_rate=req.diffusion_rate,
        seed=req.seed,
        pore_count=req.pore_count,
    )

    initial = ca.solid_count()
    if initial == 0:
        raise HTTPException(status_code=400, detail="Empty grid for given geometry")

    series: list[StepData] = []
    frames: list[FrameData] = []
    dissolution_step: int | None = None
    # In auto mode use a generous cap; manual mode uses req.steps exactly
    max_steps = req.steps

    t = 0
    while True:
        sc = ca.solid_count()
        rm = round(sc / initial, 4)
        mc = round(ca.mean_concentration(), 4)
        series.append(StepData(step=t, solid_cells=sc, relative_mass=rm, mean_concentration=mc))

        save_frame = (t % FRAME_INTERVAL == 0)

        # Fully dissolved = no SOLID and no SEMI remaining
        fully_done = (sc == 0 and ca.semi_count() == 0)
        if fully_done and dissolution_step is None:
            dissolution_step = t
            save_frame = True  # always capture the fully-dissolved state

        if save_frame:
            frames.append(FrameData(
                step=t,
                grid=ca.grid.tolist(),
                conc=[[round(float(v), 3) for v in row] for row in ca.conc.tolist()],
            ))

        if dissolution_step is not None and req.run_to_completion:
            break  # stop right after saving the final frame

        if t >= max_steps:
            break

        ca.step()
        t += 1

    if dissolution_step is None:
        dissolution_step = max_steps  # never fully dissolved within limit

    return SimulationResponse(
        initial_solid_cells=initial,
        final_solid_cells=ca.solid_count(),
        dissolution_step=dissolution_step,
        series=series,
        frames=frames,
    )
