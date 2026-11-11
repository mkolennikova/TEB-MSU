# Тест `upstream_cons_test`: control-линия (`-DTEB_UPSTREAM_CONS`) ↔ официальный TEB 4.0.0

Тест разворачивает самодостаточный стенд в заданной директории и сравнивает
**отклики** двух моделей на включение/выключение отдельных блоков городской
среды на форсинге CAPITOUL.

* `teb_msu_ctrl` — control-линия репозитория (`src_ctrl`), собранная с
  `-DTEB_UPSTREAM_CONS`;
* `teb_orig_2020` — официальный TEB 4.0.0 (`github.com/TEB-model/teb`, тег
  `4.0.0`, коммит `fb11cad0ae3a1bdb9b676924b5f7f3dc1d6d0343`).

Что именно переключает `TEB_UPSTREAM_CONS` (приводит control-линию к поведению
официального 4.0.0):

| файл | что меняется |
| --- | --- |
| `src_driver/call_driver.F90:1088` | положение солнца на старте: `XTSTEP_SURF = dt` и дополнительный `SUNPOS` на `ZTIME - dt` |
| `src_teb/bem.F90:216,403` | порог естественной вентиляции `XNATVENT_THRESH = 1.0` вместо `0.5` |
| `src_teb/ini_csts.F90:125` | `XSTEFAN` из фундаментальных констант вместо `5.6697E-8` |
| `src_teb/ini_csts.F90:139` | `XRD/XRV/XCPD` из `XAVOGADRO*XBOLTZ/XM…` вместо округлённых литералов |
| `src_driver/call_driver.F90`, `src_teb/urban_drag.F90` | D7: старые ветровой профиль `2H/3` и аэродинамическая поправка `+XZD_TOWN` вместо согласованного `H−XZD_TOWN` |

При стандартном `urb_zd_town='H/3'` ветвь D7 воспроизводит исходные формулы.
С другим `zd` она сохраняет прежнее поведение `src_ctrl`, тогда как официальный
TEB 4.0.0 не имел такого параметра. Обычная сборка `src_ctrl` использует
`H−XZD_TOWN` в обеих формулах.

## Файлы

| файл | назначение |
| --- | --- |
| `common.py` | пути, строчный патч неймлистов, запуск драйверов, генерация начального состояния 2020 из cold start control-линии, чтение выходов, метрика (только stdlib) |
| `cases.py` | набор кейсов: `C0_control` + `D1…D5` |
| `deploy.py` | развёртывание стенда в `--target`: клон 2020, копии control-дерева/форсинга/шаблонов, сборка |
| `sensitivity.py` | прогон и метрика: `prepare → run → compare → report` |

Код 2020-модели в репозитории **не хранится**: `deploy.py` клонирует её из
собственного git-репозитория в целевую директорию и проверяет ревизию.

## Развёртывание

```powershell
python python_tests/upstream_cons_test/deploy.py --target D:\teb_bench --build
```

Опции: `--exe-ctrl` / `--exe-2020` (готовые экзешники вместо сборки),
`--teb2020-src PATH` (копия существующего checkout вместо клона),
`--teb2020-url` / `--teb2020-tag` / `--teb2020-rev`, `--strip-git`,
`--toolchain-dir DIR` (каталог с `gfortran`/`make`/`cmake`, например
`C:/msys64/ucrt64/bin`), `--runtime-dir DIR`, `--generator`, `--jobs`, `--force`,
`--dry-run`.

Что появляется в `--target`:

```
config/provenance.json      ревизии, sha256 входов и экзешников, версии инструментов
config/templates/           шаблоны неймлистов обеих моделей
data/capitoul/input/        форсинг CAPITOUL репозитория (11 файлов, 18000 шагов)
src/teb_msu_ctrl/src_ctrl/  копия control-дерева
src/teb_orig_2020/          клон TEB 4.0.0 (тег 4.0.0)
tools/                      common.py, cases.py, deploy.py, sensitivity.py
build/, cases/, report/     экзешник control, каталоги прогонов, отчёты
README.md, run.ps1          описание и запуск одной командой
```

Сборка: control-дерево — `make … CPPDEFS=-DTEB_UPSTREAM_CONS` (Makefile сам
добавляет `-static-libgfortran` и обход дефекта UCRT `setlocale`); 2020-модель —
`cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_FLAGS_RELEASE="-O0 -g"
-DUSE_REAL8=ON` + `cmake --build`.

## Прогон

```powershell
python tools/sensitivity.py --target <target> --stage all
```

Стадии: `prepare` (неймлисты кейсов), `run` (обе модели на каждый кейс),
`compare` (`report/sensitivity/summary.csv`), `report`
(`report/sensitivity/SUMMARY.md`, `report/logs/sensitivity.md`).
`--smoke N` ограничивает прогон первыми `N` шагами форсинга, `--cases …`
выбирает кейсы, `--runtime-dir DIR` задаёт каталог с DLL рантайма gfortran.

## Набор кейсов

| кейс | блок | control (`&tebparam`) | 2020 (`&parameters`) |
| --- | --- | --- | --- |
| `C0_control` | — | сценарий родного неймлиста CAPITOUL: сад 0.11, кровля 0.3, `teb_frac_gz=0.1`, natvent `'NONE'`, `teb_cap_sys_rat=100/7`, `teb_ti_bld_init=292.15`, `teb_dt_res/off=3`, `urb_emis_*` вместо legacy `urb_alb_*_th` | pristine-неймлист + `XTSTEP_SURF=300`, `HZ0H='MASC95'`, `CCH_BEM=' '`; начальное состояние — cold start control-линии (якорь 292.15 K) |
| `D1_garden_off` | сад | `teb_lgarden=.FALSE.`, `fr_garden=0.0` | `LGARDEN=.FALSE.`, `ZGARDEN=0.0` |
| `D2_greenroof_off` | зелёная кровля | `teb_lgreenroof=.FALSE.`, `teb_frac_gr=0.0` | `LGREENROOF=.FALSE.`, `ZFRAC_GR=0.0` |
| `D3_solar_on` | солнечные панели | `teb_lsolar_panel=.TRUE.`, `teb_fr_panel=0.5` | `LSOLAR_PANEL=.TRUE.`, `ZFRAC_PANEL=0.5` |
| `D4_shading_on` | затенение окон | `teb_lshade=.TRUE.` | `LSHADE=.TRUE.`, `ZSHADE=1.` |
| `D5_no_bem` | BEM (выключение) | `teb_itype_bem='DEF'`, `teb_frac_gz=0.0` | `CBEM="DEF"`, `ZGR=0.0` |

`D1…D5` наследуют неймлисты `C0_control`, поэтому на 2020-стороне сохраняются
pristine-сценарий и начальное состояние; отличие — только переключатель блока.
Доля остекления входит в переключатель `D5`: **оба** драйвера останавливаются с
сообщением `Building Energy Module (BEM) is not activated but a non-zero glazing
ratio is given` (`call_driver.F90:1063`), если при выключенном BEM оставить
`ZGR ≠ 0`.

## Метрика

Для каждого кейса и переменной сравниваются отклики, а не абсолютные поля:

```
d_ctrl   = ctrl(case)     - ctrl(C0_control)
d_2020   = upstream(case) - upstream(C0_control)
residual = d_2020 - d_ctrl
signal   = max(|d_ctrl|, |d_2020|)
rel      = max|residual| / signal
```

Вердикты: `identical` (`rel ≤ 1e-3`), `close` (`rel ≤ 1e-2`), `different`
(иначе), `inactive` (сигнал не превышает базовый остаток `base_residual` —
шум модели↔модели в `C0_control`), `no-output` (2020-драйвер не пишет файл
переменной в данной конфигурации: `HVAC_*` при выключенном BEM,
`PHOT/THER_PROD_PANEL` при выключенных панелях).

Идеал — `identical`: блок подключён одинаково; `different` означает расхождение
подключения блока (или отображения ключей неймлиста).

## Эталонный результат

Полный год (17999 строк), стенд, из которого перенесён тест:

| кейс | identical | close | different | inactive | no-output |
| --- | ---: | ---: | ---: | ---: | ---: |
| `D1_garden_off` | 13 | 0 | **0** | 2 | 0 |
| `D2_greenroof_off` | 12 | 1 | **0** | 2 | 0 |
| `D3_solar_on` | 13 | 0 | **0** | 2 | 0 |
| `D4_shading_on` | 11 | 2 | **0** | 2 | 0 |
| `D5_no_bem` | 11 | 0 | **0** | 2 | 2 |

Итого 60 `identical`, 3 `close` (максимум `rel = 1.72e-3`: `D4/H_TOWN`, строка
16462), **0 `different`**. `inactive` — `P_CANYON` и `U_CANYON` (переключатели
на них не влияют). При повторном прогоне в новой сборке вердикты должны
совпасть; абсолютные sha256 экзешников могут отличаться из-за версии
компилятора.

**Проверено на этом развёртывании**: `deploy.py --build` + `sensitivity.py
--stage all` воспроизвели эти вердикты и числа (`rel`, строки максимумов,
`base_residual`) — 12 прогонов по 17999 строк, 0 nonfinite.

Найденная особенность диагностики: при выключенном BEM control-драйвер печатает
нефизические `HVAC_COOL`/`HVAC_HEAT` (до 2.9e25) вместо нулей, тогда как
2020-драйвер пишет пустой файл. На вердикты остальных переменных не влияет.

## Требования

* Python ≥ 3.10 (только стандартная библиотека);
* `git` (клон 2020-модели), `gfortran`, `make`, `cmake` + `ninja` (или `make`)
  — для `--build`; при отсутствии в `PATH` укажите `--toolchain-dir`;
* рантайм gfortran: если драйвер завершается с `rc=0xC0000135`
  (STATUS_DLL_NOT_FOUND), укажите `--runtime-dir` (каталог с
  `libgfortran-5.dll`) — при развёртывании deployer сам копирует нужные DLL
  рядом с экзешниками, если нашёл рантайм.

## Ограничения

* сравнивается только CAPITOUL и только набор `C0` + `D1…D5`;
* начальное состояние 2020-стороны синтезируется из cold start control-линии
  (у 2020-модели нет cold start), поэтому первые недели содержат память
  начального состояния — метрика откликов на это не опирается;
* матрица фич `E01…E10` и spin-up в этот тест не входят.

