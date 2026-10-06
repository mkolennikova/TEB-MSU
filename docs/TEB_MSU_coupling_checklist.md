# Сопряжение TEB-MSU с COSMO-TEB: контракт, матрица соответствия и чек-лист выравнивания

> Code state: commit `6e5b46e` (2026-10-04), branch `MV_devs`. Сторона A — деревья этого
> репозитория; сторона B — `D:\Work\git\COSMO-TEB_vers_29_09_2026\TEB_in_function_external_forcing_Lom_vers_27_09_2026`
> (рабочая копия от 2026-09-29); сторона H — `D:\Work\git\COSMO-TEB_vers_29_09_2026\COSMO`
> (хост, вызывающий код).
>
> Документ заменил временные черновики `_TEMP_TEB_MSU_vs_COSMO_TEB_physics*.md` (v1–v3); они
> удалены, причина записана в `TEB_MSU_change_history.md`, §0.

Документ отвечает на один вопрос: **что нужно сделать, чтобы сопряжённый прогон нашего TEB с
хостом COSMO был корректен и сопоставим с TEB стороны B.** В отличие от удалённых черновиков он
постоянный: обновляется вместе с изменениями контракта сопряжения.

---

## 1. Стороны, область анализа и метод

| | сторона | путь | состав |
| --- | --- | --- | --- |
| **A_ctrl** | «первое» дерево (предполагается сопрягаемым) | `src_ctrl` | `src_teb`, `src_struct`, `src_proxi_SVAT`, `src_solar`, `src_driver` |
| **A_dev** | рабочее дерево ветки `MV_devs` | `src_dev` | то же |
| **B** | TEB дерева COSMO-TEB | `D:\Work\git\COSMO-TEB_vers_29_09_2026\TEB_in_function_external_forcing_Lom_vers_27_09_2026` | то же |
| **H** | хост COSMO | `D:\Work\git\COSMO-TEB_vers_29_09_2026\COSMO` | `sfc_teb.f90` (433 строки), `sfc_interface.f90` (6071), `sfc_teb_data.f90` |

**Соглашение о ссылках.** Без префикса — сторона **A_ctrl** (пути разрешаются от `src_ctrl`);
путь `src_dev/…` — рабочее дерево; префикс `B:` — сторона B; префикс `H:` — сторона H
(корень `D:\Work\git\COSMO-TEB_vers_29_09_2026`). Ссылки `docs/…` — от корня репозитория.

**Область анализа** — сопряжённый режим, в котором сад либо выключен (`LGARDEN = .FALSE.`), либо
**внешний**: состояние (`T_s`, `q_v`), потоки и шероховатость приходят от хоста, а TEB обязан
вернуть коэффициенты обмена. Внутренние садовые схемы (`'PROXY_NEW'`, `'PROXY_OLD'`) упоминаются
только там, где влияют на внешнюю ветвь. В дереве B садовый прокси вызывается всегда и сам
является внешней ветвью (`B:src_teb/teb_garden.F90:799` → `IF (TOP%LGARDEN) THEN`, вызов
`B:src_teb/teb_garden.F90:802` → `CALL GARDEN(HIMPLICIT_WIND, TOP%TTIME, PTSUN, PPEW_A_COEF_LOWCAN, PPEW_B_COEF_LOWCAN, &`), но модели поверхности в нём нет: бовэновские потоки и β
закомментированы (`B:src_proxi_SVAT/garden.F90:129` → `!PRN_GARDEN(:) = (1.-0.15) * PSW(:)`), а
множитель влажности строится из влагосодержания хоста
(`B:src_proxi_SVAT/garden.F90:164` → `PHU_AGG_GARDEN(:) = PQV_GD(:)/PQSAT_GARDEN(:)`, клиппинги —
`B:src_proxi_SVAT/garden.F90:166` → `PHU_AGG_GARDEN(:) = MIN(PHU_AGG_GARDEN(:), 1.)` и
`B:src_proxi_SVAT/garden.F90:167`).

**Метод.** Сравнение исходников с нормализацией CRLF→LF: классификация файлов (совпадает
побайтово / различается по коду) и, для каждой величины контракта, разбор того, **кто её
вычисляет** (хост, `URBAN_DRAG` или прокси-модель) и **по какой формуле**. Прогоны стендов и их
числа — в `TEB_MSU_change_history.md`; здесь приводятся только величины, различающие стороны.

---

## 2. Контракт сопряжения

### 2.1 Вход и выход `CALL_DRIVER`

| | число аргументов | источник |
| --- | --- | --- |
| H (вызов) | 169 | `H:COSMO/sfc_teb.f90:364` → `CALL CALL_DRIVER (ntstep, i, iblock, dt, teb_year, teb_month, teb_day, teb_hour, teb_min, teb_sec, teb_seconds, sa_uc(i), lon_teb(i), &` |
| B (`SUBROUTINE CALL_DRIVER`) | 169 | `B:src_driver/call_driver.F90:10` → `SUBROUTINE CALL_DRIVER` |
| **A_ctrl** | **192** (= B + 23) | `src_driver/call_driver.F90` |
| **A_dev** | **198** (= B + 29) | `src_dev/src_driver/call_driver.F90` |

Хост вызывает B-интерфейс позиционно, поэтому адаптеру нужно подать 23 (`A_ctrl`) или 29
(`A_dev`) дополнительных аргумента и учесть переименование «внешних» величин: у B они без
суффикса (`zz0_gd`, `zalb_gd`, `ztsrad_gd`, `zh_gd`, `zle_gd`, `zevap_gd`, `zrunoff_gd` и
симметрично для кровли), у нас — с суффиксом `_ext` (`zz0_gd_ext`, `zalb_gd_ext`, …).

Дополнительные аргументы `A_ctrl` (23): `lgarden_ext`, `lgreenroof_ext`, `lshade`, `lsolar_panel`,
`lpar_rd_irrig`, `hroad_dir`, `hwall_opt`, `zroad_dir`, `zresidential`, `zdt_res`, `zdt_off`,
`zcap_sys_heat`, `zfrac_panel`, `zrd_start_month`, `zrd_end_month`, `zrd_start_hour`,
`zrd_end_hour`, `zrd_24h_irrig`, `zprod_bld`, `zutc_hour`, `zrn_town`, `zu_canyon`, `zts_road`;
плюс две OUT-диагностики (`zcd_terra`, `zch_terra`).

К `A_dev` относительно `A_ctrl` добавлены: `TYPE_GARDEN`, `TYPE_GREENROOF` (строки режима вместо
логических флагов), `ZQV_GR_EXT` (`src_dev/src_driver/call_driver.F90:272` → `REAL,DIMENSION(1)                 :: ZQV_GR_EXT        !IN greenroof specific humidity (external model)`),
`ZZ0_GR_EXT` (`src_dev/src_driver/call_driver.F90:266` → `REAL,DIMENSION(1)                 :: ZZ0_GR_EXT        !IN greenroof roughness length (external model)`),
`HZ0_TOWN`/`HZD_TOWN` (`src_dev/src_driver/call_driver.F90:234` → `CHARACTER(LEN=16)                 :: HZ0_TOWN          !IN z0 of the urban surface (0.5 | 0.5m | 0.1H | H/3 | <name>)`)
и OUT-диагностики CBS-схемы `ZCD_GARDEN_ATM`/`ZCH_GARDEN_ATM`
(`src_dev/src_driver/call_driver.F90:387` → `REAL,DIMENSION(1)                 :: ZCD_GARDEN_ATM         !OUT`).
Пара, уходящая хосту как `teb_tch_gd`/`teb_tcm_gd`, в обеих ветвях называется одинаково —
`ZCH_GD`/`ZCD_GD` (`src_driver/call_driver.F90:248` → `REAL,DIMENSION(1)                 :: ZCH_GD            !OUT garden transfer coefficient for heat (external model)`,
`src_dev/src_driver/call_driver.F90:290`).

**Способ включения внешнего режима** различается: `A_ctrl` — логическим `LGARDEN_EXT`
(`src_driver/call_driver.F90:239` → `LOGICAL                           :: LGARDEN_EXT       !IN Flag to use a garden scheme (external)`),
которого хост не передаёт; `A_dev` — строкой типа
(`src_dev/src_driver/call_driver.F90:280` → `CHARACTER(LEN=9)                  :: TYPE_GARDEN       !IN garden model type ('PROXY_OLD','PROXY_NEW','EXT')`).
Флаг сада хост подаёт сам (`H:COSMO/sfc_teb.f90:392` → `teb_shfl_gr(i), teb_lhfl_gr(i), teb_qvfl_gr(i), teb_runoff_gr(i), teb_lgarden,`).
Обе ветви проверяют нефизическую шероховатость при включённом внешнем саде:
`src_driver/call_driver.F90:693` → `IF (LGARDEN .AND. LGARDEN_EXT) THEN` и
### 2.2 Что хост подаёт и что получает обратно

| величина | H | B | A_ctrl | A_dev |
| --- | --- | --- | --- | --- |
| `z0` сада | `!IN` (`H:COSMO/sfc_teb.f90:165` → `REAL (KIND = vpp),DIMENSION(nvec) :: teb_z0_gd                      !IN garden roughness`), заполняется из `gz0_b` (`H:COSMO/sfc_interface.f90:1928` → `teb_z0_gd_t       (il)     = REAL( gz0_b              (ifull,1), vpp) / g`) | вход `URBAN_DRAG` (`B:src_teb/urban_drag.F90:593` → `PU_LOWCAN, PZ0_GARDEN, ZRI, PCD_GARDEN, ZCDN_GARDEN,         &`) | `PZ0_GARDEN_EXT` (`src_teb/urban_drag.F90:622` → `PU_LOWCAN, PZ0_GARDEN_EXT, ZRI, PCD_GARDEN, ZCDN_GARDEN, &`) | то же (`src_dev/src_teb/urban_drag.F90:794`) |
| `q_v` сада | `!IN` (`H:COSMO/sfc_teb.f90:169` → `REAL (KIND = vpp),DIMENSION(nvec) :: teb_qs_gd                      !IN garden surface specific humidity`), из `qv_s_b` (`H:COSMO/sfc_interface.f90:2488` → `teb_qs_gd_t        (il)    = REAL( qv_s_b     (ifull, 1), vpp)`) | вход `PQV_GD` (`B:src_teb/teb_garden.F90:168` → `REAL, DIMENSION(:)  , INTENT(INOUT) :: PQV_GD             ! garden specific humidity`) | вход `ZQV_GD` | вход `ZQV_GD` |
| `T_s` сада | `!IN` (`H:COSMO/sfc_teb.f90:168`) | не меняется (`B:src_proxi_SVAT/garden.F90:158` → `!PTS_GARDEN(:) = PT_LOWCAN(:)`) | не меняется | не меняется |
| потоки сада | `!IN` (`H:COSMO/sfc_teb.f90:170`, вызов `H:COSMO/sfc_teb.f90:393` → `teb_z0_gd(i), teb_alb_gd(i), 1 - teb_emis_gd(i), teb_ts_gd(i), teb_qs_gd(i), teb_shfl_gd(i),        &`) | не меняются (`B:src_proxi_SVAT/garden.F90:132` → `!PH_GARDEN (:) = 0.2 * PRN_GARDEN(:)`) | берутся от хоста (`src_teb/teb_garden.F90:871` → `ZH_GD(:) = PH_GD_EXT(:)`) | берутся от хоста |
| `T_s` кровли | `!IN` (`H:COSMO/sfc_teb.f90:159` → `REAL (KIND = vpp),DIMENSION(nvec) :: teb_ts_gr                      !IN greenroof radiative surface temp. (snow free)`), из `t_g_b` (`H:COSMO/sfc_interface.f90:2479` → `teb_ts_gr_t        (il)    = REAL( t_g_b      (ifull, 1), vpp)`) | не меняется (`B:src_proxi_SVAT/greenroof.F90:161` → `!PTS_GREENROOF(:) = PTA(:)`) | не меняется | не меняется |
| потоки кровли | `!IN` (`H:COSMO/sfc_teb.f90:160`, `H:COSMO/sfc_teb.f90:163`, вызов `H:COSMO/sfc_teb.f90:392`) | не меняются (`B:src_proxi_SVAT/greenroof.F90:136` → `!PH_GREENROOF (:) = 0.5 * PRN_GREENROOF(:)`) | берутся от хоста (`src_teb/teb_garden.F90:930` → `ZH_GR(:) = PH_GR_EXT(:)`) | берутся от хоста (`src_dev/src_teb/teb_garden.F90:1236`) |
| `z0` кровли | **нет** | жёстко `0.01` (`B:src_proxi_SVAT/greenroof.F90:149` → `PUW_GREENROOF(:) = - (XKARMAN/LOG(PUREF(:)/0.01))**2 * PVMOD(:)**2`) | словник `urb_z0_grf` (`src_proxi_SVAT/greenroof.F90:152` → `PUW_GREENROOF(:) = - (XKARMAN/LOG(PUREF(:)/urb_z0_grf))**2 * PVMOD(:)**2`) | **вход** `ZZ0_GR_EXT` (`src_dev/src_teb/urban_drag.F90:844` → `PZ0_GREENROOF_EXT,                  &`) |
| `q_v` кровли | **нет** | `0.3` (`B:src_proxi_SVAT/greenroof.F90:165` → `PHU_AGG_GREENROOF(:) = 0.3   ! surface humidity set to 30%`) | `XPHU_GR = 0.3` (`src_proxi_SVAT/greenroof.F90:168` → `PHU_AGG_GREENROOF(:) = XPHU_GR`, объявление `src_proxi_SVAT/modd_proxi_svat_par.F90:97` → `REAL, PARAMETER :: XPHU_GR  = 0.3`) | **вход** `PQV_GR_EXT` (`src_dev/src_teb/teb_garden.F90:1216` → `ZHU_AGG_GR(:) = PQV_GR_EXT(:)/ZQSAT_GR(:)`) |
| пара `tch`/`tcm` сада (обратно) | `!OUT` (`H:COSMO/sfc_teb.f90:173` → `REAL (KIND = vpp),DIMENSION(nvec) :: teb_tch_gd                    !IN Heat exchange coefficient for garden`), используется хостом (`H:COSMO/sfc_interface.f90:3383` → `tch               = teb_tch_gd_t  (:)       , & !INOUT turbulent transfer coefficient for heat`) | пара `PCH_GD`/`PCD_GD` (`B:src_teb/teb_garden.F90:172` → `REAL, DIMENSION(:)  , INTENT(OUT)   :: PCH_GD             ! drag coeifficient for heat`) | `ZCH_GD`/`ZCD_GD` (`src_driver/call_driver.F90:248`) | те же (`src_dev/src_driver/call_driver.F90:290`) |

**Следствие 1.** Для внешней кровли `A_dev` требует двух величин, которых у H **нет** — `z0` и
`q_v` кровли: адаптер обязан их синтезировать (ближайшие аналоги — `gz0_b` и `qv_s_b` того же
тайла, как для сада) или подставить константы B (`0.01`, `0.3`). `A_ctrl` этих входов не требует.

---

## 3. Матрица: `A_ctrl` и `A_dev` против B

Читается так: «величина (кто считает в B) — чем это в наших ветвях — вердикт для сопряжения».

### 3.1 Сад

| аспект | B | A_ctrl | A_dev | вердикт |
| --- | --- | --- | --- | --- |
| стратифицированные коэффициенты | `URBAN_EXCH_COEF` безусловно (`B:src_teb/urban_drag.F90:589` → `IF (TOP%LGARDEN) THEN`, вызов `B:src_teb/urban_drag.F90:593` → `PU_LOWCAN, PZ0_GARDEN, ZRI, PCD_GARDEN, ZCDN_GARDEN,         &`) | то же в ветви флага (`src_teb/urban_drag.F90:618` → `IF (OGARDEN_EXT) THEN`, вызов `src_teb/urban_drag.F90:620` → `CALL URBAN_EXCH_COEF(TOP%CZ0H, 4., PTS_GARDEN, PQS_GARDEN, PEXNS, PEXNA,`) | то же для `'EXT'`, но отношения z0/z0h из словника: `src_dev/src_teb/urban_drag.F90:792` → `CALL URBAN_EXCH_COEF(TOP%CZ0H, TOP%XZ0_O_Z0H_GD, PTS_GARDEN, PQS_GARDEN, PEXNS, PEXNA,`, `'EXT_NEU'` — нейтральные (`src_dev/src_teb/urban_drag.F90:770` → `IF (TOP%CTYPE_GARDEN == 'EXT_NEU') THEN`) | ✅ совпадает при `urb_z0_o_z0h_gdn = 4.` (дефолт: `src_dev/src_proxi_SVAT/modd_proxi_svat_par.F90:86` → `XZ0_O_Z0H_GD = 4.0`); `'EXT_NEU'` аналога в B не имеет |
| обнуление пары в EXT | пара не обнуляется (`B:src_teb/teb_garden.F90:172`) | **закрыто**: прокси не вызывается (`src_teb/teb_garden.F90:834`), пара остаётся от `URBAN_DRAG` | **закрыто** (`src_dev/src_teb/teb_garden.F90:1081` → `PCD_GD, PCH_GD, ZHU_AGG_GD`) | ✅ совпадает |
| трение | нейтральная формула с жёстким z0 = 0.1 м (`B:src_proxi_SVAT/garden.F90:145` → `PUW_GARDEN(:) = - (XKARMAN/LOG(PZ_LOWCAN(:)/0.1))**2 * PU_LOWCAN(:)**2`) | **та же формула** (`src_proxi_SVAT/garden.F90:154` → `PUW_GARDEN(:) = - (XKARMAN/LOG(PZ_LOWCAN(:)/0.1))**2 * PU_LOWCAN(:)**2`) | моментный коэффициент режима (`src_dev/src_teb/teb_garden.F90:1100` → `ZUW_GD(:) = - PCD_GD(:) * PU_LOWCAN(:)**2`; фолбэк `src_dev/src_teb/teb_garden.F90:1102` → `PCD_GD(:) = GARDEN_PCD_NEUTRAL(PZ_LOWCAN(:), PZ0_GARDEN_EXT(:))`) | ✅ `A_ctrl`; ❌ `A_dev` — см. §5 п.2 |
| множитель влажности каньона | `clamp(q_v/q_sat(Ts))` в прокси (`B:src_proxi_SVAT/garden.F90:164`) | то же, но в `TEB_GARDEN` (`src_teb/teb_garden.F90:876` → `ZHU_AGG_GD(:) = PQV_GD_EXT(:)/ZQSAT_GD(:)`) | то же | ✅ совпадает |
| внутренние режимы | — | прокси возвращает нули пары (`src_proxi_SVAT/garden.F90:183` → `PPCD_GD(:) = 0.`) и β = 0.8 (`src_proxi_SVAT/garden.F90:188` → `PHU_AGG_GARDEN(:) = XPHU_GD`, объявление `src_proxi_SVAT/modd_proxi_svat_par.F90:84` → `REAL, PARAMETER :: XPHU_GD  = 0.8`) | прокси возвращает пару и PHU модели (`src_dev/src_proxi_SVAT/garden.F90:604`, `src_dev/src_proxi_SVAT/modd_proxi_svat_par.F90:100` → `proxy_phu_gdn = 0.7             ! garden surface relative humidity (-)`) | в области сопряжения не участвуют |
| проводимость сада | прокси не меняет (строка закомментирована: `B:src_proxi_SVAT/garden.F90:151` → `!PAC_GARDEN(:) = 0.`) | прокси обнуляет (`src_proxi_SVAT/garden.F90:160` → `PAC_GARDEN(:) = 0.`) | прокси возвращает `ZCA_GD` (`src_dev/src_proxi_SVAT/garden.F90:404`) | во внешнем режиме прокси не вызывается ⇒ влияния нет (§5 п.4) |

### 3.2 Кровля

| аспект | B | A_ctrl | A_dev | вердикт |
| --- | --- | --- | --- | --- |
| прокси вызывается | да (`B:src_teb/teb_garden.F90:844` → `IF (TOP%LGREENROOF) THEN`) | да (`src_teb/teb_garden.F90:914`) | **нет** для `'EXT'`/`'EXT_NEU'`: ветвь прокси закрыта `ELSE` (`src_dev/src_teb/teb_garden.F90:1198`), мёртвая ветка `CASE` удалена | разная механика, одинаковый результат |
| потоки, `T_s` | хостовые (`B:src_proxi_SVAT/greenroof.F90:136`, `B:src_proxi_SVAT/greenroof.F90:161` закомментированы) | хостовые (`src_teb/teb_garden.F90:930`) | хостовые (`src_dev/src_teb/teb_garden.F90:1236`) | ✅ совпадает |
| проводимость | `0.` (`B:src_proxi_SVAT/greenroof.F90:155` → `PAC_GREENROOF(:) = 0.`) | `0.` (`src_proxi_SVAT/greenroof.F90:158`) | `0.` во внешнем режиме (`src_dev/src_teb/teb_garden.F90:1219` → `PAC_GR(:)     = 0.      ! no implicit coupling of an external surface (as in COSMO-TEB)`) | ✅ совпадает |
| трение | нейтральная формула, жёсткий z0 = 0.01 м (`B:src_proxi_SVAT/greenroof.F90:149`) | та же формула со словниковым `urb_z0_grf` (`src_proxi_SVAT/greenroof.F90:152`), дефолт = 0.01 | коэффициент режима (`src_dev/src_teb/teb_garden.F90:1211` → `ZUW_GR(:) = - PCD_GREENROOF_ATM(:) * PVMOD(:)**2`; фолбэк `src_dev/src_teb/teb_garden.F90:1213`) | ✅ `A_ctrl`; ❌ `A_dev` |
### 3.3 Общие расхождения (вне садовой области, но влияют на сопряжённый прогон)

| аспект | B | у нас | вердикт |
| --- | --- | --- | --- |
| снежная коррекция альбедо/эмиссивности/`Ts` | активна безусловно (`B:src_teb/teb_garden.F90:519` → `WHERE ( WSNOW_ROAD_CHECK(:)<1.E-8 * PTSTEP )`, крыша — `B:src_teb/teb_garden.F90:527`) | за флагом `teb_snow_check = .FALSE.` (`src_dev/src_teb/modd_surf_par.F90:67` → `LOGICAL :: teb_snow_check = .FALSE.`; guard `src_dev/src_teb/teb_garden.F90:600` → `IF (teb_snow_check) THEN`; в `A_ctrl` тот же флаг и значение по умолчанию: `src_teb/modd_surf_par.F90:67`) | задать `.TRUE.` для сопоставимости |
| первый подшаг | `IF (ntstep == 0) THEN` (`B:src_driver/call_driver.F90:944`) | `IF (ntstep == 1) THEN` (`src_dev/src_driver/call_driver.F90:1047`, `A_ctrl` — `src_driver/call_driver.F90:904`) | согласовать нумерацию с хостом |
| сток города | умножение на `dt` активно (`B:src_driver/call_driver.F90:1522` → `ZRUNOFF_TOWN  = ZRUNOFF_TOWN * dt`) | строка закомментирована (`src_dev/src_driver/call_driver.F90:1641` → `!ZRUNOFF_TOWN  = ZRUNOFF_TOWN * dt`, `A_ctrl` — `src_driver/call_driver.F90:1386`) | согласовать единицы |
| шероховатость города | `ZZ0 = ZBLD_HEIGHT * 0.075` (`B:src_driver/call_driver.F90:671` → `ZZ0         = ZBLD_HEIGHT * 0.075   ! Roughness length (m)`) | из словника (дефолт `0.1H`): `A_ctrl` — `src_driver/call_driver.F90:673` → `CALL URB_AERO_PARAMS(urb_z0_town, urb_zd_town, ZBLD_HEIGHT, ZZ0, XZD_TOWN)`; `A_dev` — строки интерфейса, `src_dev/src_driver/call_driver.F90:829` → `CALL URB_AERO_PARAMS(HZ0_TOWN, HZD_TOWN, ZBLD_HEIGHT, ZBLD, ZFAI, ZZ0, ZZDU)` | конфигурация: `'0.075H'` |
| инициализация пола и внутренней массы | `ZT_FLOOR(!:,1) = ZTCOOL_TARGET` (`B:src_driver/call_driver.F90:990`), `ZT_MASS` (`B:src_driver/call_driver.F90:996`) | присваиваний нет; инициализируются крыша и дорога (`src_dev/src_driver/call_driver.F90:1076` → `ZT_ROOF(:,1)   = t  ! roof layers temperatures`, `src_dev/src_driver/call_driver.F90:1083`) | выравнивать (§6 п.6) |
| BEM: сурвентиляция | `0.25` объёма/час (`B:src_teb/bem.F90:410` → `ZNAT_VENT(JJ) =  0.25*T%XBLD_HEIGHT(JJ)/3600.`) | `5.0` объёма/час (`src_dev/src_teb/bem.F90:406` → `ZNAT_VENT(JJ) =  5.0*T%XBLD_HEIGHT(JJ)/3600.`) | выравнивать (§6 п.6) |
| BEM: порог включения работы AC | `> XTHEAT_TARGET` (`B:src_teb/bem.F90:421` → `ZTI_BLD_OPEN(JJ) >  DMT%XTHEAT_TARGET (JJ))`) | `> XTHEAT_TARGET + 4.` (`src_dev/src_teb/bem.F90:417` → `ZTI_BLD_OPEN(JJ) >  DMT%XTHEAT_TARGET (JJ) + 4.)`) | выравнивать (§6 п.6) |
| BEM: второй вызов `GET_NAT_VENT` | под разбором режима (`B:src_teb/bem.F90:465` → `IF (B%CNATVENT(JJ)=='AUTO') THEN`) | без разбора (`src_dev/src_teb/bem.F90:456` → `IF (GNAT_VENT(JJ)) THEN`) | вне садовой области, фиксируется здесь |
| BEM: накопители тепла пола/массы | выходные аргументы (`B:src_teb/bem.F90:197` → `REAL, DIMENSION(:),   INTENT(OUT)  :: PDQS_FL`) | локальные `ZDQS_*` | вне садовой области |
| жалюзи | принудительно выключены (`B:src_teb/urban_solar_abs.F90:470` → `G_EFF_SHAD(:) = .FALSE.`, `B:src_teb/urban_solar_abs.F90:475`, `B:src_teb/teb_garden.F90:608` → `GSHADE(:) = .FALSE.`, `B:src_driver/call_driver.F90:1032` → `LSHADE              = .FALSE.      ! Are shading devices being used ?`) | флаг `teb_lshade`, дефолт `.FALSE.` (`src_dev/src_teb/urban_solar_abs.F90:469` → `G_EFF_SHAD(:) = OSHADE(:).AND.(ZDIR_SW_WL(:) + ZSCA_SW_WL(:) > XWIN_SW_MAX)`, `src_dev/src_teb/urban_solar_abs.F90:474`) | при дефолте совпадает |
---

## 4. Чек-лист выравнивания для сопряжённого прогона

**Обязательно (иначе прогон некорректен):**

1. **Адаптер вызова.** Хост дёргает B-интерфейс (§2.1): подать 23 (`A_ctrl`) или 29 (`A_dev`)
   дополнительных аргумента, учесть суффикс `_ext` и завести заглушки под OUT-диагностики.
2. **Шероховатость сада.** Подать `teb_z0_gd` (у H — `gz0_b`) в `PZ0_GARDEN_EXT`; нефизическое
   значение при включённом внешнем саде уже останавливает прогон
   (`src_driver/call_driver.F90:693`).
3. **Входы кровли для `A_dev`.** Синтезировать `teb_z0_gr` и `teb_qs_gr` (аналоги `gz0_b`,
   `qv_s_b`) либо подставить константы B (`0.01`, `0.3`) — §2.2, §5 п.3.
4. **Пара коэффициентов сопряжения** `teb_tch_gd`/`teb_tcm_gd`: в обеих ветвях уже отдаётся
   корректно, во внешнем режиме не обнуляется (§3.1).
5. **Снежная коррекция.** `teb_snow_check = .TRUE.` (§3.3).
6. **Шаг и единицы.** Согласовать номер первого шага (наш `== 1` против `== 0` в B) и умножение
   городского стока на `dt` (§3.3).

**Конфигурация (для численной сопоставимости с B):**

7. `urb_z0_town = '0.075H'`; толщины и теплофизика слоёв крыши/дороги — из конфигурации;
   `teb_lshade = .FALSE.`; `urb_z0_o_z0h_gdn = 4.`; `urb_z0_grf = 0.01` (все — дефолты).
8. Сад: `LGARDEN = .TRUE.` вместе с `LGARDEN_EXT = .TRUE.` (`A_ctrl`) или `TYPE_GARDEN = 'EXT'`
   (`A_dev`); при выключенном саде внешний режим не включать.
9. Кровля: `LGREENROOF = .TRUE.`; в `A_ctrl` внешняя кровля ведёт себя как в B (прокси
   вызывается, β = 0.3), в `A_dev` — включать её только если адаптер подаёт `z0` и `q_v` кровли.

**Осознанно оставляем своё (с записью в документации):**

10. `ZTS_GROUND` — наш вариант инициализации (§5 п.1).
11. Отсутствие `PAC_AGG_GARDEN`/`PAC_AGG_GREENROOF` и множитель влажности, возвращаемый прокси
    во внутренних режимах, — числа сопряжённого прогона не меняют.
12. Трение внешних поверхностей в `A_dev` — предмет решения (§5 п.2, §6 п.3).

---

## 5. Осознанные и спорные расхождения

| № | расхождение | где | обоснование | условие закрытия |
| --- | --- | --- | --- | --- |
| 1 | `ZTS_GROUND` инициализируется | `A_ctrl`, `A_dev` (`src_dev/src_teb/urban_drag.F90:601`) | в B величина читается неинициализированной (`B:src_teb/urban_drag.F90:524`) | решение авторов COSMO-TEB |
| 2 | трение внешних поверхностей — по моментному коэффициенту режима | `A_dev` (`src_dev/src_teb/teb_garden.F90:1100`, `src_dev/src_teb/teb_garden.F90:1211`) | `URBAN_DRAG` в тех же режимах считает стратифицированный коэффициент; нейтральная формула B с жёстким z0 (0.1 м / 0.01 м) расходится с коэффициентами, которые сад отдаёт хосту | решение: оставить как улучшение (инвариант G14 of `TEB_MSU_garden_diagnostic_scheme.md`) или вернуть формулу B |
| 3 | внешняя кровля берёт `q_v` и `z0` от хоста | `A_dev` (`src_dev/src_teb/teb_garden.F90:1216`, `src_dev/src_teb/urban_drag.F90:844`) | иначе состояние хоста подменяется константой: B считает β = 0.3, хотя хост подаёт свои потоки кровли | нужен вход в интерфейсе H (или константы в адаптере) |
| 4 | прокси сада обнуляет проводимость `PAC_GARDEN` | `A_ctrl` (`src_proxi_SVAT/garden.F90:160`) | унаследовано от «первого» дерева; в B строка закомментирована (`B:src_proxi_SVAT/garden.F90:151`) | во внешнем режиме прокси не вызывается ⇒ не проявляется |
| 5 | отношения z0/z0h сада берутся из словника, а не из жёсткого `4.` | `A_dev` (`src_dev/src_teb/urban_drag.F90:792`) | ключ согласует z0h диагностического сада и экспортируемые коэффициенты | держать дефолт `4.` для сопоставимости с B |
---

## 6. Открытые вопросы

| № | вопрос | владелец | как закрывается |
| --- | --- | --- | --- |
| 1 | адаптер `CALL_DRIVER` (23 аргумента для `A_ctrl`, 29 для `A_dev`) | мы + авторы COSMO-TEB | адаптер в дереве COSMO, прогон стенда |
| 2 | входы кровли `z0`/`q_v` в H (нужны `A_dev`) | авторы COSMO-TEB | поля интерфейса по аналогии с `teb_z0_gd`/`teb_qs_gd` либо константы в адаптере |
| 3 | трение внешних поверхностей в `A_dev` (§5 п.2) | мы | решение: оставить как улучшение (G14) или выровнять по B |
| 4 | `teb_snow_check = .TRUE.` для сопоставимости | мы | значение по умолчанию или ключ адаптера |
| 5 | нумерация первого шага и единицы городского стока | мы | согласование с хостом |
| 6 | BEM (сурвентиляция, порог AC, инициализация пола/массы, `PDQS_*`) | мы + авторы COSMO-TEB | выравнивание либо явная фиксация расхождения |
| 7 | количественная сверка коэффициентов сада «`A_ctrl` == B» при одинаковом `teb_z0_gd` | мы | одношаговый тест в сопряжённом стенде |
| 8 | стенд сопряжения COSMO↔TEB (сравнение `T_CANYON`, `Q_CANYON`, `RN_TOWN`, `TI_BLD`, `HVAC_*`) | мы | прогон COSMO с нашим TEB; в репозитории такого стенда нет (в `python/`, `python_tests/` нет упоминаний COSMO) |

---

## 7. Различия файлов и артефакты

Сравнение с B по каталогам физики (`src_teb`, `src_struct`, `src_proxi_SVAT`, `src_solar`) и файлам
`src_driver/call_driver.F90`, `src_driver/sfc_teb.F90` (нормализация CRLF; класс «различаются» —
различие по коду, а не только по комментариям и форматированию):

| | общих файлов | совпадают побайтово | различаются по коду |
| --- | --- | --- | --- |
| `A_ctrl` | 126 | 106 | 20 |
| `A_dev` | 126 | 96 | 30 |

`A_dev` отличается от `A_ctrl` десятью дополнительными файлами — это CBS-схема дороги и снеговые
модули (`alloc_teb_struct.F90`, `dealloc_teb_struct.F90`, `modd_diag_misc_tebn.F90`,
`modd_teb_optionn.F90`, `modd_tebn.F90`, `modi_snow_cover_1layer.f90`, `modi_urban_snow_evol.f90`,
`snow_cover_1layer.F90`, `urban_fluxes.F90`, `urban_snow_evol.F90`). Садовой области сопряжения они
не касаются; они описаны в `TEB_MSU_CBS_scheme_T_CAN_reformulation.md` и в
`TEB_MSU_change_history.md`.

Только в наших деревьях: `src_proxi_SVAT/modd_proxi_svat_par.F90` (носитель ключей словника) и
`src_teb/teb_garden_with_snow_correction.F90` (вне сборки; функционал реализован флагом
`teb_snow_check`, §3.3). Только в B: `src_teb/urban_drag_test_diff_z0h.F90` (вне сборки). Прочие
автономные драйверы стороны B (`call_teb_interface.F90`, `driver.F90`, `driver_original.F90`,
`test_function3.f90`, `call_driver_with_comments!.F90`) в сравнение не входят: при сопряжении
вызывается `CALL_DRIVER`.

---

## 8. Контроль достоверности цитат

Ссылки вида «файл:строка» проверены автоматически: для каждой ссылки проверено существование
файла и строки, а при наличии якоря (запись «ссылка → `текст`») — что текст входит в указанную
строку (сравнение по нормализованным пробелам, CRLF→LF). Сокращения `:NNN` не используются.

**Результат: 132 ссылки (85 — с якорем), ошибок — 0.**

Ссылки на сторону A даны по состоянию коммита `6e5b46e`; ссылки на B и H — по рабочей копии
`COSMO-TEB_vers_29_09_2026` (2026-09-29).
