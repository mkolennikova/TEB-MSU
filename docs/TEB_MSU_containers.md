# Контейнеры TEB-MSU: устройство, владение и пути от teb_interface до teb_garden

Документ описывает **реализованное** устройство всех контейнеров модели TEB-MSU:
одиннадцать объектов (параметры, опции, состояние, диагностика, форсинг подшага и
внешние поверхности сада/кровли), их владение и
жизненный цикл, состав полей и путь по цепочке вызовов
`run_teb_offline → TEB_OFFLINE_DRIVER → teb_interface → CALL_DRIVER → TEB_GARDEN`. Обёртка
`TEB_GARDEN_STRUCT` удалена: `CALL_DRIVER` вызывает физику `TEB_GARDEN` напрямую.

> Состояние кода: `main`, коммит `1ecb04e` и рабочие изменения API `src_dev`.

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
  для хоста и вывода; два поля `DMT` также служат входами следующего подшага (§3);
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
| `DMT` | `DIAG_MISC_TEB_t` | `src_struct/modd_diag_misc_tebn.F90` | 231 | диагностика: потоки, поглощения, агрегаты города, снег, сад/кровля, MRT пешехода на дороге и на крыше; два межшаговых входа (§3) |
| `TOPTS` | `TEB_OPTIONS_t` | `src_struct/modd_teb_optionn.F90` | 26 param + 2 work + 3 reserved | опции TEB (схемы, флаги, тип сада/кровли) |
| `TPARAMS` | `TEB_PARAMS_t` | `src_struct/modd_teb_paramsn.F90` | 39 param + 4 flux | статические параметры TEB (геометрия, материалы, антропогенные потоки) |
| `TSTATE` | `TEB_t` | `src_struct/modd_tebn.F90` | 10 state + 1 reserved | прогностическое состояние TEB (крыша, дорога, стены, каньон, снег) |
| `BOPTS` | `BEM_OPTIONS_t` | `src_struct/modd_bem_optionn.F90` | 5 param | опции BEM (тип кондиционирования, coil, autosize) |
| `BPARAMS` | `BEM_PARAMS_t` | `src_struct/modd_bem_paramsn.F90` | 40 param | статические параметры BEM (полы, HVAC, окна) |
| `BSTATE` | `BEM_t` | `src_struct/modd_bemn.F90` | 9 state + 8 work + 2 reserved | состояние BEM (температуры пола/массы, окна, HVAC-аккумуляторы) |
| `TPN` | `TEB_PANEL_t` | `src_struct/modd_teb_paneln.F90` | 4 param + 1 state | солнечные панели (доля, альбедо, КПД, температура) |
| `TIR` | `TEB_IRRIG_t` | `src_struct/modd_teb_irrign.F90` | 6 param + 13 reserved | ирригация дороги (окно полива) |
| `FORC` | `TEB_FORCING_t` | `src_struct/modd_teb_forcingn.F90` | 22 work | форсинг подшага: 14 сырых величин хоста + 8 производных (давление и функции Экнера, плотность, скорость ветра, солнечное время и положение солнца, прямая/рассеянная SW) |
| `EXT` | `TEB_EXT_SURF_t` | `src_struct/modd_teb_ext_surfn.F90` | 18 work | внешние поверхности: состояние и потоки внешнего сада и зелёной крыши, рассчитанные хостом (шероховатость, альбедо, эмиссивность, температура, влажность, потоки, испарение, сток) |

Итого **439 полей** в одиннадцати контейнерах (231 `DMT` + 208 в десяти типах стенда
`container_fields_inventory.py`). Категории (`param`/`flux`/`state`/
`work`/`reserved`) — контракт из `python_tests/container_fields_inventory.py`;
`DMT` отслеживается отдельным стендом `python_tests/check_diag_container.py`.

---

## 3. Слой контейнеров: модуль TEB_HOST

Для крыши, дороги и стены `TEB_HOST` выделяет массивы по положительным числам
слоёв, переданным в `teb_interface`. При изменении размеров между вызовами
рабочие контейнеры пересоздаются; прогностическое состояние остаётся у хоста
и загружается перед расчётом каждой колонки. Пол и внутренняя масса здания
сохраняют пять слоёв.

`urb_d_rf`, `urb_d_rd`, `urb_d_wl` — необязательные одномерные профили толщин,
общие для всего вызова API. `TEB_CHECK_LAYER_DEPTHS` проверяет их длину,
конечность и положительность до расчёта. Отсутствующий профиль допустим для
пяти слоёв и выбирает штатные толщины. `TEB_FILL_DERIVED` записывает профили в
`TPARAMS%XD_ROOF/XD_ROAD/XD_WALL`, а входные `urb_hcap_*` и `urb_hcon_*`
распространяет на все слои соответствующей поверхности. Начальные температуры
формируются по фактическому числу слоёв. Параметры неймлиста и значения по
умолчанию перечислены в [§2.9 описания переменных](TEB_MSU_variables_description.md#29-layer-configuration).

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
| `TEB_HOST_ENSURE(KNVEC, KROOF, KROAD, KWALL, KFLOOR)` | ленивая аллокация всех одиннадцати контейнеров на поток; пересоздание при смене числа слоёв |
| `TEB_FILL_PARAMS(KSTART, KEND, …)` | запись конфигурации неймлиста в `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` (только окно `KSTART:KEND`) |
| `TEB_FILL_DERIVED(KSTART, KEND, …)` | производные статические параметры (геометрия, СВФ, морфология BEM, оптика окон) |
| `TEB_FILL_FORCING(KSTART, KEND, …)` | форсинг подшага: сырые величины хоста и производные (`FORC`) |
| `TEB_FILL_EXT(KSTART, KEND, PDT, …)` | внешние поверхности: состояние и потоки сада/кровли от хоста (`EXT`), сток приводится к потоку (`/PDT`) |
| `TEB_BIND_STATE(KSTART, KEND, …)` | копирование состояния хоста в окно `TSTATE`/`BSTATE` |
| `TEB_INIT_STATE(KSTART, KEND)` | cold-start состояния на первом модельном шаге (`ntstep == 0`); вызывается из `teb_interface` до `CALL_DRIVER` |
| `TEB_UNBIND_STATE(KSTART, KEND, …)` | копирование обновлённого состояния обратно хосту |
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

**Состояние.** `TEB_BIND_STATE` и `TEB_UNBIND_STATE` копируют значения оператором
`=`, хотя поля контейнеров объявлены указателями. Через обе процедуры проходят
30 полей состояния хоста (20 в `TSTATE`, 10 в `BSTATE`, с учётом компонент снега).
Дополнительно `LSHADE` загружается как опция, а `XALB_WIN` выгружается как
производная диагностика. Владельцем состояния всех колонок остаётся хост.

**Межшаговые коэффициенты.** Обязательная часть подписи `teb_interface` завершается
два обязательных массива `REAL, DIMENSION(nvec), INTENT(INOUT)`:

| аргумент | рабочее поле | начальное значение при `ntstep == 0` | использование следующего подшага |
| --- | --- | --- | --- |
| `teb_ustar_town` | `DMT%XUSTAR_TOWN` | `0.2 m/s` | вход схемы Wang до нового расчёта `u*` |
| `teb_cd_greenroof_atm` | `DMT%XPCD_GREENROOF_ATM` | `XUNDEF` | трение внешней кровли; на первом подшаге срабатывает нейтральная формула |

При `ntstep > 0` оба значения копируются из массивов хоста в `DMT` перед
`CALL_DRIVER`; после физики возвращаются хосту. Cold-start задаёт значения из
таблицы независимо от входных массивов. Offline-драйвер хранит их между всеми
модельными подшагами. Хост при restart восстанавливает оба массива вместе с
остальным состоянием и передаёт ненулевой номер шага; формат restart в этот API
не входит. Внешняя кровля не требует отдельной копии всего `DMT`.

**Необязательные выходы.** После обязательных аргументов API содержит 44
`OPTIONAL, INTENT(OUT)` массива: текущие результаты из `DMT` и снимок дороги
после загрузки/cold-start, до физики (`teb_troad_before`). Пропуск этих выходов
не меняет шаг модели. Экспорт сохраняет единицы и площадную нормировку TEB;
для DEF мощности HVAC выдаются нулями без чтения неопределённой диагностики.
Полный контракт, неактивные режимы и отображение в COSMO — §3.4
`TEB_MSU_coupling_checklist.md`. Внешний хост не получает внутренний `DMT` через
`sfc_teb`: модуль публично экспортирует `teb_interface`, `teb_finalize`,
`teb_real_kind = KIND(0.0)` и `teb_undef` (точное значение параметра `XUNDEF`
с тем же REAL-kind); входы, состояния и результаты имеют явные INTENT.

**Настройка и завершение вызовов.** API принимает скалярный аргумент
`LOGICAL, OPTIONAL, INTENT(IN), VALUE :: teb_snow_check`, общий для блока.
Если он передан, модульный флаг устанавливается перед физикой; если опущен,
сохраняется текущая настройка (начальное значение `.FALSE.`). Offline передаёт
выбор из неймлиста на каждом шаге. Внешний хост может передавать `.TRUE.` при
каждом вызове без прямого доступа к модулю физических параметров.

Три необязательных строковых аргумента `teb_ctype_exch_road`,
`teb_ctype_exch_roof` и `teb_ctype_exch_canyon` выбирают алгоритмы обмена для
всего блока. Для каждого пропущенного аргумента на текущем вызове применяется
`'MASC95'`. Offline передаёт значения `teb_ctype_exch_rd`,
`teb_ctype_exch_rf` и `teb_ctype_exch_canyon` из `&tebopts` соответственно.

`teb_finalize()` закрывает логи, сбрасывает их настройки и освобождает рабочие
контейнеры через `TEB_HOST_FINAL`. Вызов допустим до первого шага и повторно.
Состояние колонок хоста, константы и снежный флаг не меняются. Для продолжения
после освобождения хост передаёт сохранённое состояние с ненулевым `ntstep`;
рабочая память выделяется лениво. Само освобождение не означает cold-start.

**Колонки.** Публичный API принимает блок с `nvec>=1` и окном
`ivstart:ivend`; обрабатываются только точки с `sa_uc(i)>0`. Физические
контейнеры имеют размер 1. Для каждой городской колонки `teb_interface`
загружает её параметры, форсинг, внешние поверхности и состояние в рабочую
позицию 1, вызывает `CALL_DRIVER(icell=1)` и возвращает результаты в позицию
`i` хоста. INOUT вне городской маски окна сохраняются; OUT определены только
для обработанных точек. Пустое окно задаётся как `ivend=ivstart-1`, при
`1<=ivstart<=nvec+1`; физика для него не вызывается. Оба offline-executable используют общий драйвер с `nvec>=1`; размер задаёт `tebopts`.

Границы окна и пять слоёв крыши/дороги/стены/пола проверяются до заполнения
контейнеров. `TEB_HOST_ENSURE` принимает только рабочий размер 1 и проверяет
размеры при повторном использовании памяти. Политика вызова из COSMO — §2.2
`TEB_MSU_coupling_checklist.md`. Физические процедуры остаются поколоночными.

**Offline-конфигурация и вывод.** Общие модули `src_offline/teb_offline_host.F90`,
`teb_offline_namelists.F90`, `teb_offline_driver.F90`, `teb_offline_surfaces.F90`
и `teb_offline_output.F90` обслуживают обе main-программы. Физические параметры
читаются из `tebparams`, шаг `dt` и общие опции — из `tebopts`.
Параметр `teb_ctype_wind` принимает `DEF` или `WANG`. Одноимённый
аргумент API передаёт строку в `TOPTS%CTYPE_WIND`. Состояние и накопители
стока принадлежат каждой колонке хоста. CSV привязан к логическим ID колонок;
при диагностической перестановке логгер получает отображение текущих позиций
в постоянные ID. Без такого отображения сохраняется обычная индексация API.
Формат входов и выходов описан в `TEB_MSU_variables_description.md`.

**Cold-start.** `TEB_INIT_STATE(KSTART, KEND)` заполняет состояние окна на первом
модельном шаге. Вызов находится внутри городского цикла `teb_interface`,
под условием `ntstep == 0`, перед `CALL_DRIVER` для данной колонки.
Offline-драйвер передаёт
`(nstep-1)*INB_ATM + (JSURF_STEP-1)`, coupled-хост — свой номер шага, начинающийся
с нуля. При restart `nstart > 0` процедура не вызывается. `teb_interface` вызывает
`INI_CSTS` перед подготовкой параметров и форсинга на любом шаге, в том числе при
первом вызове с городскими точками и ненулевым номером шага; после `CALL_DRIVER` данной колонки при `ntstep == 0`
синхронизирует `DMT%XTSTOWN_S_NOW` с пост-`TEB_GARDEN` значением `DMT%XTSTOWN_S`. Начальные профили слоёв крыши/стены, температура внутреннего окна и `XT_FLOOR`/`XT_MASS` якорятся на `XTI_BLD` (начальная температура здания из `teb_ti_bld_init`, при отсутствии — `XTCOOL_TARGET`); разрешение `XUNDEF` для `XTI_BLD`/`XQI_BLD` выполняется до заполнения состояния. В `src_ctrl` тот же порядок реализован в `CALL_DRIVER` под `IF (ntstep == 0)`.

---

## 4. Путь контейнеров по цепочке вызовов

Общая цепочка API и физики собирается в статическую библиотеку `libteb.a`.
Offline-хост находится в `src_dev/src_offline/` и линкуется с этой библиотекой;
его массивы `MODD_FORC_ATM` и процедуры чтения/интерполяции в библиотеку
не входят. Общие `.mod` и объекты отделены от offline `.mod` и объектов.
Состав исходников и include-файлов задан в `src_dev/make/teb_sources.mk`,
зависимости модулей — в `src_dev/make/teb_dependencies.mk`. Пути сборки
задаются внешним `BUILD_ROOT`; команды и требования к компилятору — в README.

```
run_teb_offline
  → teb_interface (206: 158 обязательных + 44 OPTIONAL OUT + 4 OPTIONAL IN) src_api/sfc_teb.F90
      → проверка блока/слоёв; маска ivstart:ivend, sa_uc>0
      → TEB_LOG_AT_CADENCE(ntstep)   одно решение для всех блоков шага
      → INI_CSTS             физические константы
      → TEB_HOST_ENSURE(1,…) аллокация 11 контейнеров (первый непустой вызов)
      → цикл по городским колонкам i:
          → TEB_FILL_PARAMS      TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR ← входы i
          → TEB_FILL_DERIVED     производная статика (морфология, оптика окон)
          → TEB_FILL_FORCING     FORC ← форсинг колонки i
          → TEB_FILL_EXT         EXT ← внешние поверхности колонки i
          → TEB_BIND_STATE       TSTATE/BSTATE ← состояние колонки i
          → TEB_INIT_STATE       cold-start, только ntstep == 0
            или загрузка         предыдущие u* и CD кровли, ntstep > 0
          → снимок дороги        OPTIONAL teb_troad_before, после cold-start
          → CALL_DRIVER (27 dummy), icell=1       src_driver/call_driver.F90
              → TEB_GARDEN (29 аргументов)         src_teb/teb_garden.F90
                  читает/пишет TOPTS/TPARAMS/TSTATE/BOPTS/BPARAMS/BSTATE/TPN/TIR/DMT
                  читает FORC и EXT
          → выгрузка u*/CD       значения для следующего подшага хоста
          → TEB_UNBIND_STATE     состояние колонки i ← TSTATE/BSTATE
          → OPTIONAL OUT         текущие результаты в позицию i хоста
          → TEB_LOG_EMIT         KHOST_CELL=i, данные из рабочей позиции 1
  → teb_finalize             закрытие логов и TEB_HOST_FINAL (конец прогона)
```

Контейнеры **не объявляются** в `teb_interface`/`CALL_DRIVER` как локальные:
они — переменные модуля `TEB_HOST` и передаются по цепочке фактическими
аргументами (в подписи `CALL_DRIVER` и `TEB_GARDEN` они — dummy).

Путь каждого рода величин:

| род | путь | пишет | читает |
| --- | --- | --- | --- |
| статика `TOPTS/TPARAMS/BOPTS/BPARAMS/TPN/TIR` | `TEB_FILL_PARAMS`/`TEB_FILL_DERIVED` в `teb_interface` → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` (для каждой городской колонки подшага) | физика (`TEB_GARDEN` и её подпрограммы) |
| состояние `TSTATE/BSTATE` | хост → `TEB_BIND_STATE` → `CALL_DRIVER` → `TEB_GARDEN` → `TEB_UNBIND_STATE` → хост | хост и физика | физика и `TEB_LOG_EMIT` |
| диагностика `DMT` | `TEB_HOST_ENSURE` (аллокация) → `CALL_DRIVER` → `TEB_GARDEN` | физика (`TEB_GARDEN` и её подпрограммы) | `TEB_LOG_EMIT` (CSV), `CALL_DRIVER` (агрегаты) |
| форсинг `FORC` | `ALLOC_TEB_FORCING` ⇒ `TEB_FILL_FORCING` (для каждой колонки подшага) → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` | физика (`TEB_GARDEN` и её подпрограммы), `TEB_LOG_EMIT` (колонки `P_CANYON`, `SOLAR_*`) |
| внешние поверхности `EXT` | `ALLOC_TEB_EXT_SURF` ⇒ `TEB_FILL_EXT` (для каждой колонки подшага) → `CALL_DRIVER` → `TEB_GARDEN` | слой `TEB_HOST` | физика (`TEB_GARDEN` и её подпрограммы), `CALL_DRIVER` (агрегаты альбедо/проверка z0) |

`TEB_GARDEN` получает все одиннадцать контейнеров; `TPARAMS`, `FORC` и `EXT`
объявлены `INTENT(IN)` (только чтение), остальные восемь — `INTENT(INOUT)`.


---

## 5. Контейнеры в деталях

### 5.1 `DMT` — диагностика (`DIAG_MISC_TEB_t`, 231 поле)

Контейнер заполняет **физика**, читают **хост и вывод**; два межшаговых поля
восстанавливаются из аргументов хоста перед физикой (§3).
Поля — `REAL, POINTER, DIMENSION(:)`; длина задаётся при аллокации (`KNVEC`,
в offline-драйвере 1). Состав: поля SURFEX (`XH_WALL_A`, `XRN_ROOF`, `XGFLUX_*`,
`XHVAC_*`), поля TEB-MSU (CBS-диагностики дороги, сад/кровля, снежная ветка) и
запись диагностик ветвей CBS-схемы, использованная дважды (см. ниже).

* аллокация — `DIAG_MISC_TEB_ALLOC(DMT, KNVEC)` (в `TEB_HOST_ENSURE`);
* `NULLIFY`/`ALLOCATE`/`DEALLOCATE` — три зеркальных списка (231/231/231),
  проверяются стендом `check_diag_container.py`;
* у каждого поля есть **производитель** — прямое присваивание либо dummy
  `INTENT(OUT/INOUT)` (в легаси-объявлениях — маркер `!OUT`); это проверяет
  `check_diag_producers.py`. Единственное исключение — `XIRRIG_GARDEN`
  (`reserved`: полив сада не реализован, `GARDEN_CBS` возвращает `PIRRIG_GARDEN = 0.`);
* `XUNDEF`-инициализация 15 полей (выходные диагностики, читаемые до записи)
  перенесена из обёртки в `TEB_GARDEN`;
* агрегаты города (`H_TOWN`, `LE_TOWN`, `RUNOFF_*`, `HSNOW_TOWN` и др.) считает
  `CALL_DRIVER` из величин физики;
* поля MRT пешехода: падающие компоненты коротковолновой радиации на дорогу
  (`XSW_DIR_ROAD`, `XSW_SKY_ROAD`, `XSW_WALL_ROAD`, `XSW_TOT_ROAD`,
  `XSUN_FRAC_ROAD`) и на кровлю (`XSW_DIR_ROOF`, `XSW_SKY_ROOF`,
  `XSW_TOT_ROOF`) пишет `URBAN_SOLAR_ABS`, температуры и их компоненты
  (`XMRT`, `XMRT_SUN`, `XMRT_F_*`, `XMRT_SW_*`, `XMRT_LW_*`, `XMRT_ROOF`) —
  `URBAN_MRT` и `URBAN_MRT_ROOF`, вызываемые из `CALL_DRIVER`; схема —
  `TEB_MSU_MRT_pedestrian_scheme.md`.

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

### 5.2 `TOPTS` — опции TEB (`TEB_OPTIONS_t`, 26 param + 2 work + 3 reserved)

Схемы и флаги: `CGARDEN`/`LGARDEN`, `LGREENROOF(_EXT)`, `CTYPE_GARDEN`/
`CTYPE_GREENROOF`, `CBEM`, `CTYPE_WIND`, `LSOLAR_PANEL`, `LCBS_SCHEME`,
`XTAU_HW_THRESH`/`XTAU_HW_WIDTH`, `NUTC_HOUR`, `XZ0_O_Z0H_GD/GR`,
`CEXCH_ROAD/ROOF/CANYON` и `TZ0H`. Поля `work` (`TTIME`, `XTSTEP`)
заполняет `CALL_DRIVER` на каждом шаге.

`TZ0H` хранит правила тепловой шероховатости дороги, крыши и города.
На время вызова offline-хост передаёт общие правила из `&tebopts` и отношения
`XZ0_O_Z0H_GD/GR` для текущей колонки. При чтении контрольной точки
отношения для сада и зелёной кровли берутся из неймлиста по сохранённым
идентификаторам колонок. Контрольная точка формата 4 хранит ветровой
селектор строкой и читается той же сборкой офлайн-драйвера.

### 5.3 `TPARAMS` — параметры TEB (`TEB_PARAMS_t`, 39 param + 4 flux)

Статическая геометрия и материалы: доли (`XBLD`, `XROAD`, `XGARDEN`,
`XGREENROOF`), `XCAN_HW_RATIO`, `XBLD_HEIGHT`, альбедо/эмиссивность/теплоёмкость/
проводимость крыши-дороги-стен, СВФ, `XZ0_TOWN`/`XZD_TOWN`, застройка
(`XRESIDENTIAL`, `XDT_RES/OFF`). Поля `flux` — антропогенные потоки
(`XH_/XLE_TRAFFIC`, `XH_/XLE_INDUSTRY`). `INTENT(IN)` во всей физике.

`TZ0` содержит шероховатости дороги, крыши и снега для импульса. Offline-хост
передаёт их из параметров блока в `TPARAMS` на время вызова и восстанавливает
предыдущую настройку после него. При restart значения читаются из того же
неймлиста.

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

**Offline-высоты `XZREF`/`XUREF`.** `OL_TIME_INTERP_ATM` строит плотность своей
атмосферы по `XZREF` модуля `MODD_FORC_ATM`, а offline-хост переводит абсолютную
влажность через неё (`qv = XQA/XRHOA`, `rho = XRHOA`). Поэтому
Общий offline-хост задаёт обе высоты из `hlev_teb` сразу после `OL_ALLOC_ATM`,
до первой интерполяции. Общий `CALL_DRIVER` не использует `MODD_FORC_ATM`
и `MODI_OL_*`; физика получает высоты через `FORC`. Для CSV исходный индекс
ячейки передаётся отдельно как `KHOST_CELL`, а данные читаются из рабочей
позиции 1. Периодичность вывода определяется номером модельного шага с отсчётом от нуля,
общим для всех блоков; пустые списки фильтров не создают CSV.


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
| `teb_interface` | `src_api/sfc_teb.F90` | **206** (158 обязательных + 44 OPTIONAL OUT + 4 OPTIONAL IN), включая INOUT `teb_ustar_town`/`teb_cd_greenroof_atm`, выходные массивы ветра, радиации и стока и общие опции снежного фильтра и обмена; собственный интерфейс COSMO описан в чек-листе |
| `CALL_DRIVER` | `src_driver/call_driver.F90` | **27** dummy = 14 transient + 2 host-export + 11 container |
| `TEB_GARDEN` | `src_teb/teb_garden.F90` | **29** = 2 индекса + 11 контейнеров + 5 флагов/строк + 4 коэффициента связи + 1 `KSW` + 2 (`PH_TRAFFIC`, `PTSTEP`) + 2 (`KDAY`, `PTIME`) + 2 проводимости (`PCH_GD`, `PCD_GD`) |

`CALL_DRIVER` — процедура модуля `MODI_CALL_DRIVER`: подпись сверяется
компилятором на каждом вызове. Одиннадцать dummy-контейнеров —
`DMT, TOPTS, TPARAMS, BOPTS, BPARAMS, TSTATE, BSTATE, TPN, TIR, FORC, EXT`; 14 transient — часы,
индексы ячейки, координаты и городская доля; 2 host-export — проводимости сада
`ZCH_GD` (OUT) и `ZCD_GD` (INOUT: предыдущий CD хоста и новый результат).

Пять флагов/строк `TEB_GARDEN` (`OGREENROOF_EXT`, `HIMPLICIT_WIND`, `PBEM_AC`,
`HSNOW_ROOF`, `HSNOW_ROAD`) — опции/параметры вызова, не вынесенные в
контейнеры: они передаются из `CALL_DRIVER` фактическими аргументами.
`KSW` (число спектральных полос) остаётся аргументом: он ограничивает цикл по
единственной полосе `PDIR_SW`/`PSCA_SW`.

---

## 7. Правила и проверки

| стенд | что проверяет |
| --- | --- |
| `python_tests/check_diag_container.py` | списки полей `DMT` (тип, `NULLIFY`, `ALLOCATE`, `DEALLOCATE`): по 231 полю, включая компоненты записи `TEB_CBS_BRANCH_t` для обоих экземпляров (`CAN`, `ATM`); расхождение — ошибка |
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

Референсный кейс — `tests/CAPITOUL` (18 000 шагов): 130 колонок в
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
dummy (было 44/57; 11 контейнеров); `teb_interface` на этапе дедупликации — **154**
(текущая подпись — 206, §6). `DMT` вырос до **208** полей, после удаления незаполняемых `XSOBS`/`XTHBS`/`XALB_TH`
(см. `TEB_MSU_change_history.md`, §5.6, N3) — **205**, после объединения диагностик
ветвей CBS-схемы в запись `TEB_CBS_BRANCH_t` — **207**. Вся дедупликация побитово
идентична эталону: полный A/B (18 000 шагов) — `IDENTICAL`, SHA-256 CSV `30499e1f…`.

| шаг | результат |
| --- | --- |
| Step H1 | форсинг подшага — в контейнере `FORC` (`TEB_FORCING_t`, 22 поля): `TEB_FILL_FORCING` в `TEB_HOST`, `CALL_DRIVER` 57 → 44 (19 плоских dummy → `FORC`) |
| Step H2 | `TEB_GARDEN` принимает `FORC` (65 → 46); `PSW_BANDS` (мёртвый) удалён |
| Step H3 | `teb_log` читает `FORC%XPS`/`XZENITH`/`XAZIM`; `MODD_FORC_ATM` остаётся только у хоста (мост `XZREF`/`XUREF`) |
| Step H4 | внешние поверхности сада/кровли — в контейнере `EXT` (`TEB_EXT_SURF_t`, 18 полей): `TEB_FILL_EXT` в `TEB_HOST`, `CALL_DRIVER` 44 → 27, `TEB_GARDEN` 46 → 29; проводимости `CH`/`CD` остаются плоскими (TEB → хост) |

