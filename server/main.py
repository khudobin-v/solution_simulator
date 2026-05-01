from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

from auth import (
    hash_password, verify_password, create_token, get_current_user,
)
from database import (
    init_db,
    create_user, get_user_by_username,
    save_result, get_user_results, delete_result,
)
from models import (
    SimulationRequest, SimulationResponse, StepData, FrameData,
    RegisterRequest, LoginRequest, TokenResponse,
    SaveResultRequest, SavedResult,
)
from simulation import CellularAutomaton

app = FastAPI(title="Dissolution Simulation API", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

FRAME_INTERVAL = 10


@app.on_event("startup")
def startup() -> None:
    init_db()


# ── Health ────────────────────────────────────────────────────────────────────

@app.get("/api/health")
def health():
    return {"status": "ok"}


# ── Auth ──────────────────────────────────────────────────────────────────────

@app.post("/api/auth/register", response_model=TokenResponse)
def register(req: RegisterRequest):
    if get_user_by_username(req.username):
        raise HTTPException(400, detail="Имя пользователя уже занято")
    uid = create_user(req.username, hash_password(req.password))
    return TokenResponse(
        access_token=create_token(uid, req.username),
        username=req.username,
        user_id=uid,
    )


@app.post("/api/auth/login", response_model=TokenResponse)
def login(req: LoginRequest):
    user = get_user_by_username(req.username)
    if not user or not verify_password(req.password, user["password_hash"]):
        raise HTTPException(401, detail="Неверный логин или пароль")
    return TokenResponse(
        access_token=create_token(user["id"], user["username"]),
        username=user["username"],
        user_id=user["id"],
    )


@app.get("/api/auth/me")
def me(current_user: dict = Depends(get_current_user)):
    return {"id": current_user["id"], "username": current_user["username"]}


# ── Simulation ────────────────────────────────────────────────────────────────

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
    max_steps = req.steps

    t = 0
    while True:
        sc = ca.solid_count()
        rm = round(sc / initial, 4)
        mc = round(ca.mean_concentration(), 4)
        series.append(StepData(step=t, solid_cells=sc, relative_mass=rm, mean_concentration=mc))

        save_frame = (t % FRAME_INTERVAL == 0)
        fully_done = (sc == 0 and ca.semi_count() == 0)
        if fully_done and dissolution_step is None:
            dissolution_step = t
            save_frame = True

        if save_frame:
            frames.append(FrameData(
                step=t,
                grid=ca.grid.tolist(),
                conc=[[round(float(v), 3) for v in row] for row in ca.conc.tolist()],
            ))

        if dissolution_step is not None and req.run_to_completion:
            break
        if t >= max_steps:
            break

        ca.step()
        t += 1

    if dissolution_step is None:
        dissolution_step = max_steps

    return SimulationResponse(
        initial_solid_cells=initial,
        final_solid_cells=ca.solid_count(),
        dissolution_step=dissolution_step,
        series=series,
        frames=frames,
    )


# ── Saved results ─────────────────────────────────────────────────────────────

@app.post("/api/results", status_code=201)
def create_result(
    req: SaveResultRequest,
    current_user: dict = Depends(get_current_user),
):
    rid = save_result(
        user_id=current_user["id"],
        name=req.name,
        params={
            "geometry": req.geometry, "grid_size": req.grid_size,
            "steps": req.steps, "temperature": req.temperature,
            "base_rate": req.base_rate, "diffusion_rate": req.diffusion_rate,
            "seed": req.seed, "pore_count": req.pore_count,
        },
        stats={
            "initial_solid_cells": req.initial_solid_cells,
            "final_solid_cells": req.final_solid_cells,
            "dissolution_step": req.dissolution_step,
            "dissolved_percent": req.dissolved_percent,
        },
    )
    return {"id": rid}


@app.get("/api/results", response_model=list[SavedResult])
def list_results(current_user: dict = Depends(get_current_user)):
    return get_user_results(current_user["id"])


@app.delete("/api/results/{result_id}")
def remove_result(
    result_id: int,
    current_user: dict = Depends(get_current_user),
):
    if not delete_result(result_id, current_user["id"]):
        raise HTTPException(404, detail="Result not found")
    return {"ok": True}
