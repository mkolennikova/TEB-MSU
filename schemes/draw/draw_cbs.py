"""Generate schemes/img/cbs_scheme.svg using only the Python standard library.

Run from the repository root: python schemes/draw/draw_cbs.py
"""
from pathlib import Path

RED, BLUE, INK = '#a0182c', '#0057c8', '#343330'
ROAD_PATCH = [(475,750), (535,610), (765,610), (825,750)]

def label(x, y, base, sub='', color=INK, size=29, anchor='start', sub_size=18):
    suffix = f'<tspan dy="7" font-size="{sub_size}">{sub}</tspan>' if sub else ''
    return f'<text x="{x}" y="{y}" fill="{color}" font-family="Times New Roman" font-size="{size}" text-anchor="{anchor}">{base}{suffix}</text>'

def path(d, color=RED, width=4):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"/>'

def node(x,y,fill='#8fce47',r=7):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{INK}" stroke-width="2.5"/>'

def road_hatching():
    # Explicit clipped strokes keep the SVG and MuPDF PNG identical.
    polygon = ROAD_PATCH
    lines = []
    for offset in range(1090, 1590, 17):
        intersections = []
        for a, b in zip(polygon, polygon[1:] + polygon[:1]):
            denominator = sum(b) - sum(a)
            if denominator:
                t = (offset - sum(a)) / denominator
                if 0 <= t <= 1:
                    intersections.append((a[0]+t*(b[0]-a[0]), a[1]+t*(b[1]-a[1])))
        if len(intersections) >= 2:
            a, b = intersections[0], intersections[-1]
            lines.append(path(f'M {a[0]:.2f} {a[1]:.2f} L {b[0]:.2f} {b[1]:.2f}', '#b5b5b1', 1.2))
    return '\n'.join(lines)

def road_boundaries():
    lines = []
    for a,b in [((475,750),(535,610)), ((825,750),(765,610))]:
        length = ((b[0]-a[0])**2 + (b[1]-a[1])**2)**0.5
        for start in range(0, int(length), 15):
            t0, t1 = start/length, min((start+8)/length, 1)
            lines.append(path(f'M {a[0]+t0*(b[0]-a[0]):.2f} {a[1]+t0*(b[1]-a[1]):.2f} L {a[0]+t1*(b[0]-a[0]):.2f} {a[1]+t1*(b[1]-a[1]):.2f}', '#77736d', 1.8))
    return '\n'.join(lines)

def forcing_drop():
    # Continuous dash spacing, including the rounded corners.
    # Derive the axis from the road patch so both geometries stay centered.
    center = sum(x for x, _ in ROAD_PATCH) / len(ROAD_PATCH)
    left, right, radius = center - 105, center + 105, 20
    points = [(left-radius,265)]
    def curve(a,b,c):
        return [((1-t)**2*a[0]+2*(1-t)*t*b[0]+t*t*c[0],
                 (1-t)**2*a[1]+2*(1-t)*t*b[1]+t*t*c[1])
                for t in [i/12 for i in range(1,13)]]
    points += curve((left-radius,265),(left,265),(left,285))
    points += [(left,505)] + curve((left,505),(left,525),(left+radius,525))
    points += [(right-radius,525)] + curve((right-radius,525),(right,525),(right,505))
    points += [(right,285)] + curve((right,285),(right,265),(right+radius,265))
    lines, remaining, visible = [], 10.0, True
    for a,b in zip(points, points[1:]):
        length = ((b[0]-a[0])**2+(b[1]-a[1])**2)**0.5
        position = 0.0
        while position < length-1e-8:
            step = min(remaining, length-position)
            t0, t1 = position/length, (position+step)/length
            if visible:
                lines.append(path(f'M {a[0]+t0*(b[0]-a[0]):.2f} {a[1]+t0*(b[1]-a[1]):.2f} L {a[0]+t1*(b[0]-a[0]):.2f} {a[1]+t1*(b[1]-a[1]):.2f}', '#8a8781', 2))
            position += step
            remaining -= step
            if remaining < 1e-8:
                visible = not visible
                remaining = 10.0 if visible else 8.0
    return '\n'.join(lines)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1300" height="660" viewBox="0 190 1300 660">
<title>Canyon Bypass Scheme: transition regime</title>
<rect width="1300" height="850" fill="white"/>

<!-- Ground lies strictly within the front and rear building planes. -->
<path d="M 300 750 L 420 610 L 880 610 L 1000 750 Z" fill="#e6e6e4"/>
{road_hatching()}
<path d="M 300 750 L 420 610 L 880 610 L 1000 750 Z" fill="none" stroke="{INK}" stroke-width="2.5"/>
{road_boundaries()}
<g stroke="{INK}" stroke-width="3.3" stroke-linejoin="round">
 <path d="M 100 490 L 220 350 L 420 350 L 300 490 Z" fill="#ffdda0"/>
 <path d="M 300 490 L 420 350 L 420 610 L 300 750 Z" fill="#f1a300"/>
 <path d="M 100 490 L 300 490 L 300 750 L 100 750 Z" fill="#ffd47f"/>
 <path d="M 1000 490 L 880 350 L 1080 350 L 1200 490 Z" fill="#ffdda0"/>
 <path d="M 1000 490 L 880 350 L 880 610 L 1000 750 Z" fill="#ffd47f"/>
 <path d="M 1000 490 L 1200 490 L 1200 750 L 1000 750 Z" fill="#f1a300"/>
</g>

<!-- The reference height drops by the building height over the bypass area. -->
<path d="M 100 265 H 1200" fill="none" stroke="#8a8781" stroke-width="2"/>
{forcing_drop()}
<text x="900" y="232" font-family="Times New Roman" font-size="30" fill="{INK}">T<tspan dy="7" font-size="18">a</tspan><tspan dy="-7">, U</tspan><tspan dy="7" font-size="18">a</tspan></text>
<text x="120" y="242" font-family="Times New Roman" font-size="27" fill="{INK}">z = h<tspan dy="7" font-size="17">bld</tspan><tspan dy="-7"> + h</tspan><tspan dy="7" font-size="17">forc</tspan></text>
{label(590,505,'z = h','forc',size=27)}

<!-- Road-to-canyon pathway and canyon ventilation -->
{path('M 650 700 L 430 700 L 470 660 L 470 650 L 458 640 L 482 630 L 458 620 L 482 610 L 458 600 L 470 590 L 470 570')}
{path('M 470 570 L 470 440 L 458 428 L 482 416 L 458 404 L 482 392 L 458 380 L 470 368 L 470 265')}
<!-- Wall-to-canyon exchange is not weighted by tau. -->
<!-- The wall and canyon nodes share the road-node depth: ground y=700,
     roof y=440, and half-height y=570. The corresponding wall x is 343. -->
{path('M 343 570 L 375 570 L 383 560 L 391 580 L 399 560 L 407 580 L 415 560 L 423 580 L 431 570 L 470 570')}
{node(343,570)}
{label(310,545,'T','wl')}

<!-- Roof exchange with the atmosphere, using the same blue as road bypass. -->
{path('M 260 420 L 260 345 L 248 335 L 272 325 L 248 315 L 272 305 L 248 295 L 260 285 L 260 265', BLUE)}
{node(260,420)}
{node(260,265,'#ffd166',6)}
{label(280,447,'T','roof')}
{label(285,320,'H','roof',BLUE,size=25)}

<!-- Direct road-to-atmosphere pathway -->
{path('M 650 700 L 650 635 L 638 623 L 662 611 L 638 599 L 662 587 L 638 575 L 650 563 L 650 525', BLUE)}
{node(470,570)}
{node(650,700)}
{node(470,265,'#ffd166',6)}
{node(650,525,'#ffd166',6)}

{label(492,600,'H','rd,can',RED,size=25)}
{label(677,595,'H','rd,atm',BLUE,size=25)}
{label(485,540,'T','can',size=28,sub_size=17)}
{label(485,570,'U','can',size=28,sub_size=17)}
{label(674,680,'T','rd')}
{label(405,738,'τ/2',color=RED,size=28,anchor='middle')}
{label(650,738,'1−τ',color=BLUE,size=28,anchor='middle')}
{label(895,738,'τ/2',color=RED,size=28,anchor='middle')}

<!-- Morphological dimensions -->
<g stroke="#77736d" stroke-width="1.4" fill="none">
 <path d="M 84 490 L 55 490 M 84 750 L 55 750 M 65 500 L 65 740"/>
 <path d="M 179 265 L 150 265 M 179 420 L 150 420 M 160 275 L 160 410"/>
 <path d="M 300 765 L 300 800 M 1000 765 L 1000 800 M 310 788 L 990 788"/>
 <path d="M 333 700 H 353 M 343 587 V 690"/>
</g>
<g fill="#77736d">
 <path d="M 65 490 L 61 502 L 69 502 Z M 65 750 L 61 738 L 69 738 Z"/>
 <path d="M 160 265 L 156 277 L 164 277 Z M 160 420 L 156 408 L 164 408 Z"/>
 <path d="M 300 788 L 312 784 L 312 792 Z M 1000 788 L 988 784 L 988 792 Z"/>
 <path d="M 343 577 L 339 589 L 347 589 Z M 343 700 L 339 688 L 347 688 Z"/>
</g>
<g transform="translate(42,657) rotate(-90)">{label(0,0,'h','bld',size=28)}</g>
<g transform="translate(137,380) rotate(-90)">{label(0,0,'h','forc',size=28)}</g>
<g transform="translate(367,663) rotate(-90)"><text x="0" y="0" font-family="Times New Roman" font-size="24" fill="{INK}">h<tspan dy="6" font-size="16">bld</tspan><tspan dy="-6">/2</tspan></text></g>
<rect x="632" y="770" width="36" height="35" fill="white"/>
{label(650,798,'w',size=28,anchor='middle')}
</svg>'''

if __name__ == '__main__':
    target = Path(__file__).resolve().parents[1] / 'img' / 'cbs_scheme.svg'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(svg, encoding='utf-8')
    print(target)
