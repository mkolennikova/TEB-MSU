# P2, ????? 2: ????? ???????? ????????? ? ??????????

????????????? ?? `src_struct/teb_garden_struct.F90` (????? `copy-in` / `copy-out`),
????????????? `CALL TEB_GARDEN_STRUCT` ? `call_driver.F90` ? `CALL CALL_DRIVER` ?
`src_api/sfc_teb.F90`. ???????????? ?????????: TGS 326 = 326 ???????????, CD 151 = 151.

??????? ????????: `TEB_BIND_STATE(T, B, KSTART, KEND, <?????????>)` ? `TEB_HOST` ????????
`<SI-?????????>` ? ??????? `(i` ?? `(KSTART:KEND`, ? `TEB_UNBIND_STATE` ?????? ????????.
????? ????????? ?????????? ???????? ? TGS/CD ? ????????? ?? ????????.

| ??? | ???? ?????????? | ???????? TGS | ???????? CALL_DRIVER | ???????? teb_interface |
| --- | --- | --- | --- | --- |
| `B` | `XTI_BLD` | `PTI_BLD` | `ZTI_BLD` | `teb_ti_bld(i)` |
| `B` | `XTRAN_WIN` | `PTRAN_WIN` | `ZTRAN_WIN` | `?` |
| `B` | `XAUX_MAX` | `PAUX_MAX` | `ZAUX_MAX` | `?` |
| `B` | `XT_WIN2` | `PT_WIN2` | `ZT_WIN2` | `teb_twin2(i)` |
| `B` | `XQI_BLD` | `PQI_BLD` | `ZQI_BLD` | `teb_qi_bld(i)` |
| `B` | `XCAP_SYS_RAT` | `PCAP_SYS_RAT` | `ZCAP_SYS_RAT` | `teb_cap_sys_rat(i)` |
| `B` | `XT_ADP` | `PT_ADP` | `ZT_ADP` | `?` |
| `B` | `XM_SYS_RAT` | `PM_SYS_RAT` | `ZM_SYS_RAT` | `teb_m_sys_rat(i)` |
| `B` | `XT_WIN1` | `PT_WIN1` | `ZT_WIN1` | `teb_twin1(i)` |
| `B` | `XABS_WIN` | `PABS_WIN` | `ZABS_WIN` | `?` |
| `B` | `XUGG_WIN` | `PUGG_WIN` | `ZUGG_WIN` | `?` |
| `B` | `LSHADE` | `OSHADE` | `LSHADE` | `lshade_arg` |
| `B` | `XSHADE` | `PSHADE` | `ZSHADE` | `?` |
| `B` | `XNATVENT` | `PNATVENT` | `ZNATVENT` | `?` |
| `B` | `LSHAD_DAY` | `OSHAD_DAY` | `GSHAD_DAY` | `teb_shad_day(i)` |
| `B` | `LNATVENT_NIGHT` | `ONATVENT_NIGHT` | `GNATVENT_NIGHT` | `teb_natvent_night(i)` |
| `T` | `XWS_ROOF` | `PWS_ROOF` | `ZWS_ROOF` | `teb_ws_roof(i)` |
| `T` | `XWS_ROAD` | `PWS_ROAD` | `ZWS_ROAD` | `teb_ws_road(i)` |
| `T` | `XT_ROOF` | `PT_ROOF` | `ZT_ROOF` | `teb_troof(i,:)` |
| `T` | `XT_ROAD` | `PT_ROAD` | `ZT_ROAD` | `teb_troad(i,:)` |
| `T` | `XT_WALL_A` | `PT_WALL_A` | `ZT_WALL_A` | `teb_twalla(i,:)` |
| `T` | `XT_WALL_B` | `PT_WALL_B` | `ZT_WALL_B` | `teb_twallb(i,:)` |
| `T` | `XT_CANYON` | `PT_CAN` | `ZT_CANYON` | `teb_tcanyon(i)` |
| `T` | `XQ_CANYON` | `PQ_CAN` | `ZQ_CANYON` | `teb_qcanyon(i)` |
| `T` | `TSNOW_ROOF%SCHEME` | `HSNOW_ROOF` | `HSNOW_ROOF` | `?` |
| `T` | `TSNOW_ROOF%WSNOW` | `PWSNOW_ROOF` | `ZWSNOW_ROOF` | `teb_wsnow_roof(i,:)` |
| `T` | `TSNOW_ROOF%T` | `PTSNOW_ROOF` | `ZTSNOW_ROOF` | `teb_tsnow_roof(i,:)` |
| `T` | `TSNOW_ROOF%RHO` | `PRSNOW_ROOF` | `ZRSNOW_ROOF` | `teb_rsnow_roof(i,:)` |
| `T` | `TSNOW_ROOF%ALB` | `PASNOW_ROOF` | `ZASNOW_ROOF` | `teb_asnow_roof(i)` |
| `T` | `TSNOW_ROOF%EMIS` | `PESNOW_ROOF` | `ZESNOW_ROOF` | `teb_esnow_roof(i)` |
| `T` | `TSNOW_ROOF%TS` | `PTSSNOW_ROOF` | `ZTSSNOW_ROOF` | `teb_tssnow_roof(i)` |
| `T` | `TSNOW_ROAD%SCHEME` | `HSNOW_ROAD` | `HSNOW_ROAD` | `?` |
| `T` | `TSNOW_ROAD%WSNOW` | `PWSNOW_ROAD` | `ZWSNOW_ROAD` | `teb_wsnow_road(i,:)` |
| `T` | `TSNOW_ROAD%T` | `PTSNOW_ROAD` | `ZTSNOW_ROAD` | `teb_tsnow_road(i,:)` |
| `T` | `TSNOW_ROAD%RHO` | `PRSNOW_ROAD` | `ZRSNOW_ROAD` | `teb_rsnow_road(i,:)` |
| `T` | `TSNOW_ROAD%ALB` | `PASNOW_ROAD` | `ZASNOW_ROAD` | `teb_asnow_road(i)` |
| `T` | `TSNOW_ROAD%EMIS` | `PESNOW_ROAD` | `ZESNOW_ROAD` | `teb_esnow_road(i)` |
| `T` | `TSNOW_ROAD%TS` | `PTSSNOW_ROAD` | `ZTSSNOW_ROAD` | `teb_tssnow_road(i)` |
| `T` | `XT_CANYON` | `PT_CAN` | `ZT_CANYON` | `teb_tcanyon(i)` |
| `T` | `XQ_CANYON` | `PQ_CAN` | `ZQ_CANYON` | `teb_qcanyon(i)` |
