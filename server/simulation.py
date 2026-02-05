import numpy as np
from scipy.ndimage import binary_dilation

SOLID, SEMI, LIQUID = 0, 1, 2
DIRS = [(-1, 0), (1, 0), (0, -1), (0, 1)]
_NEUMANN = np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]], dtype=bool)


class CellularAutomaton:
    def __init__(self, grid_size, geometry, base_rate,
                 temperature, base_temperature,
                 temperature_coefficient, diffusion_rate, seed,
                 pore_count=5):
        self.size = grid_size
        self.base_rate = base_rate
        self.T = temperature
        self.T0 = base_temperature
        self.alpha = temperature_coefficient
        self.D = diffusion_rate
        self.pore_count = pore_count
        self.rng = np.random.default_rng(seed)

        N = grid_size
        self.grid = np.full((N, N), LIQUID, dtype=np.int8)
        self.conc = np.zeros((N, N), dtype=np.float32)
        self._init_geometry(geometry)

    def _init_geometry(self, geometry: str) -> None:
        N = self.size
        cx, cy, r = N // 2, N // 2, N // 4
        if geometry == "circle":
            ys, xs = np.ogrid[:N, :N]
            self.grid[(ys - cx) ** 2 + (xs - cy) ** 2 <= r ** 2] = SOLID
        elif geometry == "square":
            self.grid[cx - r:cx + r, cy - r:cy + r] = SOLID
        elif geometry == "porous":
            self.grid[cx - r:cx + r, cy - r:cy + r] = SOLID
            pr_min = max(1, r // 7)
            pr_max = max(pr_min + 1, r // 3)
            margin = max(1, r // 4)
            ys, xs = np.ogrid[:N, :N]
            for _ in range(self.pore_count):
                pi = int(self.rng.integers(cx - r + margin, cx + r - margin))
                pj = int(self.rng.integers(cy - r + margin, cy + r - margin))
                pr = int(self.rng.integers(pr_min, pr_max + 1))
                self.grid[(ys - pi) ** 2 + (xs - pj) ** 2 <= pr ** 2] = LIQUID

    def _k(self) -> float:
        return self.base_rate * float(np.exp(self.alpha * (self.T - self.T0)))

    def step(self) -> None:
        N = self.size
        new_grid = self.grid.copy()
        new_conc = self.conc.copy()
        k = self._k()

        # ── Phase 1: SEMI → LIQUID (cells that started dissolving last step) ──
        # These were marked SEMI in the previous call; they now fully enter solution.
        semi_mask = self.grid == SEMI
        if np.any(semi_mask):
            semi_ys, semi_xs = np.where(semi_mask)
            for i, j in zip(semi_ys.tolist(), semi_xs.tolist()):
                new_grid[i, j] = LIQUID
                for di, dj in DIRS:
                    ni, nj = i + di, j + dj
                    if 0 <= ni < N and 0 <= nj < N:
                        new_conc[ni, nj] = min(1.0, new_conc[ni, nj] + 0.1)

        # ── Phase 2: boundary SOLID → SEMI (newly deciding to dissolve) ──
        # Use the UPDATED new_grid so freshly-liquidised cells count as neighbours.
        solid_mask  = new_grid == SOLID
        liquid_mask = new_grid == LIQUID
        boundary = solid_mask & binary_dilation(liquid_mask, structure=_NEUMANN)

        solid_ys, solid_xs = np.where(boundary)
        for i, j in zip(solid_ys.tolist(), solid_xs.tolist()):
            liq_nb = [
                (i + di, j + dj) for di, dj in DIRS
                if 0 <= i + di < N and 0 <= j + dj < N
                and new_grid[i + di, j + dj] == LIQUID
            ]
            if not liq_nb:
                continue
            c_local = float(np.mean([self.conc[ni, nj] for ni, nj in liq_nb]))
            if self.rng.random() < min(k * (1.0 - c_local), 1.0):
                new_grid[i, j] = SEMI   # stays SEMI until the NEXT step

        # ── Phase 3: diffuse concentration among liquid cells ──
        liq_ys, liq_xs = np.where(new_grid == LIQUID)
        for i, j in zip(liq_ys.tolist(), liq_xs.tolist()):
            nb = [
                (i + di, j + dj) for di, dj in DIRS
                if 0 <= i + di < N and 0 <= j + dj < N
                and new_grid[i + di, j + dj] == LIQUID
            ]
            if nb:
                avg = float(np.mean([new_conc[ni, nj] for ni, nj in nb]))
                new_conc[i, j] += self.D * (avg - new_conc[i, j])

        self.grid = new_grid
        self.conc = np.clip(new_conc, 0.0, 1.0)

    def solid_count(self) -> int:
        """Number of fully-solid cells (SEMI not counted — they are dissolving)."""
        return int(np.sum(self.grid == SOLID))

    def semi_count(self) -> int:
        return int(np.sum(self.grid == SEMI))

    def mean_concentration(self) -> float:
        mask = self.grid == LIQUID
        return float(np.mean(self.conc[mask])) if np.any(mask) else 0.0
