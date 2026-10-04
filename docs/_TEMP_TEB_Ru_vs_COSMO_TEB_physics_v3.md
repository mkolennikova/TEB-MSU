# Сравнение физики `src_ctrl` и TEB, сопряжённого с COSMO — область «сад выключен / внешний сад» (v3)

> ⚠️ **ВРЕМЕННЫЙ ФАЙЛ.** Рабочий черновик третьего прохода; подлежит удалению после переноса
> подтверждённых находок в основные документы (`TEB_Ru_source_defects.md` /
> `TEB_Ru_change_history.md`). Предыдущие черновики — `_TEMP_TEB_Ru_vs_COSMO_TEB_physics.md`
> (v1) и `_TEMP_TEB_Ru_vs_COSMO_TEB_physics_v2.md` (v2, сторона A = ветка `main`).

Отличия от v2:

1. **Сторона A — наш рабочий `src_ctrl`** (не `main`): именно это дерево предполагается
   сопрягать, и в нём уже есть правки ветки `MV_devs` (`PAC_AGG_GARDEN` удалён, множитель
   влажности узла каньона перенесён в `TEB_GARDEN`, внешний сад не вызывает прокси-модель).
2. **Область анализа сужена** до сопряжённого режима, в котором сад либо выключен
   (`LGARDEN = .FALSE.`), либо **внешний** (состояние и потоки — от хоста). Всё, что относится
   только к внутренним садовым схемам (`'PROXY_NEW'`/`'PROXY_OLD'`), из выводов исключено.
3. **Добавлена сторона H — хост COSMO** (`COSMO/sfc_teb.f90`, `COSMO/sfc_interface.f90`):
   контракт сопряжения восстановлен по фактическому вызову, а не только по деревьям TEB.
4. Приведены отклонения A от `main` — чтобы отделить унаследованные различия от внесённых
   в ветке `MV_devs`.

**Соглашение о ссылках.** Без префикса — сторона A (`D:\Work\git\TEB-Ru\src_ctrl`); ссылки `src_dev/...` и `docs/...` (сравнения с dev-ветвью и с документами) разрешаются от корня репозитория `D:\Work\git\TEB-Ru`;
префикс `B:` — сторона B (`D:\Work\git\COSMO-TEB_vers_29_09_2026\TEB_in_function_external_forcing_Lom_vers_27_09_2026`);
префикс `H:` — сторона H (`D:\Work\git\COSMO-TEB_vers_29_09_2026\COSMO`).

---

## 0. Метод и основание

| | Сторона | Путь | Состав |
| --- | --- | --- | --- |
| **A** | TEB-Ru, ветка `MV_devs`, дерево `src_ctrl` | `D:\Work\git\TEB-Ru\src_ctrl` (`HEAD = b9592a2`, 2026-10-03, «refactor(garden): move the canyon moisture multiplier out of the garden proxies») | `src_teb` 110, `src_struct` 18, `src_proxi_SVAT` 6, `src_solar` 2, `src_driver` 10 |
| **B** | TEB дерева COSMO-TEB | `D:\Work\git\COSMO-TEB_vers_29_09_2026\TEB_in_function_external_forcing_Lom_vers_27_09_2026` | `src_teb` 110, `src_struct` 18, `src_proxi_SVAT` 6, `src_solar` 2, `src_driver` 13 |
| **H** | хост COSMO (вызывающий код) | `D:\Work\git\COSMO-TEB_vers_29_09_2026\COSMO` | `sfc_teb.f90` (433), `sfc_interface.f90` (6071), `sfc_teb_data.f90` |

Сравнивались каталоги физики `src_teb`, `src_struct`, `src_proxi_SVAT`, `src_solar` и файлы
`src_driver/{call_driver,sfc_teb}.F90`. Ограничения метода — как в v2: нормализация CRLF→LF,
классификация `identical` / «только комментарии» / **`functional`** по двум метрикам (**norm** —
без ведущих пробелов, комментарии сохранены; **code** — комментарии удалены), «блок» =
фрагмент `replace`/`delete`/`insert` из `difflib.SequenceMatcher`.

**Контракт сопряжения.** Хост вызывает `CALL_DRIVER` напрямую, из `SUBROUTINE teb_interface`
(`H:COSMO/sfc_teb.f90:48` → `SUBROUTINE teb_interface`). Список фактических аргументов
(`H:COSMO/sfc_teb.f90:364` → `CALL CALL_DRIVER`, до строки 399) насчитывает 169 аргументов
(183 токена после разделения по запятым: 14 аргументов — срезы вида `teb_troof(i,:)`), что
совпадает с числом dummy-аргументов `CALL_DRIVER` стороны B
(`B:src_driver/call_driver.F90:10` → `SUBROUTINE CALL_DRIVER`), т.е. **хост дёргает ровно
B-интерфейс**. Сад передаётся как «внешняя модель» — все величины сада в
`H:COSMO/sfc_teb.f90:169` → `REAL (KIND = vpp),DIMENSION(nvec) :: teb_qs_gd` помечены `!IN`:

* в вызове — `H:COSMO/sfc_teb.f90:393` → `teb_z0_gd(i), teb_alb_gd(i), 1 - teb_emis_gd(i), teb_ts_gd(i), teb_qs_gd(i), teb_shfl_gd(i)` и
  `H:COSMO/sfc_teb.f90:394` → `teb_lhfl_gd(i), teb_qvfl_gd(i), teb_tch_gd(i), teb_tcm_gd(i)`,
  `H:COSMO/sfc_teb.f90:392` → `teb_shfl_gr(i), teb_lhfl_gr(i), teb_qvfl_gr(i), teb_runoff_gr(i), teb_lgarden`;
* заполняются они из собственных поверхностных полей хоста: `H:COSMO/sfc_interface.f90:2487`
  → `teb_ts_gd_t        (il)    = REAL( t_g_b      (ifull, 1), vpp)` (аналогично `qv_s_b`,
  `-shfl_s_b`, `-lhfl_s_b`, `-qvfl_s_b` на строках 2488–2491), шероховатость —
  `H:COSMO/sfc_interface.f90:1928` → `teb_z0_gd_t       (il)     = REAL( gz0_b              (ifull,1), vpp) / g`;
* обратно хост ожидает **коэффициенты обмена**: `H:COSMO/sfc_interface.f90:2947`
  → `teb_tch_gd          = teb_tch_gd_t          (:)       , & !OUT Heat exchange coefficient for garden`,
  и использует их в своей модели сада/грунта — `H:COSMO/sfc_interface.f90:3383`
  → `tch               = teb_tch_gd_t  (:)       , & !INOUT turbulent transfer coefficient for heat`,
  сохраняя затем в своё поле (`H:COSMO/sfc_interface.f90:3228`, `H:COSMO/sfc_interface.f90:3691`).

**Следствие для области анализа.** В сопряжённом прогоне сад всегда «внешний»: состояние
(`T_s`, `q_v`) и потоки приходят от хоста, а TEB обязан вернуть коэффициенты `teb_tch_gd`/
`teb_tcm_gd`. Наши внутренние садовые схемы (`'PROXY_NEW'`, `'PROXY_OLD'`) в этой области
не участвуют — ниже они упоминаются только там, где влияют на внешнюю ветвь.

---

## 1. Сводная таблица различий

### 1.1. A (`src_ctrl`) против B (COSMO-TEB)

Файлов: A 146, B 149; общих 143.

| каталог | identical | «только комментарии» | **functional** |
| --- | --- | --- | --- |
| `src_teb` | 86 | 0 | 12 |
| `src_struct` | 16 | 0 | 2 |
| `src_proxi_SVAT` | 2 | 0 | 4 |
| `src_solar` | 2 | 0 | 0 |
| `src_driver` | 11 | 0 | 8 |

**Functional-файлы** (блоки по метрикам `code` / `norm`):

| Файл | блоки (code/norm) | в области «сад off / EXT» |
| --- | --- | --- |
| `src_teb/teb_garden.F90` | 45 / 50 | **да** (§3.1, §3.2, §3.3, §3.8) |
| `src_teb/urban_drag.F90` | 10 / 12 | **да** (§3.1, §3.4) |
| `src_teb/avg_urban_fluxes.F90` | 4 / 5 | **да** (§3.1) |
| `src_teb/teb.F90` | 13 / 13 | только интерфейс (§2) |
| `src_teb/bem.F90` | 13 / 13 | **да** (§3.6) |
| `src_teb/urban_solar_abs.F90` | 1 / 2 | **да** (§3.5) |
| `src_teb/modd_surf_par.F90` | 1 / 1 | **да** (§3.3) |
| `src_teb/modi_teb.f90` | 6 / 6 | только интерфейс (§2) |
| `src_teb/modi_teb_garden.f90` | 8 / 8 | только интерфейс (§2) |
| `src_teb/modi_urban_drag.f90` | 4 / 4 | только интерфейс (§2) |
| `src_teb/modi_bem.f90` | 2 / 2 | только интерфейс (§2) |
| `src_teb/modi_avg_urban_fluxes.f90` | 2 / 2 | только интерфейс (§2) |
| `src_struct/teb_garden_struct.F90` | 15 / 15 | **да** (§3.1) |
| `src_struct/modi_teb_garden_struct.f90` | 10 / 10 | только интерфейс (§2) |
| `src_proxi_SVAT/garden.F90` | 8 / 10 | **да** (§3.1) |
| `src_proxi_SVAT/greenroof.F90` | 6 / 8 | нет (вне области; §7 п.3) |
| `src_proxi_SVAT/modi_garden.F90` | 4 / 4 | только интерфейс (§2) |
| `src_proxi_SVAT/modi_greenroof.F90` | 2 / 2 | только интерфейс (§2) |
| `src_driver/call_driver.F90` | 51 / 76 | **да** (§2, §3.7) |
| `src_driver/sfc_teb.F90` | 14 / 15 | **да** (§2) |
| `src_driver/ahf_traffic_now.F90` | 4 / 5 | нет (слой I/O, §4) |
| `src_driver/ol_read_atm.F90` | 8 / 8 | нет (§4) |
| `src_driver/ol_read_atm_ascii.F90` | 9 / 9 | нет (§4) |
| `src_driver/ol_time_interp_atm.F90` | 7 / 7 | нет (§4) |
| `src_driver/open_close_bin_asc_forc.F90` | 3 / 3 | нет (§4) |
| `src_driver/read_surf_atm.F90` | 1 / 1 | нет (§4) |

Только в A: `src_driver/run_teb_offline.F90`, `src_proxi_SVAT/modd_proxi_svat_par.F90`,
`src_teb/teb_garden_with_snow_correction.F90` (§5). Только в B:
`src_driver/call_teb_interface.F90`, `src_driver/driver.F90`, `src_driver/driver_original.F90`,
`src_driver/call_driver_with_comments!.F90`, `src_driver/test_function3.f90`,
`src_teb/urban_drag_test_diff_z0h.F90` (§5).

**Совпадают полностью** (влияние на физику исключено): `surface_ri.F90`, `urban_exch_coef.F90`,
`flxsurf3bx.F`, все `modd_*` (кроме `modd_surf_par`), `mode_thermos`, `*_layer_e_budget`,
`urban_fluxes`, `urban_hydro`, `urban_snow_evol`, `urban_lw_coef`, `snow_cover_1layer`,
`solar_panel`, `src_solar/*`.

---

### 1.2. A (`src_ctrl`) против `main` — что унаследовано, а что внесено в `MV_devs`

146 файлов: 134 identical, **11 functional**:

| Файл | блоки | источник различия |
| --- | --- | --- |
| `src_teb/teb_garden.F90` | 9 | D8-инициализация, флаг `teb_snow_check`, внешняя ветвь сада, фикс `ZRN_GR` (внесено в `MV_devs`) |
| `src_teb/urban_drag.F90` | 2 | D9 (`ZTS_GROUND`), ветвь `IF (OGARDEN_EXT)` |
| `src_teb/avg_urban_fluxes.F90` | 4 | удаление `PAC_AGG_GARDEN` (внесено в `MV_devs`) |
| `src_teb/modi_avg_urban_fluxes.f90` | 2 | там же |
| `src_proxi_SVAT/garden.F90` | 3 | вынос множителя влажности из прокси (внесено в `MV_devs`) |
| `src_proxi_SVAT/modi_garden.F90` | 2 | там же |
| `src_proxi_SVAT/greenroof.F90` | 2 | z0 кровли из намлиста (порт) |
| `src_teb/modd_surf_par.F90` | 1 | флаг `teb_snow_check` (порт) |
| `src_driver/call_driver.F90` | 4 | порт I/O и словников |
| `src_driver/sfc_teb.F90` | 2 | там же |
| `src_driver/run_teb_offline.F90` | 27 | там же |

**Вывод.** Все физические различия A↔B из §3 **унаследованы от `main`** (они же разобраны в
v2); дополнительно в `MV_devs` внесены: удаление `PAC_AGG_GARDEN`, перенос множителя влажности
узла каньона в `TEB_GARDEN` (§3.1) и фикс `ZRN_GD→ZRN_GR` (в B соответствующей ветви нет — §3.8).

---

## 2. Контракт сопряжения: интерфейс и хост

### 2.1. Список аргументов `CALL_DRIVER`

| | число dummy/actual | вывод |
| --- | --- | --- |
| H (вызов) | 169 (`H:COSMO/sfc_teb.f90:364`) | хост дёргает B-интерфейс |
| B (`SUBROUTINE CALL_DRIVER`) | 169 (`B:src_driver/call_driver.F90:10`) | совпадает с H позиционно |
| A (`SUBROUTINE CALL_DRIVER`) | 192 (`src_driver/call_driver.F90:10`) | = B + 23 аргумента |

Позиционное сравнение B↔A даёт **39 расхождений**: 16 совпадающих по смыслу, но
переименованных (суффикс `_EXT`) и 23 «только в A»:

* переименованы (A ↔ B): `zz0_gd_ext`↔`zz0_gd`, `zalb_gd_ext`↔`zalb_gd`,
  `zemis_gd_ext`↔`zemis_gd`, `ztsrad_gd_ext`↔`ztsrad_gd`, `zqv_gd_ext`↔`zqv_gd`,
  `zh_gd_ext`↔`zh_gd`, `zle_gd_ext`↔`zle_gd`, `zevap_gd_ext`↔`zevap_gd`,
  `zrunoff_gd_ext`↔`zrunoff_gd` и симметрично для кровли (`zalb_gr_ext`…`zrunoff_gr_ext`);
  у B аналога `lgarden_ext`/`lgreenroof_ext` нет (в B нет понятия внешней схемы), а
  `teb_lgarden`/`teb_lgreenroof` передаются хостом обычными флагами;
* только в A (23): `lgarden_ext`, `lgreenroof_ext`, `lshade`, `lsolar_panel`, `lpar_rd_irrig`,
  `hroad_dir`, `hwall_opt`, `zroad_dir`, `zresidential`, `zdt_res`, `zdt_off`, `zcap_sys_heat`,
  `zfrac_panel`, `zrd_start_month`, `zrd_end_month`, `zrd_start_hour`, `zrd_end_hour`,
  `zrd_24h_irrig`, `zprod_bld`, `zutc_hour`, `zrn_town`, `zu_canyon`, `zts_road`;
* только в B: **нет** (список B полностью содержится в A с точностью до `_EXT`-имён).

Следствия: (а) для сопряжения хост обязан передать 23 дополнительных аргумента (или
использовать адаптер/свои значения по умолчанию для городских параметров — как в
`B:src_driver/call_driver.F90:671` → `ZZ0         = ZBLD_HEIGHT * 0.075   ! Roughness length (m)`);
(б) наши `*_EXT`-аргументы принимают пакет хоста напрямую, порядок «сад: z0, alb, emis, Ts,
q_v, SHF, LHF, qvfl, tch, tcm, runoff» совпадает с H (`H:COSMO/sfc_teb.f90:393` → `teb_z0_gd(i), teb_alb_gd(i), 1 - teb_emis_gd(i), teb_ts_gd(i), teb_qs_gd(i), teb_shfl_gd(i)`);
(в) **в A нет `LGARDEN_EXT` среди аргументов, ожидаемых хостом**: чтобы включить внешнюю ветвь
сада, адаптеру нужно установить наш флаг (`src_driver/call_driver.F90:239` →
`LOGICAL                           :: LGARDEN_EXT       !IN Flag to use a garden scheme (external)`,
проводка — `CALL TEB_GARDEN_STRUCT (icell, iblock, LGARDEN, LGARDEN_EXT, LGREENROOF, LGREENROOF_EXT, LSOLAR_PANEL,`
в `src_driver/call_driver.F90:1258`).

* **(г) способ включения внешнего сада различается между нашими ветвями:** `src_ctrl` — флагом
  `LGARDEN_EXT` (`src_driver/call_driver.F90:239`), `src_dev` — строкой типа `TYPE_GARDEN`
  (`src_dev/src_driver/call_driver.F90:280` → `CHARACTER(LEN=9)                  :: TYPE_GARDEN       !IN garden model type ('PROXY_OLD','PROXY_NEW','EXT')`,
  рабочая ветвь — `src_dev/src_driver/call_driver.F90:1327` → `IF (TYPE_GARDEN == 'EXT' .OR. TYPE_GARDEN == 'EXT_NEU') THEN`).
  У хоста COSMO сад всегда внешний, поэтому адаптеру нужно либо выставить флаг (для `src_ctrl`),
  либо передать тип `'EXT'` (для `src_dev`).
### 2.2.

| величина | H | B | A |
| --- | --- | --- | --- |
| `T_s` сада | `!IN` (`H:COSMO/sfc_teb.f90:168`) | `INTENT(INOUT)` (`B:src_teb/teb_garden.F90:167`) | `INTENT(IN)` (в `*_EXT`) |
| `q_v` сада | `!IN` (`H:COSMO/sfc_teb.f90:169`) | `INTENT(INOUT)` (`B:src_teb/teb_garden.F90:168`) | `INTENT(IN)` |
| потоки `SHF/LHF/qvfl/runoff` | `!IN` (`H:COSMO/sfc_teb.f90:170`) | `INTENT(INOUT)` (`B:src_teb/teb_garden.F90:169`) | `INTENT(IN)` |
| коэффициенты `tch`/`tcm` | `!OUT` (`H:COSMO/sfc_interface.f90:2947`) | выходы `ZCH_GD/ZCD_GD` (`B:src_driver/call_driver.F90:227`) | те же выходы (`src_driver/call_driver.F90:248`) |

Практически `INTENT(INOUT)` в B безвреден: прокси B эти величины не перезаписывает (строки
потоков закомментированы, `B:src_proxi_SVAT/garden.F90:129` → `!PRN_GARDEN(:) = (1.-0.15) * PSW(:)`),
`PTS_GARDEN` тоже не меняется. Поэтому ужесточение до `INTENT(IN)` в A не мешает сопряжению, но
**обязывает** адаптер не рассчитывать на обновление хостом этих массивов.

---

## 3. Физика в области «сад выключен / внешний сад»

### 3.1. Внешний сад: эквивалентность схем и три расхождения

**Схема B (в сопряжённом прогоне — всегда внешний сад).** Прокси вызывается безусловно
(`B:src_teb/teb_garden.F90:799` → `IF (TOP%LGARDEN) THEN`, вызов `B:src_teb/teb_garden.F90:802`
→ `CALL GARDEN(HIMPLICIT_WIND, TOP%TTIME, PTSUN, PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, &`)
и получает пакет хоста (`PQV_GD`, `PH_GD`, `PLE_GD`, `PEVAP_GD`, `PRUNOFF_GD` — `INTENT(INOUT)`,
`B:src_teb/teb_garden.F90:168` → `REAL, DIMENSION(:)  , INTENT(INOUT) :: PQV_GD             ! garden specific humidity`).
Прокси не моделирует поверхность: потоки закомментированы
(`B:src_proxi_SVAT/garden.F90:129` → `!PRN_GARDEN(:) = (1.-0.15) * PSW(:)`), `PAC_GARDEN` не
затирается (`B:src_proxi_SVAT/garden.F90:151` → `!PAC_GARDEN(:) = 0.`), и строятся только
`PQSAT_GARDEN = QSAT(PTS_GARDEN)` (`B:src_proxi_SVAT/garden.F90:155` →
`PQSAT_GARDEN(:) = QSAT(PTS_GARDEN(:),PPS(:))`), `PAC_AGG_GARDEN = PAC_GARDEN`
(`B:src_proxi_SVAT/garden.F90:163` → `PAC_AGG_GARDEN(:) = PAC_GARDEN(:)`) и
`PHU_AGG_GARDEN = clamp(PQV_GD/PQSAT_GARDEN)` (`B:src_proxi_SVAT/garden.F90:164` →
`PHU_AGG_GARDEN(:) = PQV_GD(:)/PQSAT_GARDEN(:)`, клиппинги — `B:src_proxi_SVAT/garden.F90:166` →
`PHU_AGG_GARDEN(:) = MIN(PHU_AGG_GARDEN(:), 1.)` и `B:src_proxi_SVAT/garden.F90:167` →
`PHU_AGG_GARDEN(:) = MAX(PHU_AGG_GARDEN(:), 0.01)`).
Узел влажности каньона — `B:src_teb/avg_urban_fluxes.F90:503` →
`ZINTER = PAC_RD_WAT(JJ) * PDF_RD(JJ) * PDELT_RD(JJ) * ZRD(JJ) + PAC_AGG_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ` и
`B:src_teb/avg_urban_fluxes.F90:505` → `+ PQSAT_GD   (JJ) * PAC_AGG_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ)`.

**Схема A (после правок `MV_devs`).** Для `OGARDEN_EXT` прокси-модель не вызывается вовсе
(`src_teb/teb_garden.F90:834` → `IF (.NOT. OGARDEN_EXT) THEN` — ветвь `ELSE` строит только
`src_teb/teb_garden.F90:849` → `ZQSAT_GD(:)  = QSAT(ZTSRAD_GD(:), PPS(:))`, трение и нули);
множитель для внутренних режимов — β, его возвращает сама прокси-модель
(`src_proxi_SVAT/garden.F90:188` → `PHU_AGG_GARDEN(:) = XPHU_GD`),
а внешний режим перезаписывает его отношением хоста (`src_teb/teb_garden.F90:870` →
`IF (OGARDEN_EXT) THEN`, `src_teb/teb_garden.F90:876` → `ZHU_AGG_GD(:) = PQV_GD_EXT(:)/ZQSAT_GD(:)`,
клиппинги — `src_teb/teb_garden.F90:874` и `src_teb/teb_garden.F90:875`); потоки берутся от
хоста (`src_teb/teb_garden.F90:871` → `ZH_GD(:) = PH_GD_EXT(:)` и далее). Узел влажности —
`src_teb/avg_urban_fluxes.F90:501` →
`ZINTER = PAC_RD_WAT(JJ) * PDF_RD(JJ) * PDELT_RD(JJ) * ZRD(JJ) + PAC_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ) + PAC_TOP(JJ)`
и `src_teb/avg_urban_fluxes.F90:503` → `+ PQSAT_GD   (JJ) * PAC_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ)`.

**Эквивалентность.** Формула множителя, её числитель (`q_v` хоста) и знаменатель (`q_sat(T_s)`
хостовой поверхности) и клиппинги `[0.01, 1]` в A и B совпадают; удаление `PAC_AGG_GARDEN`
(правка `MV_devs`) не меняет чисел, так как в B `PAC_AGG_GARDEN` тождественно равен
`PAC_GARDEN`, а в A используется `PAC_GD` — та же величина (в A она приходит из `URBAN_DRAG`,
в B — через пасс-тру прокси). Проверено прогонами: внутренний режим и `'EXT'` в A дают CSV,
побитово совпадающий с прогонами до этой правки.

**Расхождение 1 — источник z0 для коэффициентов сада.** A считает коэффициенты сада в ветви
`IF (OGARDEN_EXT)` по **своему** z0: `src_teb/urban_drag.F90:618` → `IF (OGARDEN_EXT) THEN`,
вызов `src_teb/urban_drag.F90:620` →
`CALL URBAN_EXCH_COEF(TOP%CZ0H, 4., PTS_GARDEN, PQS_GARDEN, PEXNS, PEXNA,` с `PZ0_GARDEN_EXT`,
где `src_proxi_SVAT/modd_proxi_svat_par.F90:118` → `REAL :: urb_z0_gdn   = XZ0_GD` (дефолт 0.8);
B использует z0 хоста: `B:src_teb/urban_drag.F90:589` → `IF (TOP%LGARDEN) THEN`,
`B:src_teb/urban_drag.F90:593` → `PU_LOWCAN, PZ0_GARDEN, ZRI, PCD_GARDEN, ZCDN_GARDEN,         &`
(`PZ0_GARDEN` — вход, `H:COSMO/sfc_interface.f90:1928` даёт `teb_z0_gd_t = gz0_b/g`).
⇒ **адаптер обязан подать `teb_z0_gd` в `PZ0_GARDEN_EXT`**, иначе коэффициенты и проводимость
сада разойдутся с B (при совпадении z0 — совпадут). **Статус (частично выполнено):** в обеих ветвях добавлена проверка z0 при включённом внешнем саде — `src_driver/call_driver.F90:693` → `IF (LGARDEN .AND. LGARDEN_EXT) THEN` и `src_dev/src_driver/call_driver.F90:1336` → `IF (LGARDEN .AND. (TYPE_GARDEN == 'EXT' .OR. TYPE_GARDEN == 'EXT_NEU')) THEN` (нефизическое значение → `STOP 1`); передача значения `teb_z0_gd` остаётся задачей адаптера сопряжения.

**Расхождение 2 — A возвращает хосту нулевые `tch`/`tcm` сада.** В A (до правки) коэффициенты
обнулялись в блоке сада `TEB_GARDEN` для всех режимов, включая внешний: `PCH_GD`/`PCD_GD`
присваивались нули сразу после вызова модели сада (та же пара строк стоит и в ветви
выключенного сада), поэтому выходные `ZCH_GD`/`ZCD_GD` (`src_driver/call_driver.F90:248` →
`REAL,DIMENSION(1)                 :: ZCH_GD            !OUT garden transfer coefficient for heat (extern`)
уходят нулями → хостовые `teb_tch_gd`/`teb_tcm_gd` (`H:COSMO/sfc_interface.f90:2947`) нулевые, а
хост использует их в своей модели сада (`H:COSMO/sfc_interface.f90:3383`). В B обнуления нет
(`B:src_teb/teb_garden.F90:172` → `REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD             ! drag coeifficient for heat`),
поэтому хост получает коэффициенты, посчитанные `URBAN_DRAG` с его z0. ⇒ **обязательно к
выравниванию**: для `OGARDEN_EXT` не обнулять `PCH_GD`/`PCD_GD`, а отдавать значения из
`URBAN_DRAG` (внешний режим) или моделью сада (внутренний). **Статус: исправлено.** Пара коэффициентов теперь возвращается самой моделью сада: в `src_dev` — `GARDEN`/`GARDEN_TAU` (`src_dev/src_proxi_SVAT/garden.F90:600` → `IF (TYPE_GARDEN == 'PROXY_NEW') THEN` для нейтральной пары, `src_dev/src_proxi_SVAT/garden.F90:604` → `PPCD_GD(:) = 0.` для Боуэн-прокси), в `src_ctrl` — прокси-Боуэн (`src_proxi_SVAT/garden.F90:183` → `PPCD_GD(:) = 0.`); `TEB_GARDEN` только передаёт их в списке аргументов вызова (`src_dev/src_teb/teb_garden.F90:1081` → `PCD_GD, PCH_GD, ZHU_AGG_GD )`, `src_teb/teb_garden.F90:842` → `PCD_GD, PCH_GD, ZHU_AGG_GD )`). Во внешнем режиме прокси не вызывается, и в массивах остаются значения `URBAN_DRAG`. Проверено прогонами: CSV с садом не изменился побайтово (в `src_dev` — все четыре режима, включая `'PROXY_OLD'`).

**Расхождение 3 (проверка, а не дефект) — блок D8 в EXT не срабатывает.** В A он закрыт
условием `src_teb/teb_garden.F90:579` → `IF (.NOT. OGARDEN_EXT) THEN`, а ветвь `ELSE` берёт
данные хоста (`src_teb/teb_garden.F90:587` → `ZALB_GD   = PALB_GD_EXT`, `src_teb/teb_garden.F90:589`
→ `ZTSRAD_GD = PTSRAD_GD_EXT`) ⇒ при EXT значения `TEB_VEG_PROPERTIES` не подставляются и данные
хоста не перекрываются (в v2 §3.1 это был риск для конфигурации «сад включён без `*_EXT`» —
в нашей области он не реализуется). **Статус:** действий не требуется.

**Уточнение к v2 §3.2 (`PAC_GARDEN = XUNDEF`).** В обеих версиях `PAC_GARDEN` объявлен
**`INTENT(OUT)`** (`src_struct/teb_garden_struct.F90:386` →
`REAL, DIMENSION(:)  , INTENT(OUT)   :: PAC_GARDEN         ! green area conductance`,
`B:src_struct/teb_garden_struct.F90:385` — то же), поэтому разница «сброс входящего значения
активен / закомментирован» (`src_struct/teb_garden_struct.F90:663` → `PAC_GARDEN       = XUNDEF  ! green area conductance`
против `B:src_struct/teb_garden_struct.F90:666` → `!PAC_GARDEN       = XUNDEF  ! green area conductance`)
на сопряжённый результат **не влияет**: проводимость сада всегда считает TEB (`URBAN_DRAG`),
а не приходит от хоста.

### 3.2. Сад выключен: ветви «нулей» в A и B

При `TOP%LGARDEN = .FALSE.` физика сада не исполняется; сравнимы только ветви инициализации:

| величина | A | B |
| --- | --- | --- |
| потоки, сток, `EVAP` | `src_teb/teb_garden.F90:887` → `ZRN_GD    (:) = 0.` … `:889` → `ZRUNOFF_GD(:) = 0.` | `B:src_teb/teb_garden.F90:819` → `PH_GD     (:) = 0.` … `:823` → `PRUNOFF_GD(:) = 0.` |
| `T_s` сада | `src_teb/teb_garden.F90:894` → `ZTSRAD_GD (:) = XUNDEF` | `B:src_teb/teb_garden.F90:825` → `PTSRAD_GD (:) = XUNDEF` |
| множитель влажности и `q_sat` | `src_teb/teb_garden.F90:901` → `ZQSAT_GD   (:) = XUNDEF`, `:899` → `ZHU_AGG_GD (:) = XUNDEF` | `B:src_teb/teb_garden.F90:832` → `ZHU_AGG_GD (:) = XUNDEF` |
| тэг-ветви | `src_teb/teb_garden.F90:883` → `ZRN_GD(:) =  DMT%XABS_SW_GARDEN(:) + DMT%XABS_LW_GARDEN(:)` (ветвь EXT) | — (в B тэг-ветви нет) |

**Вывод:** при выключенном саде различия A↔B по садовым величинам не влияют ни на что: обе
версии обнуляют (или помечают `XUNDEF`) те же переменные, а узел влажности умножается на
`ZGD = 0` (`src_teb/avg_urban_fluxes.F90:501` — `PAC_GD(JJ) * PHU_AGG_GD(JJ) * ZGD(JJ)`).
Садовая ветвь A дополнительно требует, чтобы `OGARDEN_EXT` оставался `.FALSE.` — иначе
включается внешний режим §3.1.

### 3.3. Снежная коррекция альбедо/эмиссивности/`Ts` снега (флаг `teb_snow_check`)

* B активна безусловно: `B:src_teb/teb_garden.F90:519` → `WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )`
  (дорога) и `B:src_teb/teb_garden.F90:527` → `WHERE ( WSNOW_ROOF_CHECK(:)<1.E-8 * PTSTEP )` (крыша).
* A — за флагом: `src_teb/modd_surf_par.F90:67` → `LOGICAL :: teb_snow_check = .FALSE.`;
  guard вокруг вычисления `WSNOW_ROAD_CHECK` — `src_teb/teb_garden.F90:487` → `IF (teb_snow_check) THEN`;
  guard вокруг самой коррекции — `src_teb/teb_garden.F90:517` → `IF (teb_snow_check) THEN`
  (внутри `src_teb/teb_garden.F90:519` → `WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )`).

**Вывод:** для сопоставимости сопряжённого прогона с B нужно задать `teb_snow_check = .TRUE.`
(по умолчанию `.FALSE.` — поведение «базовой» модели). Значимость подтверждена измерением:
включение флага меняет часть строк базового прогона (см. запись в
`docs/TEB_Ru_change_history.md`, §0) — то есть это не косметика.

### 3.4. `ZTS_GROUND` в `URBAN_DRAG`

* A вычисляет её (фикс D9): `src_teb/urban_drag.F90:517` →
  `ZTS_GROUND(:) = PTS_ROAD(:)   * T%XROAD(:)   / (T%XROAD(:) + T%XGARDEN(:)) &` (и
  `src_teb/urban_drag.F90:520` → `ZTS_GROUND(:) = PTS_ROAD(:)`, ветвь `ELSEWHERE`), после чего
  она входит в бюджет импульса каньона (`src_teb/urban_drag.F90:553` →
  `+ (ZTS_GROUND  (JJ) - PT_LOWCAN(JJ)) * PAC_ROAD  (JJ)`).
* B вычисления не содержит (остался только закомментированный предшественник —
  `B:src_teb/urban_drag.F90:500` → `!  ZTS_GROUND(:) = PTS_ROAD(:) * T%XROAD  (:)/(T%XROAD(:)+T%XGARDEN(:)) + PTS_GARDEN(:) * T%XGARDEN  (:)`),
  а использует её ниже (`B:src_teb/urban_drag.F90:524` →
  `+ (ZTS_GROUND  (JJ) - PT_LOWCAN(JJ)) * PAC_ROAD  (JJ)`) ⇒ в B читается неинициализированная память.

**Вывод:** ожидаемое численное расхождение в бюджете импульса каньона (в т.ч. при выключенном
саде: `ZTS_GROUND` усредняет дорогу и сад). Вариант A — исправленный; для паритета с B
пришлось бы воспроизводить его дефект, что не рекомендуется (см. §7 п.2).

### 3.5. Жалюзи/солнцезащита

* A управляется флагом `LSHADE` (словник `teb_lshade`, дефолт `.FALSE.`): активны
  `src_teb/urban_solar_abs.F90:469` → `G_EFF_SHAD(:) = OSHADE(:).AND.(ZDIR_SW_WL(:) + ZSCA_SW_WL(:) > XWIN_SW_MAX)`
  и `src_teb/urban_solar_abs.F90:474` → `OSHAD_DAY(:)  = G_EFF_SHAD(:) .OR. OSHAD_DAY(:)`
  (принудительные `.FALSE.` закомментированы — `src_teb/urban_solar_abs.F90:470`, `:475`);
  в блоке сада окно-менеджер вызывается с флагом —
  `src_teb/teb_garden.F90:636` → `CALL WINDOW_SHADING_AVAILABILITY(B%LSHADE, B%XTI_BLD, DMT%XTCOOL_TARGET, GSHADE)`
  (жёсткое `GSHADE(:) = .FALSE.` закомментировано — `src_teb/teb_garden.F90:640`); в драйвере
  `src_driver/call_driver.F90:1001` → `!LSHADE         = .FALSE.      ! Are shading devices being used ?`.
* B выключает жалюзи принудительно в четырёх местах: `B:src_teb/urban_solar_abs.F90:470` →
  `G_EFF_SHAD(:) = .FALSE.`, `B:src_teb/urban_solar_abs.F90:475` → `OSHAD_DAY(:) = .FALSE.`,
  `B:src_teb/teb_garden.F90:608` → `GSHADE(:) = .FALSE.`, `B:src_driver/call_driver.F90:1032` →
  `LSHADE              = .FALSE.      ! Are shading devices being used ?`.

**Вывод:** при дефолте (`teb_lshade = .FALSE.`) поведение A совпадает с B; при
`teb_lshade = .TRUE.` расходятся тепловые потоки зданий (`TI_BLD`, `HVAC_*`, `H_TOWN`, `LE_TOWN`)
— для сопряжения оставлять дефолт либо передавать флаг хоста.

### 3.6. BEM: сурвентиляция, порог AC, накопители, инициализация

| место | A | B |
| --- | --- | --- |
| «механическая» сурвентиляция | `src_teb/bem.F90:406` → `ZNAT_VENT(JJ) =  5.0*T%XBLD_HEIGHT(JJ)/3600.` | `B:src_teb/bem.F90:410` → `ZNAT_VENT(JJ) =  0.25*T%XBLD_HEIGHT(JJ)/3600.` (и `B:src_teb/bem.F90:472` → `ZNAT_VENT(JJ) =  0.25*T%XBLD_HEIGHT(JJ)/3600.`) |
| порог включения работы AC | `src_teb/bem.F90:417` → `ZTI_BLD_OPEN(JJ) >  DMT%XTHEAT_TARGET (JJ) + 4.)` (и `src_teb/bem.F90:420`) | `B:src_teb/bem.F90:421` → `ZTI_BLD_OPEN(JJ) >  DMT%XTHEAT_TARGET (JJ))` (и `B:src_teb/bem.F90:426`) |
| второй вызов `GET_NAT_VENT` (секция энергопотребления) | без разбора `CNATVENT` — `src_teb/bem.F90:458` → `CALL GET_NAT_VENT(B%XTI_BLD(JJ), PT_CAN(JJ), PU_CAN(JJ), B%XGR(JJ), &` (внутри `IF (GNAT_VENT(JJ))`, `src_teb/bem.F90:456` → `IF (GNAT_VENT(JJ)) THEN`) | под разбором — `B:src_teb/bem.F90:465` → `IF (B%CNATVENT(JJ)=='AUTO') THEN`, `B:src_teb/bem.F90:469` → `ELSE IF (B%CNATVENT(JJ)=='MECH') THEN` |
| накопители тепла пола/массы | локальные (`ZDQS_FL`, `ZDQS_MA`) | выходные аргументы — `B:src_teb/bem.F90:197` → `REAL, DIMENSION(:),   INTENT(OUT)  :: PDQS_FL` |
| первый шаг: пол и масса | присваиваний нет (крыша/дорога/стены инициализируются — `src_driver/call_driver.F90:933` → `ZT_ROOF(:,1)   = t  ! roof layers temperatures`, `src_driver/call_driver.F90:940` → `ZT_ROAD  (:,1) = t  ! road layers temperatures`) | `B:src_driver/call_driver.F90:990` → `ZT_FLOOR (:,1) = ZTCOOL_TARGET  ! building floor temperature`, `B:src_driver/call_driver.F90:996` → `ZT_MASS  (:,1) = ZTCOOL_TARGET  ! building mass temperature` |

**Вывод:** три численных различия (0.25 против 5.0 объёмов/час; порог AC без `+4 K`;
инициализация пола/массы) влияют на `TI_BLD`, `PHU_BLD`, `HVAC_*` и далее на городской бюджет.
Сигнал проявляется и без сада, поэтому для сопряжённого прогона нужно либо выравнивать BEM по B,
либо явно зафиксировать расхождение в документации.

### 3.7. `call_driver`: умолчания, единицы измерения, момент инициализации

| что | A | B |
| --- | --- | --- |
| шероховатость города | словник: `src_driver/call_driver.F90:673` → `CALL URB_AERO_PARAMS(urb_z0_town, urb_zd_town, ZBLD_HEIGHT, ZZ0, XZD_TOWN)` (дефолт `0.1H` — `src_proxi_SVAT/modd_proxi_svat_par.F90:105` → `CHARACTER(LEN=16), PARAMETER :: XURB_Z0_TOWN_DEF = '0.1H'`); B-вариант закомментирован — `src_driver/call_driver.F90:665` → `!ZZ0         = ZBLD_HEIGHT * 0.075   ! Roughness length (m)` | `B:src_driver/call_driver.F90:671` → `ZZ0         = ZBLD_HEIGHT * 0.075   ! Roughness length (m)` |
| теплофизика крыши/дороги | из конфигурации + жёсткие числа: `src_driver/call_driver.F90:711` → `ZHC_ROOF(1,1) = ZHC_ROOF_S(1)   ! volumetric heat capacity (J m-3 K-1) (external layer)`, `src_driver/call_driver.F90:714` → `ZHC_ROOF(1,4) = 1127845.62      ! volumetric heat capacity (J m-3 K-1)` | целиком из конфигурации: `B:src_driver/call_driver.F90:688` → `ZHC_ROOF(1,4) = ZHC_ROOF_S(1)   ! volumetric heat capacity (J m-3 K-1)` |
| толщины слоёв | `src_driver/call_driver.F90:722` → `ZD_ROOF(1,2)  = 0.098      ! thickcness (m)` | `B:src_driver/call_driver.F90:706` → `ZD_ROOF(1,2)  = 0.1568     ! thickcness (m)` |
| первый шаг | `src_driver/call_driver.F90:904` → `IF (ntstep == 1) THEN` | `B:src_driver/call_driver.F90:944` → `IF (ntstep == 0) THEN` |
| сток города | умножение на `dt` закомментировано — `src_driver/call_driver.F90:1386` → `!ZRUNOFF_TOWN  = ZRUNOFF_TOWN * dt` | активно — `B:src_driver/call_driver.F90:1522` → `ZRUNOFF_TOWN  = ZRUNOFF_TOWN * dt` |
| проводимость сада | объявлена и передаётся, не присваивается — `src_driver/call_driver.F90:424` → `REAL,DIMENSION(1)  :: ZAC_GARDEN        ! garden aerodynamical conductance` | то же — `B:src_driver/call_driver.F90:404` → `REAL,DIMENSION(1)  :: ZAC_GARDEN        ! garden aerodynamical conductance` |

**Вывод.** Для сопоставимости прогонов: задать `urb_z0_town = '0.075H'` (наш резолвер принимает
форму `<знач>H`), выровнять толщины и теплофизику поверхностей и единицы стока и **согласовать
нумерацию шага** (`ntstep == 1` в A против `== 0` в B — при вызове хостом с нумерацией B первый
шаг A окажется «не первым»). `ZAC_GARDEN` как вход не использовать: значение приходит из
`URBAN_DRAG` (в обеих версиях переменная не присваивается).

### 3.8. Внесено в `MV_devs` и как это проявляется при сопряжении

* **Удаление `PAC_AGG_GARDEN`** (A: `src_teb/avg_urban_fluxes.F90:501` против B:
  `B:src_teb/avg_urban_fluxes.F90:503`): интерфейс различается именем dummy, числа — нет (§3.1).
* **Перенос множителя влажности в `TEB_GARDEN`** (A: `src_teb/teb_garden.F90:876` →
  `ZHU_AGG_GD(:) = PQV_GD_EXT(:)/ZQSAT_GD(:)` против B: `B:src_proxi_SVAT/garden.F90:164` →
  `PHU_AGG_GARDEN(:) = PQV_GD(:)/PQSAT_GARDEN(:)`): формула и входы те же, меняется место
  вычисления. Интерфейсная цена: прокси A больше не возвращает множитель —
  `src_proxi_SVAT/modi_garden.F90:22` → `PPCD_GD, PPCH_GD, PHU_AGG_GARDEN      )`
  (соответствует `modi_garden` стороны A) ; заготовка COSMO-входа сохранена закомментированной —
  `src_proxi_SVAT/modi_garden.F90:47` → `!REAL, DIMENSION(:)  , INTENT(IN)    :: PQV_GD             ! garden specific humidity`.
* **Фикс `ZRN_GD → ZRN_GR`** в ветви внешней зелёной кровли: в A ветвь дополнена
  (`src_teb/teb_garden.F90:938` → `ZRN_GR(:) =  DMT%XABS_SW_GREENROOF(:) + DMT%XABS_LW_GREENROOF(:)`
  внутри `src_teb/teb_garden.F90:929` → `IF (OGREENROOF_EXT) THEN`); в B этой ветви нет вовсе ⇒
  осознанное дополнение, а не расхождение с ошибкой.
* **Новые ключи/флаги A** (`urb_z0_gdn`, `urb_alb_gdn`, `urb_emis_gdn`, `urb_z0_o_z0h_gdn`,
  `proxy_phu_gdn`, `proxy_phu_grf` (**переименованы** из `urb_phu_*`: параметры принадлежат
  модулю прокси и читаются только им), `teb_snow_check`, `teb_lshade`): при сопряжении значения должны
  приходить от хоста (в первую очередь `z0` сада — §3.1) либо оставаться на дефолтах базового
  поведения. Ключи `proxy_phu_gdn`/`proxy_phu_grf` в сопряжённом режиме **не участвуют**: внешний сад
  берёт отношение влажности от хоста (§3.1), а `src_ctrl` эти ключи вообще не читает
  (значение β — константа `src_proxi_SVAT/modd_proxi_svat_par.F90:84` → `REAL, PARAMETER :: XPHU_GD  = 0.8`).

---

## 4. Различия, не влияющие на сопряжённый результат

* **Слой I/O и форсинга** (`ol_read_atm`, `ol_read_atm_ascii`, `ol_time_interp_atm`,
  `open_close_bin_asc_forc`, `read_surf_atm`, `ahf_traffic_now`, а также наши
  `src_driver/run_teb_offline.F90` и `src_proxi_SVAT/modd_proxi_svat_par.F90`): при сопряжении
  входные данные даёт хост, наши читалки не используются.
* **Интерфейсные модули** (`modi_teb.f90`, `modi_teb_garden.f90`, `modi_teb_garden_struct.f90`,
  `modi_urban_drag.f90`, `modi_bem.f90`, `modi_avg_urban_fluxes.f90`, `modi_garden.F90`,
  `modi_greenroof.F90`): различия дословно повторяют сигнатуры процедур (§2) и не влияют на числа.
* **`INTENT`/имена `*_EXT`** (§2.2), перестановки строк и комментарии, отладочные `!print*`
  в B, `ZDQS_*` ↔ `PDQS_*`.
* **Артефакты**: `.mod`-файлы, варианты вне сборки (§5).

---

## 5. Файлы и артефакты вне сборки

| Файл | Где | Комментарий |
| --- | --- | --- |
| `src_teb/teb_garden_with_snow_correction.F90` | только A | в сборке не участвует; функционал реализован флагом `teb_snow_check` (§3.3) |
| `src_driver/run_teb_offline.F90`, `src_proxi_SVAT/modd_proxi_svat_par.F90` | только A | наш оффлайн-драйвер и носитель ключей словника; при сопряжении не используются |
| `src_driver/call_teb_interface.F90` | только B | тестовый драйвер (задаёт дефолты `teb_z0_gd = 0.8`, `teb_alb_gd = 0.15`, `teb_emis_gd = 0.9`, `teb_ts_gd = 275.`, `teb_qs_gd = 0.00380` — `B:src_driver/call_teb_interface.F90:237` → `teb_z0_gd(:) = 0.8`) |
| `src_driver/driver.F90`, `driver_original.F90`, `test_function3.f90` | только B | автономные варианты драйвера |
| `src_driver/call_driver_with_comments!.F90` | только B | в сборку не входит; содержит активную строку `ZAC_GARDEN = ZTCH_GARDEN * ZU_CANYON` |
| `src_teb/urban_drag_test_diff_z0h.F90` | только B | экспериментальный вариант |

---

## 6. Итог: чек-лист выравнивания для сопряжённого прогона (сад выключен или внешний)

**Обязательно (иначе сопряжённый прогон некорректен):**

1. **Адаптер вызова.** Хост вызывает `CALL_DRIVER` с B-интерфейсом (§0); наш `CALL_DRIVER` имеет
   192 аргумента (§2.1) ⇒ передать 23 дополнительных (`lgarden_ext`, `lgreenroof_ext`, `lshade`,
   `lsolar_panel`, `lpar_rd_irrig`, `hroad_dir`, `hwall_opt`, `zroad_dir`, `zresidential`,
   `zdt_res`, `zdt_off`, `zcap_sys_heat`, `zfrac_panel`, пять `zrd_*`, `zprod_bld`, `zutc_hour`,
   `zrn_town`, `zu_canyon`, `zts_road`) и учесть переименование `*_EXT` (§2.1).
2. **Сад, расхождение 1 — выполнено (частично):** в `CALL_DRIVER` обеих ветвей добавлена
   проверка `ZZ0_GD_EXT` (`src_driver/call_driver.F90:693`, `src_dev/src_driver/call_driver.F90:1338`):
   нефизическое значение при включённом внешнем саде завершает работу. Подача самого
   значения `teb_z0_gd` в `PZ0_GARDEN_EXT` остаётся задачей адаптера сопряжения (§3.1).
3. **Сад, расхождение 2 — выполнено:** пару коэффициентов считает и возвращает сама модель
   сада (`src_dev/src_proxi_SVAT/garden.F90:597`, `src_proxi_SVAT/garden.F90:179`),
   `TEB_GARDEN` только передаёт её в списке аргументов вызова (`src_dev/src_teb/teb_garden.F90:1079`);
   во внешнем режиме хост получает коэффициенты `URBAN_DRAG` (§3.1).
4. **Снежная коррекция:** `teb_snow_check = .TRUE.` (§3.3).
5. **Нумерация шага и единицы:** согласовать `ntstep` и сток (§3.7).
6. **BEM:** выровнять по B (0.25 объём/час, порог без `+4 K`, инициализация пола/массы, `PDQS_*`)
   либо зафиксировать расхождение (§3.6).

**По конфигурации:**

7. `urb_z0_town = '0.075H'`, толщины слоёв 0.001/0.1568/0.2112/0.1568/0.001 и теплофизика
   из конфигурации поверхности, `teb_lshade = .FALSE.` (§3.5, §3.7).
8. Сад: `LGARDEN = .TRUE.` и `LGARDEN_EXT = .TRUE.` (наш флаг; хост его не передаёт — §2.1в);
   при выключенном саде `LGARDEN_EXT` держать `.FALSE.` (§3.2).

**Осознанно оставляем своё (с записью в документации):**

9. `ZTS_GROUND` (фикс D9) — в B читается неинициализированная память (§3.4).
10. Дополнение ветви внешней кровли (`ZRN_GR`), удаление `PAC_AGG_GARDEN`, перенос множителя
    влажности в `TEB_GARDEN` (§3.8) — числа не меняют.

---

## 7. Открытые вопросы

1. **Флаги схем `teb_lgarden`/`teb_lgreenroof`** хост передаёт как `!IN` (`H:COSMO/sfc_teb.f90:392`);
   при сопряжении значения `LGARDEN`/`LGARDEN_EXT` в A должны быть с ними согласованы (§2.1в).
2. **`ZTS_GROUND`**: оставляем наш фикс (рекомендуется) или переносим вычисление в B —
   решение с авторами COSMO-TEB; до решения ожидаемое расхождение в бюджете импульса каньона (§3.4).
3. **Кровля.** Дублирующая величина `PAC_AGG_GREENROOF` удалена, а её CSV-колонка заменена
   **живой** проводимостью `PAC_GREENROOF` (OUT-аргумент `call_driver` в той же позиции +
   `TEB_INTERFACE`/драйвер + колонка; значения те же, что у удалённой, кроме ветви «кровля
   выключена», где теперь `0.` вместо `XUNDEF`) — см. `docs/TEB_Ru_change_history.md`, §0.
   Отдельным пунктом остаётся `PHU_AGG_GREENROOF` в прокси — такой же дубликат (`= PPHU_GR`
   во всех ветвях `src_dev`). Проводимость кровли в уравнения не входит (проверено), поэтому в
   сопряжённом режиме `PAC_GREENROOF = 0` совпадает с B и ни на что не влияет.
4. **`ZAC_GARDEN`/`ZTCH_GARDEN`:** в собираемых драйверах `ZAC_GARDEN` не присваивается
   (§3.7), «входной путь» проводимости сада жив только в невключаемом
   `call_driver_with_comments!.F90` (B) ⇒ при сопряжении не использовать.
5. **Сверка коэффициентов (частично выполнено):** качественная часть закрыта — возвращаемая
   хост-величина теперь *и есть* то, что посчитала модель сада (`GARDEN`/`GARDEN_TAU` отдают
   пару напрямую, §3.1), а прогоны с садом остались бит-в-бит. **Остаётся** количественная
   сверка «A == B» при одинаковых `teb_z0_gd` — одношаговый тест в сопряжённом стенде (п.6).
6. **Стенд сопряжения:** нужен прогон COSMO-TEB (эталон) и сопряжённый прогон A на одинаковых
   настройках, со сравнением `T_CANYON`, `Q_CANYON`, `RN_TOWN`, `TI_BLD`, `HVAC_*` — «до/после»
   выравнивания; в репозитории такого стенда пока нет (в оффлайн-стендах сопряжение не проверяется).

---

## 8. Контроль достоверности цитат

Все ссылки вида `файл:строка` в этом документе сверены автоматически тем же способом, что в v2:
для каждой ссылки проверено, что в файле соответствующей стороны существует строка с указанным
номером, а при наличии якоря (запись вида `ссылка` → `текст`) — что этот текст входит в указанную
строку (сравнение по тексту с нормализованными пробелами, CRLF→LF). Сокращения вида `:NNN`
разрешаются по последней полной ссылке.

**Результат: 155 ссылок (120 — с якорем), 4 сокращения `:NNN` разрешены, ошибок — 0.**

Ссылки на сторону A даны в состоянии коммита `b9592a2`; ссылки на `src_dev/...` приведены только
в §3.1 (сравнение «как сделано в dev-ветви»); ссылки на B и H — по рабочей копии
`COSMO-TEB_vers_29_09_2026` (§0). При первом прогоне контроля были уточнены три ссылки
(`modd_proxi_svat_par.F90`, `modi_garden.F90`) — номера строк сдвинулись после правок
`MV_devs` в самом дереве A. После правок §3.1 (устранение расхождений 1–2) автоматически
уточнена **21 ссылка** на `src_teb/teb_garden.F90` и `src_driver/call_driver.F90` — номера
сдвинулись из-за внесённых строк. После выноса коэффициентов обмена в прокси (расхождение 2,
реализация B) уточнено ещё **16 ссылок** в `src_teb/teb_garden.F90`,
`src_driver/call_driver.F90` и `src_proxi_SVAT/modi_garden.F90`.








---


