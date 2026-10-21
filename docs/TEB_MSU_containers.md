# Контейнеры TEB-MSU: устройство, владение и пути от teb_interface до teb_garden

Документ описывает **реализованное** устройство всех контейнеров модели TEB-MSU:
одиннадцать объектов (параметры, опции, состояние, диагностика, форсинг подшага и
внешние поверхности сада/кровли), их владение и
жизненный цикл, состав полей и путь по цепочке вызовов
`run_teb_offline → teb_interface → CALL_DRIVER → TEB_GARDEN`. Обёртка
`TEB_GARDEN_STRUCT` удалена: `CALL_DRIVER` вызывает физику `TEB_GARDEN` напрямую.

Смежные документы:

* `TEB_MSU_CBS_scheme_T_CAN_reformulation.md` — CBS-схема дороги (диагностики
  `H_ROAD`, `LE_ROAD`, `T_CAN0`, `T_CAN1`, `PCD_ROAD_*`, `PAC_ROAD_*` — поля `DMT`);
* `TEB_MSU_garden_diagnostic_scheme.md` — диагностическая схема сада и внешняя
  модель кровли;
* `TEB_MSU_source_defects.md` — дефекты исходного TEB;
* `TEB_MSU_change_history.md` — история изменений (записи 48–81 описывают
  появление контейнеров, последующую дедупликацию и вынос форсинга в `FORC`);
* `TEB_MSU_coupling_checklist.md` — сопряжение с COSMO-TEB: что контейнеры
  означают для хоста.

---

## 1. Назначение

**Задача.** Физика TEB-MSU оперирует пятью родами величин:

* **статика** (конфигурация, геометрия, материалы) — задаётся один раз из
  неймлиста и не меняется во время расчёта;
* **состояние** (прогностические температуры, влажности, снег) — переносится
  между подшагами и шагами форсинга;
* **диагностика** (потоки, поглощения, агрегаты города) — считается физикой
  только для вывода в CSV и накоплений драйвера;
* **форсинг подшага** (метеорологические входы хоста и их производные) —
  обновляется каждый подшаг и только читается физикой;
* **внешние поверхности** (состояние и потоки внешнего сада и зелёной крыши,
  рассчитанные хостом) — обновляются каждый подшаг и только читаются физикой.

Раньше все пять родов передавались плоскими аргументами: подпись физики росла до
нескольких сотен dummy, а расхождение списков (порядок, тип, ранг) не проверял
никакой компилятор. Теперь величины сгруппированы в **одиннадцать контейнеров**,
которые создаются один раз на прогон и протягиваются по цепочке вызовов одним
аргументом каждый.

**Решение.**

* состояние, параметры, опции, диагностика, форсинг подшага и внешние
  поверхности передаются одиннадцатью агрегатами
  `TOPTS, TPARAMS, TSTATE, BOPTS, BPARAMS, BSTATE, TPN, TIR, DMT, FORC, EXT`;
* часы, индексы ячейки, координаты и две проводимости сада
  (`teb_tch_gd`/`teb_tcm_gd`, которые TEB возвращает хосту) остаются плоскими
  аргументами (они нужны вызываемому «как есть» и меняются каждый шаг/ячейку);
* подписи процедур — модульные и сверяются компилятором на каждом вызове.

---

## 2. Одиннадцать контейнеров

| имя | тип | файл | состав (полей) | роль |
| --- | --- | --- | --- | --- |
| `DMT` | `DIAG_MISC_TEB_t` | `src_struct/modd_diag_misc_tebn.F90` | 207 | диагностика: потоки, поглощения, агрегаты города, снег, сад/кровля (вывод CSV) |
| `TOPTS` | `TEB_OPTIONS_t` | `src_struct/modd_teb_optionn.F90` | 22 param + 2 work + 3 reserved | опции TEB (схемы, флаги, тип сада/кровли) |
| `TPARAMS` | `TEB_PARAMS_t` | `src_struct/modd_teb_paramsn.F90` | 38 param + 4 flux | статические параметры TEB (геометрия, материалы, антропогенные потоки) |
| `TSTATE` | `TEB_t` | `src_struct/modd_tebn.F90` | 10 state + 1 reserved | прогностическое состояние TEB (крыша, дорога, стены, каньон, снег) |
| `BOPTS` | `BEM_OPTIONS_t` | `src_struct/modd_bem_optionn.F90` | 5 param | опции BEM (тип кондиционирования, coil, autosize) |
| `BPARAMS` | `BEM_PARAMS_t` | `src_struct/modd_bem_paramsn.F90` | 40 param | статические параметры BEM (полы, HVAC, окна) |
| `BSTATE` | `BEM_t` | `src_struct/modd_bemn.F90` | 9 state + 8 work + 2 reserved | состояние BEM (температуры пола/массы, окна, HVAC-аккумуляторы) |
| `TPN` | `TEB_PANEL_t` | `src_struct/modd_teb_paneln.F90` | 4 param + 1 state | солнечные панели (доля, альбедо, КПД, температура) |
| `TIR` | `TEB_IRRIG_t` | `src_struct/modd_teb_irrign.F90` | 6 param + 13 reserved | ирригация дороги (окно полива) |
| `FORC` | `TEB_FORCING_t` | `src_struct/modd_teb_forcingn.F90` | 22 work | форсинг подшага: 14 сырых величин хоста + 8 производных (давление и функции Экнера, плотность, скорость ветра, солнечное время и положение солнца, прямая/рассеянная SW) |
| `EXT` | `TEB_EXT_SURF_t` | `src_struct/modd_teb_ext_surfn.F90` | 18 work | внешние поверхности: состояние и потоки внешнего сада и зелёной крыши, рассчитанные хостом (шероховатость, альбедо, эмиссивность, температура, влажность, потоки, испарение, сток) |

Итого **415 полей** в одиннадцати контейнерах (207 `DMT` + 208 в десяти типах стенда
`container_fields_inventory.py`). Категории (`param`/`flux`/`state`/
`work`/`reserved`) — контракт из `python_tests/container_fields_inventory.py`;
`DMT` отслеживается отдельным стендом `python_tests/check_diag_container.py`.

---

## 3. Слой контейнеров: модуль TEB_HOST

Контейнеры объявлены в `src_api/teb_host.F90` как переменные модуля `TEB_HOST`:

```fortran
TYPE(TEB_OPTIONS_t),  SAVE :: TOPTS     ! options of TEB
TYPE(TEB_PARAMS_t),   SAVE :: TPARAMS   ! parameters of TEB
TYPE(TEB_t),          SAVE :: TSTATE    ! state of TEB
TYPE(BEM_OPTIONS_t),  SAVE :: BOPTS     ! options of BEM
TYPE(BEM_PARAMS_t),   SAVE :: BPARAMS   ! parameters of BEM
TYPE(BEM_t),          SAVE :: BSTATE    ! state of BEM
TYPE(TEB_PANEL_t),    SAVE :: TPN       ! solar panels
TYPE(TEB_IRRIG_t),    SAVE :: TIR       ! irrigation
TYPE(DIAG_MISC_TEB_t),SAVE :: DMT       ! diagnostics
TYPE(TEB_FORCING_t),  SAVE :: FORC      ! atmospheric forcing of the sub-step
TYPE(TEB_EXT_SURF_t), SAVE :: EXT       ! external garden / greenroof surface (host -> TEB)
```

Процедуры слоя:

| процедура | действие |
| --- | --- |
| `TEB_HOST_ENSURE(KNVEC, KROOF, KROAD, KWALL, KFLOOR)` | ленивая аллокация всех одиннадцати контейнеров (один раз на поток/прогон) |
| `TEB_FILL_PARAMS(KSTART, KEND, …)` | запись конфигурации неймлиста в `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` (только окно `KSTART:KEND`) |
| `TEB_FILL_DERIVED(KSTART, KEND, …)` | производные статические параметры (геометрия, СВФ, морфология BEM, оптика окон) |
| `TEB_FILL_FORCING(KSTART, KEND, …)` | форсинг подшага: сырые величины хоста и производные (`FORC`) |
| `TEB_FILL_EXT(KSTART, KEND, PDT, …)` | внешние поверхности: состояние и потоки сада/кровли от хоста (`EXT`), сток приводится к потоку (`/PDT`) |
| `TEB_BIND_STATE(KSTART, KEND, …)` | привязка указателей `TSTATE`/`BSTATE` к окну хоста `teb_*` |
| `TEB_UNBIND_STATE(KSTART, KEND, …)` | отвязка указателей после шага |
| `TEB_HOST_FINAL` | деаллокация всех контейнеров (конец прогона) |

**Аллокация.** `TEB_HOST_ENSURE` вызывает `ALLOC_TEB_STRUCT` (для `TOPTS`,
`TSTATE`, `BOPTS`, `BSTATE`, `TPN`, `TIR`), `ALLOC_TEB_PARAMS` (`TPARAMS`),
`ALLOC_BEM_PARAMS` (`BPARAMS`), `DIAG_MISC_TEB_ALLOC` (`DMT`),
`ALLOC_TEB_FORCING` (`FORC`) и `ALLOC_TEB_EXT_SURF` (`EXT`). `TPARAMS`/`BPARAMS` вынесены из
`TEB_t`/`BEM_t`, чтобы состояние держало только прогностику, а статика жила
отдельно и передавалась явными аргументами `TPARAMS`/`BPARAMS`.

**Заполнение.** `TEB_FILL_PARAMS` записывает значения неймлиста прямо в
`teb_interface` — там, где конфигурация известна. `CALL_DRIVER` больше не
копирует свои аргументы в контейнеры: у него остались только производные
присваивания, которые считаются из его локальных переменных
(`TEB_FILL_DERIVED`, записи 63–67 истории).

**Состояние.** `TEB_BIND_STATE` привязывает 26 dummy-полей `TSTATE`/`BSTATE` к
окну `KSTART:KEND` через указатели (`BSTATE%LSHADE(KSTART:KEND) = teb_lshade` и
т.д.); физика читает/пишет состояние через ссылки, `TEB_UNBIND_STATE` отвязывает
после шага. Это убирает копирование «аргумент → контейнер» из физики.

---

## 4. Путь контейнеров по цепочке вызовов

```
run_teb_offline
  → teb_interface (154 аргумента)                    src_api/sfc_teb.F90
      → TEB_HOST_ENSURE      аллокация 11 контейнеров (первый вызов)
      → TEB_FILL_PARAMS      TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR ← неймлист
      → TEB_FILL_DERIVED     производная статика (морфология, оптика окон)
      → TEB_FILL_FORCING     FORC ← форсинг подшага (сырые + производные)
      → TEB_FILL_EXT         EXT ← внешние поверхности сада/кровли (хост -> TEB)
      → TEB_BIND_STATE       TSTATE/BSTATE ⇒ окно teb_* (указатели)
      → CALL_DRIVER (27 dummy)  [по ячейке]          src_driver/call_driver.F90
          → TEB_GARDEN (29 аргументов)               src_teb/teb_garden.F90
              читает/пишет TOPTS/TPARAMS/TSTATE/BOPTS/BPARAMS/BSTATE/TPN/TIR/DMT
              читает FORC и EXT
      → TEB_UNBIND_STATE     отвязка TSTATE/BSTATE
      → TEB_LOG_EMIT         строка CSV из DMT + состояния + FORC
  → TEB_HOST_FINAL           деаллокация (конец прогона)
```

Контейнеры **не объявляются** в `teb_interface`/`CALL_DRIVER` как локальные:
они — переменные модуля `TEB_HOST` и передаются по цепочке фактическими
аргументами (в подписи `CALL_DRIVER` и `TEB_GARDEN` они — dummy).

Путь каждого рода величин:

| род | путь | пишет | читает |
| --- | --- | --- | --- |
| статика `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` | `TEB_FILL_PARAMS`/`TEB_FILL_DERIVED` в `teb_interface` → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` (один раз на окно) | физика (`TEB_GARDEN` и её подпрограммы) |
| состояние `TSTATE/BSTATE` | `TEB_BIND_STATE` ⇒ окно хоста → `CALL_DRIVER` → `TEB_GARDEN` | физика | физика и `TEB_LOG_EMIT` |
| диагностика `DMT` | `TEB_HOST_ENSURE` (аллокация) → `CALL_DRIVER` → `TEB_GARDEN` | физика (`TEB_GARDEN` и её подпрограммы) | `TEB_LOG_EMIT` (CSV), `CALL_DRIVER` (агрегаты) |
| форсинг `FORC` | `ALLOC_TEB_FORCING` ⇒ `TEB_FILL_FORCING` (раз на подшаг) → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` | физика (`TEB_GARDEN` и её подпрограммы), `TEB_LOG_EMIT` (колонки `P_CANYON`, `SOLAR_*`) |
| внешние поверхности `EXT` | `ALLOC_TEB_EXT_SURF` ⇒ `TEB_FILL_EXT` (раз на подшаг) → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` | физика (`TEB_GARDEN` и её подпрограммы), `CALL_DRIVER` (агрегаты альбедо/проверка z0) |

`TEB_GARDEN` получает все одиннадцать контейнеров; `TPARAMS`, `FORC` и `EXT`
объявлены `INTENT(IN)` (только чтение), остальные восемь — `INTENT(INOUT)`.


---

## 5. Контейнеры в деталях

### 5.1 `DMT` — диагностика (`DIAG_MISC_TEB_t`, 207 полей)

Единственный контейнер, который заполняет **физика** и читает **вывод**.
Поля — `REAL, POINTER, DIMENSION(:)`; длина задаётся при аллокации (`KNVEC`,
в offline-драйвере 1). Состав: поля SURFEX (`XH_WALL_A`, `XRN_ROOF`, `XGFLUX_*`,
`XHVAC_*`), поля TEB-MSU (CBS-диагностики дороги, сад/кровля, снежная ветка) и
запись диагностик ветвей CBS-схемы, использованная дважды (см. ниже).

* аллокация — `DIAG_MISC_TEB_ALLOC(DMT, KNVEC)` (в `TEB_HOST_ENSURE`);
* `NULLIFY`/`ALLOCATE`/`DEALLOCATE` — три зеркальных списка (207/207/207),
  проверяются стендом `check_diag_container.py`;
* у каждого поля есть **производитель** — прямое присваивание либо dummy
  `INTENT(OUT/INOUT)` (в легаси-объявлениях — маркер `!OUT`); это проверяет
  `check_diag_producers.py`. Единственное исключение — `XIRRIG_GARDEN`
  (`reserved`: полив сада не реализован, `GARDEN_CBS` возвращает `PIRRIG_GARDEN = 0.`);
* `XUNDEF`-инициализация 15 полей (выходные диагностики, читаемые до записи)
  перенесена из обёртки в `TEB_GARDEN`;
* агрегаты города (`H_TOWN`, `LE_TOWN`, `RUNOFF_*`, `HSNOW_TOWN` и др.) считает
  `CALL_DRIVER` из величин физики.

**Ветви CBS-схемы (`TEB_CBS_BRANCH_t`).** Схема обменивает дорогу, сад и снег на
дороге с двумя резервуарами воздуха — воздухом каньона (`CAN`) и уровнем
форсинга (`ATM`). Обе ветви несут один и тот же набор величин, поэтому он
объявлен **одной записью** и использован в `DMT` дважды: `DMT%CAN%…` и
`DMT%ATM%…` (тот же приём, что `TSTATE%TSNOW_ROOF%T`).

| компонент | что это | колонки CSV (`CAN` / `ATM`) |
| --- | --- | --- |
| `PCD_ROAD`, `PCDN_ROAD`, `PRI_ROAD`, `ZZ0H_ROAD` | коэффициенты обмена дороги | `PCD_ROAD_CAN`/`_ATM`, `PCDN_…`, `PRI_…`, `ZZ0H_…` |
| `PAC_ROAD`, `PAC_ROAD_WAT`, `PCH_ROAD` | проводимости дороги (сухая, водная, тепло) | `PAC_ROAD_CAN`/`PAC_ROAD_ATM`, `PAC_ROAD_WAT`/`PAC_ROAD_ATM_WAT`, `PCH_ROAD_CAN`/`PCH_ROAD_ATM` |
| `PH_ROAD`, `PLE_ROAD` | потоки дороги в ветвь | `H_ROAD_CAN`/`_ATM`, `LE_ROAD_CAN`/`_ATM` |
| `PCD_GARDEN`, `PCH_GARDEN`, `PCDN_GARDEN`, `PRI_GARDEN`, `ZZ0H_GARDEN`, `PAC_GARDEN` | коэффициенты и проводимости сада | `PCD_GARDEN_CAN`/`_ATM`, `PCH_…`, `PCDN_…`, `PRI_…`, `ZZ0H_…`, `PAC_GARDEN`/`PAC_GARDEN_ATM` |
| `H_GARDEN`, `LE_GARDEN` | потоки сада в ветвь | `H_GARDEN_CAN`/`_ATM`, `LE_GARDEN_CAN`/`_ATM` |
| `PHSN_RD`, `PLESN_RD` | снег на дороге → ветвь | не выводятся |

Жизненный цикл записи — при ней самой: `INIT_CBS_BRANCH` (`NULLIFY`),
`ALLOC_CBS_BRANCH` и `DEALLOC_CBS_BRANCH` (в `MODD_DIAG_MISC_TEB_n`) действуют
на один экземпляр и вызываются для `CAN` и `ATM` из `DIAG_MISC_TEB_INIT` /
`DIAG_MISC_TEB_ALLOC` / `DIAG_MISC_TEB_DEALLOC`.

Две оговорки:

* `PHSN_RD`/`PLESN_RD` **персистентны**: узлы каньона читают их в начале
  подшага, а `URBAN_SNOW_EVOL` пишет в конце, т.е. это значение
  **предыдущего** подшага;
* в режимах `PROXY_*` модель сада возвращает одну проводимость, и она попадает
  в `CAN%PAC_GARDEN` (колонка `PAC_GARDEN`), а `ATM%PAC_GARDEN` остаётся
  `XUNDEF`; в `EXT`/`EXT_NEU` заполняются обе ветви (`URBAN_DRAG`).

Шесть полей с суффиксом `_ATM` остаются плоскими — `PAC_GREENROOF_ATM`,
`PCD_GREENROOF_ATM`, `PCDN_GREENROOF_ATM`, `PCH_GREENROOF_ATM`,
`PRI_GREENROOF_ATM`, `ZZ0H_GREENROOF_ATM`: у зелёной кровли ветвей нет, она
обменивается только с уровнем форсинга.

### 5.2 `TOPTS` — опции TEB (`TEB_OPTIONS_t`, 22 param + 2 work + 3 reserved)

Схемы и флаги: `CGARDEN`/`LGARDEN`, `LGREENROOF(_EXT)`, `CTYPE_GARDEN`/
`CTYPE_GREENROOF`, `CBEM`, `ITYPE_WIND`, `LSOLAR_PANEL`, `LCBS_SCHEME`,
`XTAU_HW_THRESH`/`XTAU_HW_WIDTH`, `NUTC_HOUR`, `XZ0_O_Z0H_GD/GR`. Поля `work`
(`TTIME`, `XTSTEP`) заполняет `CALL_DRIVER` на каждом шаге.

### 5.3 `TPARAMS` — параметры TEB (`TEB_PARAMS_t`, 38 param + 4 flux)

Статическая геометрия и материалы: доли (`XBLD`, `XROAD`, `XGARDEN`,
`XGREENROOF`), `XCAN_HW_RATIO`, `XBLD_HEIGHT`, альбедо/эмиссивность/теплоёмкость/
проводимость крыши-дороги-стен, СВФ, `XZ0_TOWN`/`XZD_TOWN`, застройка
(`XRESIDENTIAL`, `XDT_RES/OFF`). Поля `flux` — антропогенные потоки
(`XH_/XLE_TRAFFIC`, `XH_/XLE_INDUSTRY`). `INTENT(IN)` во всей физике.

### 5.4 `TSTATE` — состояние TEB (`TEB_t`, 10 state + 1 reserved)

Прогностика поверхности: `XT_ROOF/ROAD/WALL_A/WALL_B`, `XT_CANYON`,
`XQ_CANYON`, `XWS_ROOF/ROAD`, снег (`TSNOW_ROOF/ROAD` с полями `WSNOW`, `T`,
`RHO`, `ALB`, `EMIS`, `TS`, `SCHEME`). `TSNOW_*%SCHEME` задаёт `TEB_GARDEN` из
`HSNOW_ROOF/HSNOW_ROAD` (ранее — обёртка).

### 5.5 `BOPTS` — опции BEM (`BEM_OPTIONS_t`, 5 param)

Тип кондиционирования и coil: `CCOOL_COIL`, `CHEAT_COIL`, `LBEM_AC`,
`LAUTOSIZE`, `NFLOOR_LAYER` (число слоёв, задаётся из `teb_nfloor_layer`).

### 5.6 `BPARAMS` — параметры BEM (`BEM_PARAMS_t`, 40 param)

Статика здания: материалы пола (`XHC_FLOOR`, `XTC_FLOOR`, `XD_FLOOR`),
HVAC-уставки (`XTCOOL_TARGET`, `XTHEAT_TARGET`, `XCAP_SYS_HEAT`, `XCOP_RAT`),
вентиляция/инфильтрация (`XV_VENT`, `XINF`), окна (`XU_WIN`, `XTRAN_WIN`,
`XALB_WIN`, `XABS_WIN`, `XSHGC_WIN`), внутренняя геометрия и view-факторы.
`INTENT(INOUT)` в физике: BEM ещё пересчитывает оптику окон и autosize — это
снимается переносом однократных расчётов в инициализацию.

### 5.7 `BSTATE` — состояние BEM (`BEM_t`, 9 state + 8 work + 2 reserved)

Прогностика здания: `XT_FLOOR`, `XT_MASS`, `XTI_BLD`, `XQI_BLD`, `XT_WIN1/2`,
`XCAP_SYS_RAT`, `XM_SYS_RAT`. Блок `work` — непрогностические величины
(оптика окон `XALB_WIN`/`XABS_WIN`/`XTRAN_WIN`/`XUGG_WIN`, аккумулятор
`XAUX_MAX`, точка росы `XT_ADP`), флаги `LSHADE`/`LSHAD_DAY`/`LNATVENT_NIGHT`.
`RESERVED` — `XSHADE`, `XNATVENT` (REAL-зеркала флагов для i/o, помечены `TODO`).

### 5.8 `TPN` — солнечные панели (`TEB_PANEL_t`, 4 param + 1 state)

Параметры (`XEMIS_PANEL`, `XALB_PANEL`, `XEFF_PANEL`, `XFRAC_PANEL`) задаёт
`TEB_FILL_PARAMS` (перенесены из `CALL_DRIVER`, P-C4); состояние (производство,
температура) — физика (`SOLAR_PANEL`).

### 5.9 `TIR` — ирригация дороги (`TEB_IRRIG_t`, 6 param + 13 reserved)

Окно полива: `LPAR_RD_IRRIG`, `XRD_START/END_MONTH`, `XRD_START/END_HOUR`,
`XRD_SUM`; заполняется в `TEB_FILL_PARAMS`.


---

### 5.10 `FORC` — форсинг подшага (`TEB_FORCING_t`, 22 work)

Контейнер, который заполняет **слой** (`TEB_FILL_FORCING`) и читают только
физика и вывод. Он заменил 19 отдельных аргументов, несших те же величины от
`CALL_DRIVER` до `TEB_GARDEN`, и снял с драйвера чтение глобальных массивов
`MODD_FORC_ATM`.

| группа | поля | источник |
| --- | --- | --- |
| сырые | `XU`, `XV`, `XTA`, `XQA`, `XPS`, `XZS`, `XRAIN`, `XSNOW`, `XLW`, `XDIR_SW`, `XSCA_SW`, `XZREF`, `XUREF`, `XCO2` | аргументы `teb_interface` (окно `KSTART:KEND`) |
| производные | `XPA`, `XEXNS`, `XEXNA`, `XRHOA`, `XVMOD`, `XTSUN`, `XZENITH`, `XAZIM` | `TEB_FILL_FORCING` |

* `XDIR_SW`/`XSCA_SW` — **после** коррекции горизонта (`ZCOEF`) и разбиения по
  околосолнечной модели (`CIRCUMSOLAR_RAD`): это те величины, которые
  потребляет физика, а не сырые `swdir_s`/`swdifd_s` хоста.
* `XQA` — **удельная** влажность в кг/кг (это `qv` хоста и `PQA` физики); её
  нельзя путать с `MODD_FORC_ATM%XQA` в кг/м³, которым пользуется ридер
  offline-драйвера.
* `XZS` в offline-хосте не задаётся (`XUNDEF`): запасное значение давления
  `101325·(1−0.0065·XZS/288.15)^5.31` сохраняет историческое поведение.
* `XCO2` хостом не задаётся — ноль, как и прежде.
* Формулы, их порядок и подстановки `XUNDEF` — дословно из прежнего блока
  `CALL_DRIVER`, включая порядок «плотность и давление форсинга считаются до
  подстановки запасного давления».

**Мост `XZREF`/`XUREF`.** `OL_TIME_INTERP_ATM` строит плотность своей
атмосферы по `XZREF` модуля `MODD_FORC_ATM`, а хост переводит абсолютную
влажность форсинга через неё (`qv = XQA/XRHOA`, `rho = XRHOA`). Раньше эти два
поля обновлял `CALL_DRIVER`; теперь он копирует их из контейнера
(`XZREF(1:1) = FORC%XZREF(icell:icell)`), иначе влажность и плотность хоста
застывают на `XUNDEF` (поймано первым прогоном A/B).


---

### 5.11 `EXT` — внешние поверхности (`TEB_EXT_SURF_t`, 18 work)

Контейнер, который заполняет **слой** (`TEB_FILL_EXT`) и читает только физика.
Он заменил 18 отдельных аргументов, несших состояние и потоки внешнего сада и
зелёной крыши от `teb_interface` до `TEB_GARDEN` (интерфейс `EXT`/`EXT_NEU`).

| группа | поля | источник |
| --- | --- | --- |
| зелёная крыша | `XZ0_GR`, `XALB_GR`, `XEMIS_GR`, `XTSRAD_GR`, `XQV_GR`, `XH_GR`, `XLE_GR`, `XEVAP_GR`, `XRUNOFF_GR` | `teb_z0_gr` … `teb_runoff_gr` |
| сад | `XZ0_GD`, `XALB_GD`, `XEMIS_GD`, `XTSRAD_GD`, `XQV_GD`, `XH_GD`, `XLE_GD`, `XEVAP_GD`, `XRUNOFF_GD` | `teb_z0_gd` … `teb_runoff_gd` |

* Направление — **хост → TEB**: эти величины считает внешняя модель сада/кровли
  (в offline-драйвере — эмулятор `PCD_GARDEN`/`PCD_GREENROOF`), а TEB подставляет
  их в бюджет города. Проводимости сада `CH`/`CD` идут наоборот (TEB → хост) и
  остались плоскими dummy `ZCH_GD`/`ZCD_GD` (`PCH_GD`/`PCD_GD` в `TEB_GARDEN`).
* `XTSRAD_*` — радиационная температура поверхности (у хоста `teb_ts_*`),
  `XQV_*` — удельная влажность поверхности (у хоста `teb_qs_*`).
* Два стока (`XRUNOFF_GR`/`XRUNOFF_GD`) хост отдаёт накопленными за шаг (кг/м²);
  `TEB_FILL_EXT` делит их на `PDT` — тот же `/dt`, что раньше применял
  `CALL_DRIVER`, поэтому контейнер несёт готовый поток (кг/м²/с).


---

## 6. Подписи цепочки

| процедура | файл | аргументы |
| --- | --- | --- |
| `teb_interface` | `src_api/sfc_teb.F90` | **154** (стык с coupled-моделью: числовые массивы + выходные скаляры `teb_wind_canyon`/`teb_sobs`/`teb_thbs`/`teb_runoff_*`) |
| `CALL_DRIVER` | `src_driver/call_driver.F90` | **27** dummy = 14 transient + 2 host-export + 11 container |
| `TEB_GARDEN` | `src_teb/teb_garden.F90` | **29** = 2 индекса + 11 контейнеров + 5 флагов/строк + 4 коэффициента связи + 1 `KSW` + 2 (`PH_TRAFFIC`, `PTSTEP`) + 2 (`KDAY`, `PTIME`) + 2 проводимости (`PCH_GD`, `PCD_GD`) |

`CALL_DRIVER` — процедура модуля `MODI_CALL_DRIVER`: подпись сверяется
компилятором на каждом вызове. Одиннадцать dummy-контейнеров —
`DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR, FORC, EXT`; 14 transient — часы,
индексы ячейки, координаты и городская доля; 2 host-export — проводимости сада
`ZCH_GD`/`ZCD_GD`, которые TEB пишет, а хост читает (обратное направление по
сравнению с `EXT`).

Пять флагов/строк `TEB_GARDEN` (`OGREENROOF_EXT`, `HIMPLICIT_WIND`, `PBEM_AC`,
`HSNOW_ROOF`, `HSNOW_ROAD`) — опции/параметры вызова, не вынесенные в
контейнеры: они передаются из `CALL_DRIVER` фактическими аргументами.
`KSW` (число спектральных полос) остаётся аргументом: он ограничивает цикл по
единственной полосе `PDIR_SW`/`PSCA_SW`.

---

## 7. Правила и проверки

| стенд | что проверяет |
| --- | --- |
| `python_tests/check_diag_container.py` | три списка полей `DMT` (тип, `NULLIFY`, `ALLOCATE`, `DEALLOCATE`): 207/207/207, включая компоненты записи `TEB_CBS_BRANCH_t` для обоих экземпляров (`CAN`, `ATM`); расхождение — ошибка |
| `python_tests/check_diag_producers.py` | производитель каждого поля `DMT` (плоского и двухуровневого `CAN%…`/`ATM%…`): прямое присваивание или `INTENT(OUT/INOUT)` (легаси `!OUT`) dummy; `= XUNDEF` производителем не считается; `XIRRIG_GARDEN` — `reserved` |
| `python_tests/container_fields_inventory.py` | категории полей десяти типов (`param`/`flux`/`state`/`work`/`reserved`/`dead`), включая `FORC` (22 `work`) и `EXT` (18 `work`), и сверка контракта в обе стороны: необъявленное поле — `UNCLASSIFIED`, объявленное, но не упомянутое нигде — `dead`, исчезнувшее из кода — `STALE TABLE`; `--strict` — `dead` как ошибка, `--enforce-param` — `param`/`flux` пишет только драйвер или слой `TEB_HOST`. Сейчас `RESULT: OK` во всех трёх режимах (27/11/42/5/19/40/5/19/22/18 поля) |
| `python_tests/call_signature_inventory.py` | подпись `CALL_DRIVER`: классы `transient`/`container`/`host-export`/`deferred`/`violation`; `--strict --expect 27` |
| `python_tests/container_ab_compare.py` | два бинарника на кейсе `tests/CAPITOUL`: побитовое сравнение CSV поле-в-поле, заголовок, число строк, SHA-256 |
| `python_tests/container_ab_matrix.py` | то же по матрице конфигураций; наборы (`--set`): `base` — 13 конфигураций словника (BEM, режимы сада и кровли, панели, CBS), `ext` — 13 конфигураций покрытия контейнеров (высота форсинга 3/50 м, `EXT_NEU` кровли, обе внешние поверхности одновременно, CBS при `urb_h_bld` 10/40 и `urb_h2w` 0.1/0.3/0.5/0.75, «внешний сад + CBS»), `opt` — 3, `all` — 29; физика — по именам колонок, `RUNOFF_*` и `EMU_*` — против отдельных файлов кандидата; сводка — `summary_matrix.csv` / `summary_matrix_<set>.csv` |
| `python_tests/bem_option_sensitivity.py` | чувствительность опций BEM и их A/B: для каждой опции два словника (off/on) и четыре прогона (ref/new x off/on). Проверяются обе вещи: кандидат побитово равен эталону для одного и того же словника (A/B) и результат кандидата меняется между off и on в наблюдаемых колонках, причём материально (`max_rel > 1e-6`, чтобы 1 ulp не выдавался за эффект). Опции: ставни (`teb_lshade`), кондиционеры (`teb_lbem_ac`), проветривание (`teb_itype_natvent` = `AUTO` и `MECH`); сводка — `bem_sensitivity/summary_bem_sensitivity.csv` |

```powershell
python python_tests/check_diag_container.py
python python_tests/check_diag_producers.py
python python_tests/container_fields_inventory.py
python python_tests/call_signature_inventory.py
python python_tests/container_ab_compare.py --ref-exe build/TEB_offline_dev_ref.exe `
    --new-exe build/TEB_offline_dev.exe
python python_tests/container_ab_matrix.py                  # --set base (по умолчанию)
python python_tests/container_ab_matrix.py --set ext        # покрытие контейнеров
python python_tests/container_ab_matrix.py --set all        # base + ext + opt
python python_tests/bem_option_sensitivity.py      # опции BEM: A/B + чувствительность
```

**Почему набор `ext` нужен.** Базовая матрица варьирует только словник на одной
геометрии и одном форсинге: `hlev_teb = 28`, `urb_h_bld = 20`,
`urb_h2w = 1.38158`. Последнее даёт `τ = 0.5·(1 + tanh((H/W − 0.5)/0.25)) = 0.999`,
т.е. и `baseline`, и `cbs_on` сидят в самом «каньонном» конце релаксации, а
переходная полоса и режим `τ ≈ 0` не проверяются вовсе. Набор `ext` добавляет:

* высоту форсинга 3 и 50 м — вклад `ZREF·G` в `XRHOA`/`XPA`/`XEXNA`, профиль
  `DMT%XWIND_TOP`, нейтральные коэффициенты эмулятора и мост `XZREF`/`XUREF`
  (плюс связка с обеими внешними поверхностями);
* `EXT_NEU` зелёной кровли и `combined_ext` — обе внешние поверхности в одном
  шаге вместе с панелями и CBS (базовый `combined` считает внутренние прокси);
* `urb_h2w` = 0.1 / 0.3 / 0.5 / 0.75 (`τ` = 0.04 / 0.17 / 0.50 / 0.88) и
  `urb_h_bld` = 10 / 40 м; `urb_z0_town='0.1H'` и `urb_zd_town='H/3'` следуют
  за высотой, поэтому аэродинамика остаётся согласованной.

**Опции BEM.** `bem_option_sensitivity.py` проверяет, что опции не «мёртвые»: для каждой — пара словников off/on, четыре прогона, A/B-идентичность на каждом и материальный отклик (`max_rel > 1e-6`). Измерено (18 000 шагов): ставни — до 28.97 на 13 842 строках, кондиционеры — до 54.02 на 13 848, проветривание `AUTO`/`MECH` — до 11.48/19.74; все четыре — `IDENTICAL` и материальны.

Референсный кейс — `tests/CAPITOUL` (18 000 шагов): 109 колонок в
`TEB_output_b1_c1.csv` и 26 колонок эмулятора в `TEB_emu.csv`. Критерий приёмки:
**побитовое совпадение** CSV (равные SHA-256) и `RESULT: OK` всех стендов.

---

## 8. Что изменилось за последние три дня

До правок цепочка заканчивалась обёрткой `TEB_GARDEN_STRUCT`, которая собирала
плоские аргументы в контейнеры и после вызова `TEB_GARDEN` копировала поля
контейнеров обратно в выходные dummy. Три дня дедупликации убрали обёртку
полностью:

| шаг | результат |
| --- | --- |
| P-C4 / Step 1 | входы панелей и ирригации перенесены в `TEB_FILL_PARAMS` |
| P-C2b / P-C3 / Step 2a-2b | состояние читается/пишется через `TSTATE`/`BSTATE` (`TEB_BIND_STATE`/`TEB_UNBIND_STATE`) |
| Step 2c | диагностика сада/кровли, обмены и агрегаты города — в `DMT` |
| Step E | ~33 чисто-внутренних аргумента обёртки → локальные переменные |
| Step E2 | copy-out аргументы обёртки (потоки 29 + поглощения/BEM-HVAC 47 + состояние/параметры 15) → `DMT`/`BSTATE`/`BPARAMS` |
| Step F | снежная ветка (`PHSN_RD_*`, `PLESN_RD_*`) → `DMT`; `HSNOW_*` → `T%TSNOW_*%SCHEME`; `XUNDEF`-инициализация → `TEB_GARDEN` |
| Step G | `CALL_DRIVER` вызывает `TEB_GARDEN` напрямую; `TEB_GARDEN_STRUCT` и `modi_teb_garden_struct.f90` удалены; `Makefile` очищен |

Итоговые счётчики: `TEB_GARDEN_STRUCT` был 411 → 326 → 304 → 83 → 68 аргументов
и затем удалён; `TEB_GARDEN` — **29** аргументов (было 46/65); `CALL_DRIVER` — **27**
dummy (было 44/57; 11 контейнеров); `teb_interface` — **154** (стык с coupled-моделью
сохранён). `DMT` вырос до **208** полей, после удаления незаполняемых `XSOBS`/`XTHBS`/`XALB_TH`
(см. `TEB_MSU_change_history.md`, §5.6, N3) — **205**, после объединения диагностик
ветвей CBS-схемы в запись `TEB_CBS_BRANCH_t` — **207**. Вся дедупликация побитово
идентична эталону: полный A/B (18 000 шагов) — `IDENTICAL`, SHA-256 CSV `30499e1f…`.

| шаг | результат |
| --- | --- |
| Step H1 | форсинг подшага — в контейнере `FORC` (`TEB_FORCING_t`, 22 поля): `TEB_FILL_FORCING` в `TEB_HOST`, `CALL_DRIVER` 57 → 44 (19 плоских dummy → `FORC`) |
| Step H2 | `TEB_GARDEN` принимает `FORC` (65 → 46); `PSW_BANDS` (мёртвый) удалён |
| Step H3 | `teb_log` читает `FORC%XPS`/`XZENITH`/`XAZIM`; `MODD_FORC_ATM` остаётся только у хоста (мост `XZREF`/`XUREF`) |
| Step H4 | внешние поверхности сада/кровли — в контейнере `EXT` (`TEB_EXT_SURF_t`, 18 полей): `TEB_FILL_EXT` в `TEB_HOST`, `CALL_DRIVER` 44 → 27, `TEB_GARDEN` 46 → 29; проводимости `CH`/`CD` остаются плоскими (TEB → хост) |

