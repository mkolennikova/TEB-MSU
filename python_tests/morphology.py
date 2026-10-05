"""Building configurations (urban morphologies) used by the TEB-Ru benches.

This module is the single source of truth for the description of the built
surfaces of a case: every bench that varies the urban morphology imports its set
from here (most of them through `sensitivity_zd`, which re-exports `LCZ`).

A morphology is a dict of the namelist items of the built surface:

    label  - human-readable name, used in the figures and the reports
    h_bld  - building height H (m)
    fr_bld - plan area index (plan area of the buildings / total area) (-)
    h2w    - canyon aspect ratio H/W (-), passed to the model as `urb_h2w`
    fai    - frontal area index, used for all 8 wind directions (-)

Typical values are taken from the LCZ literature, Stewart & Oke (2012) and the
parameter tables used by WUDAPT-to-WRF.

`LCZ` holds every configuration used by the benches, as a single set shared by all
of them (sensitivity_zd, the garden and greenroof ones and the cbs comparison).
`LCZ6D` is the low but dense morphology (its H/W is the driver default of the cbs
threshold, so that tau = 0.5 exactly).
"""

from __future__ import annotations

#: the building configurations used by the benches (single source of truth);
#: LCZ6D comes after LCZ2 and before LCZ9
LCZ = {
    'LCZ2': dict(label='LCZ 2 - compact mid-rise (Moscow centre)',
                 h_bld=20.0, fr_bld=0.55, h2w=1.50, fai=0.40),
    #: LOW but DENSE buildings (a dense open low-rise, roughly a compact LCZ 6).
    #: The aspect ratio is the driver default of the cbs threshold,
    #: urb_h2w = 0.5 = teb_tau_hw_thresh, so tanh(0) = 0 gives tau = 0.5 EXACTLY,
    #: whatever the width: it is the worst case of the cbs averaging, where the
    #: canyon path and the atmosphere path carry the same weight (1/2 each). The
    #: plan area index follows the same geometry as SPARSE (fr_bld = 0.5/1.588 =
    #: 0.37, fai = 0.67 * fr_bld); the building height stays the low-rise one.
    'LCZ6D': dict(label='LCZ 6 - dense low-rise (dense open low-rise)',
                  h_bld=6.0, fr_bld=0.37, h2w=0.50, fai=0.25),
    'LCZ9': dict(label='LCZ 9 - sparse low-rise (suburban)',
                 h_bld=6.0, fr_bld=0.15, h2w=0.15, fai=0.10),
    #: extreme test case: nearly free-standing buildings (plan area index 0.01).
    #: H/W is derived from the geometry of a regular building array,
    #: h2w = fr_bld/(1-fr_bld) * (H/D), with the building shape H/D = 0.85
    #: calibrated on LCZ 9 (h2w = 0.15 * 0.85 / 0.15 = 0.85):
    #: h2w = 0.01/0.99 * 0.85 = 0.0086. The frontal area index is scaled
    #: accordingly (fai = 0.67 * fr_bld, as for LCZ 9).
    'SPARSE': dict(label='Extremely sparse buildings (fr_bld = 0.01)',
                   h_bld=6.0, fr_bld=0.01, h2w=0.0086, fai=0.007),
}
