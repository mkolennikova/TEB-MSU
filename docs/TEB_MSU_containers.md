# Контейнеры TEB-MSU: устройство, владение и пути от teb_interface до teb_garden

Документ описывает **реализованное** устройство всех контейнеров модели TEB-MSU:
девять объектов (параметры, опции, состояние и диагностика), их владение и
жизненный цикл, состав полей и путь по цепочке вызовов
`run_teb_offline → teb_interface → CALL_DRIVER → TEB_GARDEN`. Обёртка
`TEB_GARDEN_STRUCT` удалена: `CALL_DRIVER` вызывает физику `TEB_GARDEN` напрямую.

Смежные документы:

* `TEB_MSU_CBS_scheme_T_CAN_reformulation.md` — CBS-схема дороги (диагностики
  `H_ROAD`, `LE_ROAD`, `T_CAN0`, `T_CAN1`, `PCD_ROAD_*`, `PAC_ROAD_*` — поля `DMT`);
* `TEB_MSU_garden_diagnostic_scheme.md` — диагностическая схема сада и внешняя
  модель кровли;
* `TEB_MSU_source_defects.md` — дефекты исходного TEB;
* `TEB_MSU_change_history.md` — история изменений (записи 48–71 описывают
  появление контейнеров и последующую дедупликацию);
* `TEB_MSU_coupling_checklist.md` — сопряжение с COSMO-TEB: что контейнеры
  означают для хоста.

---

## 1. Назначение

**Задача.** Физика TEB-MSU оперирует тремя родами величин:

* **статика** (конфигурация, геометрия, материалы) — задаётся один раз из
  неймлиста и не меняется во время расчёта;
* **состояние** (прогностические температуры, влажности, снег) — переносится
  между подшагами и шагами форсинга;
* **диагностика** (потоки, поглощения, агрегаты города) — считается физикой
  только для вывода в CSV и накоплений драйвера.

Раньше все три рода передавались плоскими аргументами: подпись физики росла до
нескольких сотен dummy, а расхождение списков (порядок, тип, ранг) не проверял
никакой компилятор. Теперь величины сгруппированы в **девять контейнеров**,
которые создаются один раз на прогон и протягиваются по цепочке вызовов одним
аргументом каждый.

**Решение.**

* состояние, параметры, опции и диагностика передаются девятью агрегатами
  `TOPTS, TPARAMS, TSTATE, BOPTS, BPARAMS, BSTATE, TPN, TIR, DMT`;
* форсинг, часы, индексы ячейки и интерфейс внешнего эмулятора сада/кровли
  остаются плоскими аргументами (они нужны вызываемому «как есть» и меняются
  каждый шаг/ячейку);
* подписи процедур — модульные и сверяются компилятором на каждом вызове.

---

## 2. Девять контейнеров

| имя | тип | файл | состав (полей) | роль |
| --- | --- | --- | --- | --- |
| `DMT` | `DIAG_MISC_TEB_t` | `src_struct/modd_diag_misc_tebn.F90` | 208 | диагностика: потоки, поглощения, агрегаты города, снег, сад/кровля (вывод CSV) |
| `TOPTS` | `TEB_OPTIONS_t` | `src_struct/modd_teb_optionn.F90` | 22 param + 2 work + 3 reserved | опции TEB (схемы, флаги, тип сада/кровли) |
| `TPARAMS` | `TEB_PARAMS_t` | `src_struct/modd_teb_paramsn.F90` | 38 param + 4 flux | статические параметры TEB (геометрия, материалы, антропогенные потоки) |
| `TSTATE` | `TEB_t` | `src_struct/modd_tebn.F90` | 10 state + 1 reserved | прогностическое состояние TEB (крыша, дорога, стены, каньон, снег) |
| `BOPTS` | `BEM_OPTIONS_t` | `src_struct/modd_bem_optionn.F90` | 5 param | опции BEM (тип кондиционирования, coil, autosize) |
| `BPARAMS` | `BEM_PARAMS_t` | `src_struct/modd_bem_paramsn.F90` | 40 param | статические параметры BEM (полы, HVAC, окна) |
| `BSTATE` | `BEM_t` | `src_struct/modd_bemn.F90` | 9 state + 8 work + 2 reserved | состояние BEM (температуры пола/массы, окна, HVAC-аккумуляторы) |
| `TPN` | `TEB_PANEL_t` | `src_struct/modd_teb_paneln.F90` | 4 param + 1 state | солнечные панели (доля, альбедо, КПД, температура) |
| `TIR` | `TEB_IRRIG_t` | `src_struct/modd_teb_irrign.F90` | 6 param + 13 reserved | ирригация дороги (окно полива) |

Итого **376 полей** в девяти контейнерах. Категории (`param`/`flux`/`state`/
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
```

Процедуры слоя:

| процедура | действие |
| --- | --- |
| `TEB_HOST_ENSURE(KNVEC, KROOF, KROAD, KWALL, KFLOOR)` | ленивая аллокация всех девяти контейнеров (один раз на поток/прогон) |
| `TEB_FILL_PARAMS(KSTART, KEND, …)` | запись конфигурации неймлиста в `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` (только окно `KSTART:KEND`) |
| `TEB_FILL_DERIVED(KSTART, KEND, …)` | производные статические параметры (геометрия, СВФ, морфология BEM, оптика окон) |
| `TEB_BIND_STATE(KSTART, KEND, …)` | привязка указателей `TSTATE`/`BSTATE` к окну хоста `teb_*` |
| `TEB_UNBIND_STATE(KSTART, KEND, …)` | отвязка указателей после шага |
| `TEB_HOST_FINAL` | деаллокация всех контейнеров (конец прогона) |

**Аллокация.** `TEB_HOST_ENSURE` вызывает `ALLOC_TEB_STRUCT` (для `TOPTS`,
`TSTATE`, `BOPTS`, `BSTATE`, `TPN`, `TIR`), `ALLOC_TEB_PARAMS` (`TPARAMS`),
`ALLOC_BEM_PARAMS` (`BPARAMS`) и `DIAG_MISC_TEB_ALLOC` (`DMT`). `TPARAMS`/`BPARAMS` вынесены из
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
      → TEB_HOST_ENSURE      аллокация 9 контейнеров (первый вызов)
      → TEB_FILL_PARAMS      TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR ← неймлист
      → TEB_FILL_DERIVED     производная статика (морфология, оптика окон)
      → TEB_BIND_STATE       TSTATE/BSTATE ⇒ окно teb_* (указатели)
      → CALL_DRIVER (57 dummy)  [по ячейке]          src_driver/call_driver.F90
          → TEB_GARDEN (65 аргументов)               src_teb/teb_garden.F90
              читает/пишет TOPTS/TPARAMS/TSTATE/BOPTS/BPARAMS/BSTATE/TPN/TIR/DMT
      → TEB_UNBIND_STATE     отвязка TSTATE/BSTATE
      → TEB_LOG_EMIT         строка CSV из DMT + состояния
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

`TEB_GARDEN` получает все девять контейнеров; `TPARAMS` объявлен `INTENT(IN)`
(только чтение), остальные восемь — `INTENT(INOUT)`.


---

## 5. Контейнеры в деталях

### 5.1 `DMT` — диагностика (`DIAG_MISC_TEB_t`, 205 полей)

Единственный контейнер, который заполняет **физика** и читает **вывод**.
Поля — `REAL, POINTER, DIMENSION(:)`; длина задаётся при аллокации (`KNVEC`,
в offline-драйвере 1). Состав: поля SURFEX (`XH_WALL_A`, `XRN_ROOF`, `XGFLUX_*`,
`XHVAC_*`) и поля TEB-MSU (CBS-диагностики дороги, сад/кровля, снежная ветка).

* аллокация — `DIAG_MISC_TEB_ALLOC(DMT, KNVEC)` (в `TEB_HOST_ENSURE`);
* `NULLIFY`/`ALLOCATE`/`DEALLOCATE` — три зеркальных списка (205/205/205),
  проверяются стендом `check_diag_container.py`;
* у каждого поля есть **производитель** — прямое присваивание либо dummy
  `INTENT(OUT/INOUT)` (в легаси-объявлениях — маркер `!OUT`); это проверяет
  `check_diag_producers.py`. Единственное исключение — `XIRRIG_GARDEN`
  (`reserved`: полив сада не реализован, `GARDEN_CBS` возвращает `PIRRIG_GARDEN = 0.`);
* `XUNDEF`-инициализация 15 полей (выходные диагностики, читаемые до записи)
  перенесена из обёртки в `TEB_GARDEN`;
* снежная ветка `XPHSN_RD_CAN/ATM`, `XPLESN_RD_CAN/ATM` — персистентна: физика
  читает/пишет `DMT` напрямую (носители-автоматы обёртки удалены);
* агрегаты города (`H_TOWN`, `LE_TOWN`, `RUNOFF_*`, `HSNOW_TOWN` и др.) считает
  `CALL_DRIVER` из величин физики.

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

## 6. Подписи цепочки

| процедура | файл | аргументы |
| --- | --- | --- |
| `teb_interface` | `src_api/sfc_teb.F90` | **154** (стык с coupled-моделью: числовые массивы + выходные скаляры `teb_wind_canyon`/`teb_sobs`/`teb_thbs`/`teb_runoff_*`) |
| `CALL_DRIVER` | `src_driver/call_driver.F90` | **57** dummy = 28 transient + 20 host-emulator + 9 container |
| `TEB_GARDEN` | `src_teb/teb_garden.F90` | **65** = 2 индекса + 9 контейнеров + 6 флагов/строк + 27 форсинг/коэффициенты + 2 (KDAY, PTIME) + 19 эмулятор |

`CALL_DRIVER` — процедура модуля `MODI_CALL_DRIVER`: подпись сверяется
компилятором на каждом вызове. Девять dummy-контейнеров —
`DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR`; 28 transient — форсинг, часы,
индексы ячейки; 20 host-emulator — интерфейс внешнего эмулятора сада/кровли
(`ZZ0_GR_EXT`…`ZRUNOFF_GD_EXT`), который остаётся плоским, потому что меняется
каждый шаг и принадлежит хосту, а не модели.

Шесть флагов/строк `TEB_GARDEN` (`OGREENROOF_EXT`, `HIMPLICIT_WIND`, `PBEM_AC`,
`PTSUN`, `HSNOW_ROOF`, `HSNOW_ROAD`) — опции/параметры вызова, не вынесенные в
контейнеры: они передаются из `CALL_DRIVER` фактическими аргументами.

---

## 7. Правила и проверки

| стенд | что проверяет |
| --- | --- |
| `python_tests/check_diag_container.py` | три списка полей `DMT` (тип, `NULLIFY`, `ALLOCATE`, `DEALLOCATE`): 205/205/205, расхождение — ошибка |
| `python_tests/check_diag_producers.py` | производитель каждого поля `DMT`: прямое присваивание или `INTENT(OUT/INOUT)` (легаси `!OUT`) dummy; `= XUNDEF` производителем не считается; `XIRRIG_GARDEN` — `reserved` |
| `python_tests/container_fields_inventory.py` | категории полей восьми контейнеров (`param`/`flux`/`state`/`work`/`reserved`/`dead`); `--enforce-param` — `param`/`flux` пишет только слой `TEB_HOST` |
| `python_tests/call_signature_inventory.py` | подпись `CALL_DRIVER`: классы `transient`/`container`/`host-emulator`/`deferred`/`violation`; `--strict --expect N` |
| `python_tests/container_ab_compare.py` | два бинарника на кейсе `tests/CAPITOUL`: побитовое сравнение CSV поле-в-поле, заголовок, число строк, SHA-256 |
| `python_tests/container_ab_matrix.py` | то же по матрице конфигураций словника (BEM, режимы сада и кровли, панели, CBS); физика — по именам колонок, `RUNOFF_*` и `EMU_*` — против отдельных файлов кандидата |

```powershell
python python_tests/check_diag_container.py
python python_tests/check_diag_producers.py
python python_tests/container_fields_inventory.py
python python_tests/call_signature_inventory.py
python python_tests/container_ab_compare.py --ref-exe build/TEB_offline_dev_ref.exe `
    --new-exe build/TEB_offline_dev.exe
python python_tests/container_ab_matrix.py
```

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
и затем удалён; `TEB_GARDEN` — **65** аргументов; `CALL_DRIVER` — **57** dummy
(9 контейнеров); `teb_interface` — **154** (стык с coupled-моделью сохранён).
`DMT` вырос до **208** полей, а после удаления незаполняемых `XSOBS`/`XTHBS`/`XALB_TH`
(см. `TEB_MSU_change_history.md`, §5.6, N3) — **205**. Вся дедупликация побитово
идентична эталону: полный A/B (18 000 шагов) — `IDENTICAL`, SHA-256 CSV `30499e1f…`.

