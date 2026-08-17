# data/

Datasets used by the model experiments and the test benches are **not stored in this
repository**: they are far too large for Git (the CAPITOUL measurement data alone is
3062 files, about 2.6 GB).

They are kept outside the repository, in the working directory that
`run_on_windows.ipynb` also uses as `WORK_DIR`:

| Dataset | Location | Size |
| --- | --- | --- |
| CAPITOUL measurement campaign data: the Urban-PLUMBER site collection and the CAPITOUL datasets (`21STATIONS_TEMP`, `CARS_TROAD`, `FLUXES`, `MAST_BASIC`, `METEOSTATIONS`, `SODAR`, `SODAR2`, `SURFACE AND MOBILE METEOROLOGICAL STATIONS`, `TEMP_PROFILE_MAST`, `UHF_RADAR`) | `D:\TEB_work\CAPITOUL DATA` | ~2.6 GB, 3062 files |

The dataset had been committed to the `main` branch in July 2026 (`CAPITOUL DATA/`)
and was removed from the repository history in September 2026: every branch and
`origin/main` were rewritten without it, so the data now exists only outside Git.
Please do not commit it again.

Everything inside `data/` is ignored (see `data/.gitignore`), so local datasets copied
here are never staged by accident. A small file that does belong to the repository can
still be added explicitly:

```bash
git add -f data/<file>
```
