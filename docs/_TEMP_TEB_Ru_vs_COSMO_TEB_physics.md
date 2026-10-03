# Сравнение физики TEB-Ru (`main`) и TEB, сопряжённого с COSMO

> ⚠️ **ВРЕМЕННЫЙ ФАЙЛ.** Это рабочий черновик сравнения; он **подлежит удалению**
> после того, как находки будут перенесены в основные документы
> (`TEB_Ru_source_defects.md` / `TEB_Ru_change_history.md`) либо признаны
> неактуальными. В репозитории оставлять его не планируется.

Документ фиксирует различия в **физике** между текущим репозиторием TEB-Ru
(ветка `main`) и версией TEB, которая используется совместно с моделью атмосферы
COSMO (`D:\Work\git\COSMO-TEB\TEB_in_function_external_forcing`).

Отдельно выделены:
* блоки, **закомментированные в TEB-Ru, но активные** в сопряжённой версии;
* все места с пометкой **`! MT`**.

---

## 0. Метод

* Со стороны COSMO-TEB использован источник, восстановленный из истории git —
  состояние на коммите **`c75fa63`** («Version from 01.11.2025»). Причина: в
  текущем `HEAD` репозитория COSMO-TEB содержимое
  `TEB_in_function_external_forcing` **уничтожено** (файлы сохранены по именам и
  размерам, но заполнены NUL-байтами). Поломка внесена коммитом `2192ca0`
  («Fixed surface temperature for non-urban cells in TEB-Garden»): дерево
  сократилось с 1389 до 213 файлов, из которых 212 — нулевые. Полный, читаемый
  источник сохранён в коммите `c75fa63`.
* Со стороны TEB-Ru использован рабочий каталог worktree ветки `main`
  (`D:\Work\git\TEB-Ru-main`).
* Сравнивались каталоги физики: `src_teb`, `src_struct`, `src_proxi_SVAT`,
  `src_solar`. Файлы сравнивались построчно после нормализации переводов строк
  (CRLF → LF).
* Каталог `src_driver` (словники, ввод/вывод, цикл драйвера) не рассматривался:
  в COSMO-TEB это слой сопряжения (`sfc_teb.F90`, `call_teb_interface.F90`,
  `wind_profile_wang.F90`), а в TEB-Ru — автономный оффлайн-драйвер; прямое
  сравнение не имеет смысла.

---

## 1. Сводная таблица различий

| Файл | Тип отличия | Влияние на результат |
| --- | --- | --- |
| `src_teb/teb_garden.F90` | **физика**: снежная коррекция (`! MT`), отключение жалюзи (`! MT`), внешний garden | да (снег; жалюзи — при BEM); внешний garden — при включённом саде |
| `src_teb/urban_solar_abs.F90` | **физика**: отключение жалюзи (`! MT`) | да, при активных жалюзи/BEM |
| `src_teb/surface_ri.F90` | **физика**: ограничение числа Ричардсона `MIN(PRI,XRIMAX)` | да (коэффициенты обмена) |
| `src_teb/urban_drag.F90` | **физика**: клампа `u* ≥ 0.1`; внешний garden; мёртвый блок `sigmoida` | да (клампа `u*`); остальное — при саде / без эффекта |
| `src_proxi_SVAT/garden.F90` | **режим сопряжения**: COSMO = внешний сад (потоки/влажность извне) | только при включённом саде |
| `src_proxi_SVAT/greenroof.F90` | **режим сопряжения**: COSMO = внешняя кровля (+ реальное `PALB_GR`) | только при включённой зелёной кровле |
| `src_teb/teb.F90` | только обвязка внешнего garden/greenroof (аргументы) | нет (кроме случая внешнего сада) |
| `src_struct/teb_garden_struct.F90` | только обвязка внешнего garden/greenroof (аргументы) | нет (кроме случая внешнего сада) |
| `src_teb/bem.F90` | косметика (`.EQV.` → `==`) | нет |
| `src_teb/avg_urban_fluxes.F90` | косметика (пустая строка) | нет |
| `src_teb/urban_exch_coef.F90` | косметика (аргумент `ilmo` сделан локальным, пробелы) | нет |
| `src_teb/flxsurf3bx.F` | косметика (удалены закомментированные `print*`) | нет |
| все `modi_*` | интерфейсные модули (следуют за `.F90`) | нет |
| все `modd_*`, `mode_thermos`, бюджеты слоёв, `urban_fluxes`, `urban_hydro`, `urban_snow_evol`, `urban_lw_coef`, `snow_cover_1layer`, `solar_panel` и др. | **идентичны** | — |

**Константы и параметры идентичны** (`modd_csts.F90`, `modd_surf_par.F90`,
`modd_tebn.F90`, `modd_bemn.F90`, `modd_teb_optionn.F90` и т. д.) — расхождений в
коэффициентах нет. Ядро энергобаланса и снега/гидрологии совпадает; отличия
сосредоточены в перечисленных выше файлах.

---

## 2. Блоки `! MT`: закомментировано в TEB-Ru, активно в COSMO-TEB

### 2.1. Снежная коррекция дорожного альбедо/излучательной способности

**Файл:** `src_teb/teb_garden.F90`

**TEB-Ru (`main` / `src_ctrl` / `src_dev`) — блок ЗАКОММЕНТИРОВАН**
(`src_ctrl/src_teb/teb_garden.F90` 488–532; `src_dev/src_teb/teb_garden.F90` 602–640):

```fortran
 ! MT
 ! Claculation of snow content to exclude cases of very low snow rate
 !WSNOW_ROOF_CHECK = 0.
 !WSNOW_ROAD_CHECK = 0.
 !WHERE (T%TSNOW_ROAD%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROAD_CHECK = PTSTEP * PSR(:)
 !WHERE (T%TSNOW_ROOF%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROOF_CHECK = PTSTEP * PSR(:)
 !
 ! MT
 ! Exclude cases of very low snow rate
 !WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )
 !   T%TSNOW_ROAD%ALB (:) = XUNDEF
 !   T%TSNOW_ROAD%EMIS(:) = XUNDEF
 !   T%TSNOW_ROAD%TS  (:) = XUNDEF
 !   PDN_RD = 0.
 !   ZDF_RD = 1.
 !END WHERE
 !
 !WHERE ( WSNOW_ROOF_CHECK(:)<1.E-8 * PTSTEP )
 !   T%TSNOW_ROOF%ALB (:) = XUNDEF
 !   T%TSNOW_ROOF%EMIS(:) = XUNDEF
 !   T%TSNOW_ROOF%TS  (:) = XUNDEF
 !   PDN_RF = 0.
 !   ZDF_RF = 1.
 !END WHERE
```

**COSMO-TEB (`c75fa63`) — тот же блок АКТИВЕН**
(`src_teb/teb_garden.F90` 475–480 и 503–519):

```fortran
 ! MT
 ! Claculation of snow content to exclude cases of very low snow rate
 WSNOW_ROOF_CHECK = 0.
 WSNOW_ROAD_CHECK = 0.
 WHERE (T%TSNOW_ROAD%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROAD_CHECK = PTSTEP * PSR(:)
 WHERE (T%TSNOW_ROOF%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROOF_CHECK = PTSTEP * PSR(:)
 !
 ! MT
 ! Exclude cases of very low snow rate
 WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )
    T%TSNOW_ROAD%ALB (:) = XUNDEF
    T%TSNOW_ROAD%EMIS(:) = XUNDEF
    T%TSNOW_ROAD%TS  (:) = XUNDEF
    PDN_RD = 0.
    ZDF_RD = 1.
 END WHERE
 !
 WHERE ( WSNOW_ROOF_CHECK(:)<1.E-8 * PTSTEP )
    T%TSNOW_ROOF%ALB (:) = XUNDEF
    T%TSNOW_ROOF%EMIS(:) = XUNDEF
    T%TSNOW_ROOF%TS  (:) = XUNDEF
    PDN_RF = 0.
    ZDF_RF = 1.
 END WHERE
```

> **Блоки совпадают построчно** (закомментированный в TEB-Ru против активного в
> COSMO-TEB): это один и тот же код, поэтому включение флага `teb_snow_check`
> даёт точный паритет.

**Суть:** при очень малой величине свежего снега (`< 1e-8 · PTSTEP`) COSMO-TEB
сбрасывает дорожные `ALB`/`EMIS` в `XUNDEF`; в TEB-Ru эта коррекция отключена.
Влияет на снежное альбедо и радиационный бюджет дороги в условиях слабого снега.

> Маркеры `! MT` сохранены в обоих репозиториях (в TEB-Ru — строки ~488 и ~516,
> в COSMO-TEB — ~475 и ~503).

### 2.2. Отключение затеняющих устройств (жалюзи / солнцезащита окон)

Коррекция присутствует **в двух местах** и в COSMO-TEB активна в обоих.

#### 2.2.1. `src_teb/urban_solar_abs.F90`

**TEB-Ru (жалюзи РАБОТАЮТ):**

```fortran
 ! MT deactivation of shading devices
 G_EFF_SHAD(:) = OSHADE(:).AND.(ZDIR_SW_WL(:) + ZSCA_SW_WL(:) > XWIN_SW_MAX)
 !G_EFF_SHAD(:) = .FALSE.
 ...
 ! MT deactivation of shading devices
 OSHAD_DAY(:)  = G_EFF_SHAD(:) .OR. OSHAD_DAY(:)
 !OSHAD_DAY(:) = .FALSE.
```

**COSMO-TEB (жалюзи ВЫКЛЮЧЕНЫ принудительно):**

```fortran
 ! MT deactivation of shading devices
 !G_EFF_SHAD(:) = OSHADE(:).AND.(ZDIR_SW_WL(:) + ZSCA_SW_WL(:) > XWIN_SW_MAX)
 G_EFF_SHAD(:) = .FALSE.
 ...
 ! MT deactivation of shading devices
 !OSHAD_DAY(:)  = G_EFF_SHAD(:) .OR. OSHAD_DAY(:)
 OSHAD_DAY(:) = .FALSE.
```

#### 2.2.2. `src_teb/teb_garden.F90`

**TEB-Ru (жалюзи РАБОТАЮТ):**

```fortran
 ! MT deactivation of shading devices
 !GSHADE(:) = .FALSE.
```

**COSMO-TEB (жалюзи ВЫКЛЮЧЕНЫ):**

```fortran
 ! MT deactivation of shading devices
 GSHADE(:) = .FALSE.
```

**Суть и совместимость.** В COSMO-TEB затеняющие устройства принудительно
отключены *в дополнение* к тому, что `LSHADE` там жёстко равен `.FALSE.`
(`call_driver.F90:989`). В TEB-Ru `B%LSHADE` — это ключ неймлиста `teb_lshade`
(дефолт `.FALSE.`), и при `teb_lshade = .FALSE.`:
`WINDOW_SHADING_AVAILABILITY` возвращает `.FALSE.` → `GSHADE = .FALSE.` →
`G_EFF_SHAD = .FALSE.`, т.е. **поведение совпадает с COSMO-TEB** (принудительный
`.FALSE.` становится no-op).

Вывод: **новый переключатель не нужен** — паритет достигается существующим
ключом `teb_lshade = .FALSE.`; а `teb_lshade = .TRUE.` даёт поведение TEB-Ru
(жалюзи работают). Различие в коде проявляется только при `teb_lshade = .TRUE.`;
при желании строгого паритета и в этом случае — опциональный
`teb_shade_force_off` (в план не включён).

### 2.3. Общий `! MT` без различий

**Файл:** `src_teb/urban_snow_evol.F90`, строка ~281 — совпадает в обоих
репозиториях, различия нет:

```fortran
 WHERE (T%TSNOW_ROAD%T(:,1) .EQ. XUNDEF) PDN_RD(:) = 0.0
 ! MT
 !WHERE (T%TSNOW_ROOF%T(:,1) .EQ. XUNDEF) PDN_RF(:) = 0.0
```

---

## 3. Прочие различия физики (активно в TEB-Ru, убрано в COSMO-TEB)

### 3.1. Ограничение числа Ричардсона — `src_teb/surface_ri.F90`

**TEB-Ru (активно):**

```fortran
 PRI(:) = MIN(PRI(:),XRIMAX)
```

**COSMO-TEB:** строки нет (ограничение отсутствует).

**Суть:** TEB-Ru ограничивает число Ричардсона сверху значением `XRIMAX`. Так как
`PRI` используется в функциях устойчивости → коэффициентах обмена, различие
проявляется в сильно устойчивых/неустойчивых условиях.

### 3.2. Нижний предел `u*` и мёртвый код — `src_teb/urban_drag.F90`

**TEB-Ru (активно):**

```fortran
 PUSTAR_TOWN(JJ) = SQRT(ZUSTAR2(JJ))
 PUSTAR_TOWN(JJ) = MAX(PUSTAR_TOWN(JJ), 0.1)
```

**COSMO-TEB:** строки `MAX(PUSTAR_TOWN, 0.1)` нет.

**Суть:** в TEB-Ru скорость трения города снизу ограничена `0.1 м/с`; в COSMO-TEB —
нет.

Дополнительно в TEB-Ru присутствует блок «Increase PCH_TOP according to U*» с
функцией `sigmoida`, но собственно строки применения
(`PCH_TOP = PCH_TOP * k_ustar`, `PAC_TOP = PAC_TOP * k_ustar`) закомментированы —
**блок не влияет на результат** (в COSMO-TEB удалён целиком).

### 3.3. Прокси-сад / зелёная кровля — `src_proxi_SVAT/`

**`garden.F90`:**

| | TEB-Ru | COSMO-TEB |
| --- | --- | --- |
| тепло/влагa | `PRN=(1-0.15)*PSW`, `PH=0.2·RN`, `PLE=0.8·RN`, `PEVAP=PLE/XLVTT` | эти строки **закомментированы** |
| связь с каньоном | `PAC_AGG=0`, `PHU_AGG=0.8` | `PAC_AGG=PAC_GARDEN`, `PHU_AGG=PQV_GD/PQSAT_GARDEN` (с `MIN/MAX`) |

В COSMO-TEB прокси-сад «связан» с влажностью каньона (добавлен вход `PQV_GD`); в
TEB-Ru используется классический прокси с фиксированной влажностью 0.8.

**`greenroof.F90`:**

| | TEB-Ru | COSMO-TEB |
| --- | --- | --- |
| альбедо | `PRN=(1-0.15)*PSW` (фикс. 0.15) | `PRN=(1-PALB_GR)*PSW` (реальное альбедо, вход `PALB_GR`) |
| потоки | `PH=0.5·RN`, `PLE=0.5·RN` активны | эти строки закомментированы |

**Область действия:** отличия проявляются только когда **включены** сад
(`OGARDEN`) / зелёная кровля (`OGREENROOF`). В стандартной конфигурации CAPITOUL
(Toulouse) обе поверхности выключены, поэтому на базовый прогон не влияют.

---

## 4. Сад / зелёная кровля: COSMO-TEB = режим «внешней модели»

Проверка кода показала, что различие по саду/кровле — **не формульное, а режим
сопряжения**: в COSMO-TEB сад и кровлю ведёт **внешняя** модель, а TEB считает
только радиационный бюджет и агрегацию.

### 4.1. Признаки режима «внешней модели» в COSMO-TEB

* `src_proxi_SVAT/garden.F90`: строки, считающие потоки (`PRN`, `PH`, `PLE`,
  `PEVAP`, `PAC`, `PRUNOFF`), **закомментированы**; остаются `PGFLUX = 0`,
  `SFCO2 = 0`, `PUW`, `PQSAT` и агрегация `PAC_AGG_GARDEN = PAC_GARDEN`,
  `PHU_AGG_GARDEN = PQV_GD/PQSAT_GARDEN` (клампа `[0.01,1]`).
* `PQV_GD` (влажность сада) — **вход от хоста**: `INTENT(INOUT)` в `TEB_GARDEN`,
  `ZQV_GD !IN garden specific humidity` в `CALL_DRIVER`.
* `PH_GD/PLE_GD` (и `PH/PLE_GREENROOF`) не присваиваются — потоки тоже извне.
* Rn сада считается в `teb_garden.F90` из бюджета поверхности:
  `(1−PALB_GD)·SW_rec + (ε·LW_rec − σ·ε·T_s⁴)`.
* `greenroof.F90`: `PRN = (1−PALB_GR)·SW` (только КВ), `PH/PLE/EVAP` не считаются,
  `PHU_AGG = 0.3`.

### 4.2. Реализация в TEB-Ru: `teb_type_garden`/`teb_type_greenroof`

В TEB-Ru эти режимы уже есть — значения `'EXT'` и `'EXT_NEU'` (в `src_dev` через
`TOP%CTYPE_GARDEN`; в `src_ctrl` — через легаси-флаги `teb_lgarden_ext` /
`teb_lgreenroof_ext` и ветку `IF (OGARDEN_EXT)`). Внешние величины подаются
аргументами `*_EXT`, а Rn считается тем же выражением:

```fortran
IF (TOP%CTYPE_GARDEN == 'EXT' .OR. TOP%CTYPE_GARDEN == 'EXT_NEU') THEN   ! src_dev
   ZH_GD(:)      = PH_GD_EXT(:)
   ZLE_GD(:)     = PLE_GD_EXT(:)
   ZEVAP_GD(:)   = PEVAP_GD_EXT(:)
   ZRUNOFF_GD(:) = PRUNOFF_GD_EXT(:)
   ZQV_GD(:)     = PQV_GD_EXT(:)
   ZHU_AGG_GD(:) = MIN(MAX(PQV_GD_EXT(:)/ZQSAT_GD(:), 0.01), 1.)
   DMT%XABS_SW_GARDEN(:) = (1.-ZALB_GD(:)) * ZREC_SW_GD
   DMT%XABS_LW_GARDEN(:) = ZEMIS_GD(:)*ZREC_LW_GD(:) - XSTEFAN*ZEMIS_GD(:)*ZTSRAD_GD(:)**4
   ZRN_GD(:) = DMT%XABS_SW_GARDEN(:) + DMT%XABS_LW_GARDEN(:)
ENDIF
```

### 4.3. Соответствие COSMO ↔ TEB-Ru (`EXT`/`EXT_NEU`)

| Элемент | COSMO-TEB | TEB-Ru `EXT`/`EXT_NEU` | Совместимость |
| --- | --- | --- | --- |
| Радиационный бюджет сада | `ABS_SW+ABS_LW` (`PALB_GD/PEMIS_GD/PTSRAD_GD`) | то же (`PALB_GD_EXT/PEMIS_GD_EXT/PTSRAD_GD_EXT`) | ✔ идентично |
| Влажностная агрегация | `clamp(PQV_GD/PQSAT, 0.01, 1)` | `clamp(PQV_GD_EXT/ZQSAT_GD, 0.01, 1)` | ✔ идентично |
| H, LE, EVAP, RUNOFF | извне | `PH_GD_EXT`, `PLE_GD_EXT`, … | ✔ |
| `PQV_GD` | вход от хоста | `PQV_GD_EXT` | ✔ |
| `PAC_AGG_GARDEN` | `= PAC_GARDEN` | остаётся `0` из прокси | ⚠ расхождение |
| Коэффициенты обмена | внутри прокси | `URBAN_DRAG` (`EXT`/`EXT_NEU`) | ⚠ разные определения |
| Кровля, Rn | `(1−PALB_GR)·SW` (только КВ) | `ABS_SW+ABS_LW` | ⚠ расхождение |
| Кровля, `PHU_AGG` | `0.3` жёстко | `urb_phu_grf` (дефолт `0.7`) | ⚠ согласовать |

**Вывод:** расхождение по саду/кровле объясняется режимом сопряжения, а не
различием формул; строгий паритет требует запуска в режиме `EXT`/`EXT_NEU` с теми
же внешними данными, что подаёт хост COSMO. Остаточные расхождения зафиксированы
для дальнейшей проработки — см. §8.

---

## 5. Отличия, отнесённые к косметике (на результат не влияют)

* `src_teb/bem.F90`: `IF (PBEM_AC .EQV. .TRUE.)` → `IF (PBEM_AC == .TRUE.)` (два
  места; логически эквивалентно).
* `src_teb/avg_urban_fluxes.F90`: удалена пустая строка.
* `src_teb/urban_exch_coef.F90`: аргумент `ilmo` (1/L Монина—Обухова) в TEB-Ru
  объявлен как `OUT`, в COSMO-TEB заменён локальной переменной; плюс выравнивание
  пробелов. На результат не влияет (в COSMO-TEB `ilmo` наружу не передаётся).
* `src_teb/flxsurf3bx.F`: в COSMO-TEB удалены закомментированные отладочные
  `!print*, 'ILMO str ...'`.
* все `modi_*.f90` — интерфейсные модули, следуют за соответствующими `.F90`.
* `src_struct/teb_garden_struct.F90` — только обвязка (см. §4).
* все `modd_*.F90` (константы и опции), `mode_thermos`, `mode_psychro`,
  `mode_conv_DOE`, `mode_surf_snow_frac`, бюджеты слоёв
  (`*_layer_e_budget`), `urban_fluxes`, `urban_hydro`, `urban_snow_evol`,
  `urban_lw_coef`, `snow_cover_1layer`, `solar_panel`, `window_*`,
  `tridiag_ground`, `surface_cd`, `surface_aero_cond`, `wind_threshold` и др. —
  **побайтово совпадают**.

---

## 6. Примечание: `teb_garden_with_snow_correction.F90`

В `src_teb/` репозитория TEB-Ru есть файл `teb_garden_with_snow_correction.F90`
(и `teb_garden_original.F90`), которых нет в COSMO-TEB. В нём снежная коррекция
из §2.1 **активна** и **дословно совпадает** с активным блоком COSMO-TEB
(`WSNOW_*_CHECK`; два `WHERE`-вычисления; сброс `ALB/EMIS/TS = XUNDEF`;
`PDN_RD/RF = 0.`; `ZDF_RD/RF = 1.`):

```fortran
 ! MT
 WSNOW_ROOF_CHECK = 0.
 WSNOW_ROAD_CHECK = 0.
 WHERE (T%TSNOW_ROAD%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROAD_CHECK = PTSTEP * PSR(:)
 WHERE (T%TSNOW_ROOF%WSNOW(:,1)==0. .AND. PSR(:)>0.) WSNOW_ROOF_CHECK = PTSTEP * PSR(:)
 ...
 ! MT
 ! Exclude cases of very low snow rate
 WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )
    T%TSNOW_ROAD%ALB (:) = XUNDEF
    T%TSNOW_ROAD%EMIS(:) = XUNDEF
    T%TSNOW_ROAD%TS  (:) = XUNDEF
    PDN_RD = 0.
    ZDF_RD = 1.
 END WHERE
 WHERE ( WSNOW_ROOF_CHECK(:)<1.E-8 * PTSTEP )
    T%TSNOW_ROOF%ALB (:) = XUNDEF
    T%TSNOW_ROOF%EMIS(:) = XUNDEF
    T%TSNOW_ROOF%TS  (:) = XUNDEF
    PDN_RF = 0.
    ZDF_RF = 1.
 END WHERE
```

При этом отключение жалюзи в этом файле тоже **активно** (`GSHADE(:) = .FALSE.`),
как в COSMO-TEB.

**Важно:** этот файл **не компилируется** — в `Makefile` в списке `SRC` стоит
`src_teb/teb_garden.F90`. Т. е. это готовая заготовка с поведением COSMO-TEB,
но в сборку не включённая (реализуемый флаг `teb_snow_check` делает то же самое
без отдельного файла).

---

## 7. Итог по направлению отличий

* **«Закомментировано в TEB-Ru, активно в COSMO-TEB»** — блоки, помеченные `! MT`:
  1. снежная коррекция (`teb_garden.F90`): ROAD и ROOF; сброс
     `ALB/EMIS/TS = XUNDEF`, `PDN = 0.`, `ZDF = 1.`; **дословно один и тот же
     блок** → реализуется флагом `teb_snow_check`;
  2. принудительное отключение затеняющих устройств (`urban_solar_abs.F90` и
     `teb_garden.F90`) — **покрывается существующим ключом `teb_lshade = .FALSE.`**
     (в COSMO `LSHADE` и так жёстко `.FALSE.`), отдельный код не нужен.
* **Активно в TEB-Ru, отсутствует в COSMO-TEB** — `MIN(PRI,XRIMAX)`
  (`surface_ri.F90`) и `MAX(u*, 0.1)` (`urban_drag.F90`); переключатели
  (`teb_pri_max`, `teb_ustar_min`) **отложены**.
* **Сад / зелёная кровля** — COSMO-TEB использует **режим внешней модели**
  (`EXT`/`EXT_NEU`), который в TEB-Ru уже есть; см. §4. На базовый прогон
  (сад/кровля выключены) не влияет.
* Всё остальное — косметика; константы и ядро физики идентичны.

---

## 8. Принятый план работ и открытые вопросы

**План (согласован):**

1. **Документация** — корректировка описания различий (этот файл). — **выполнено**.
2. **`teb_snow_check`** — новый логический ключ `/tebparam/` (дефолт `.FALSE.`),
   реализован **в обеих ветвях** (`src_ctrl` и `src_dev`); размещён в
   существующем модуле `MODD_SURF_PAR` (правок `USE`/`Makefile` не потребовалось),
   применение — guard вокруг блока в `teb_garden.F90`. — **выполнено**.
   Проверка: при отсутствии ключа результат **побитово** совпадает с прежним
   (`fe0a3c083626047a` для `src_ctrl`, `6555198f48e973e6` для `src_dev`);
   при `teb_snow_check = .TRUE.` меняются **1507 из 18001** строк (обе ветви),
   начиная со строки 16494 (снежный период 2005-01-28), амплитуда ≤ 0.13 K.
3. **`EXT`/`EXT_NEU` в `src_ctrl`** — **выполнено**: ключи принимаются, драйвер
   выставляет `teb_lgarden_ext`/`teb_lgreenroof_ext = .TRUE.` и запускает
   **боуэновский эмулятор** (`PCD_GARDEN`/`PCD_GREENROOF` в `run_teb_offline.F90`),
   который повторяет внутренний прокси сада/кровли и подаёт результат через
   интерфейс `*_EXT` (лаг в один под-шаг, как в `src_dev`; `src_dev`-эмулятор
   дословно не переносится — он опирается на `GARDEN_PCD`/`MODE_GARDEN_BALANCE`,
   которых в `src_ctrl` нет).
   Проверка (`fr_garden = 0.2`, `teb_lgarden = .TRUE.`, `urb_emis_gdn = 0.98`):
   `EXT`+эмулятор против внутреннего прокси — **без NaN**, средние различия
   `T_CANYON` 0.004 K, `H_TOWN` 0.07 W/m², `LE_TOWN` 0.30 W/m²; максимумы в
   переходных процессах 0.14 K и ~11 W/m² (следствие лага в один под-шаг).
   Систематическое различие `RN_TOWN` ≈ 3.5 W/m² объясняется тем, что режим `EXT`
   считает полный радиационный бюджет сада (с длинноволновым членом), а
   внутренний прокси — только `(1−0.15)·SW` (см. §4).
4. **Различия «внешнего сада»** — зафиксированы ниже, проработка отложена.

**Открытые вопросы (к дальнейшей проработке):**

1. `PAC_AGG_GARDEN`: COSMO `= PAC_GARDEN`; в TEB-Ru `EXT` остаётся `0`
   (не перезаписывается) → кандидат на правку `ZAC_AGG_GD(:) = PAC_GD(:)`.
2. Кровля, Rn: TEB-Ru `EXT` = `ABS_SW+ABS_LW`; COSMO = только КВ
   (`(1−PALB_GR)·SW`) — расхождение в учёте длинноволновой части.
3. `PHU_AGG_GREENROOF`: COSMO `0.3` против дефолта `urb_phu_grf = 0.7`
   в `src_dev` (в базовой модели `0.3`).
4. Трение сада `PUW` зависит от `urb_z0_gdn` (`src_dev` `0.10` vs `src_ctrl`
   `0.80`) — при паритете задавать явно.
5. Определения коэффициентов обмена внешних сада/кровли (`URBAN_DRAG`:
   `EXT` = полный `URBAN_EXCH_COEF`, `EXT_NEU` = нейтральный лог) против COSMO —
   сверить при строгой сверке.
6. Источник `PQV_GD` у COSMO (влажность сада от хоста) и способ воспроизведения
   этой величины оффлайн.

**После переноса подтверждённых находок в основные документы
(`TEB_Ru_source_defects.md` / `TEB_Ru_change_history.md`) этот временный файл
удаляется.**
