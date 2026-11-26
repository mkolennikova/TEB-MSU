"""Draw the TEB-MSU pedestrian MRT scheme with the Python standard library.

Run from the repository root: python illustrations/draw/draw_mrt.py
"""
from math import atan2, cos, degrees, hypot, pi, sin, sqrt
from pathlib import Path
from xml.sax.saxutils import escape


INK, LABEL, GRAY = "#343330", "#413a31", "#657078"
FRONT, SIDE, ROOF = "#ffd47f", "#efa523", "#ffe0a1"
PAVEMENT, GREEN, GREEN_EDGE = "#dfddd8", "#93c653", "#53783b"
SHORT, LONG, DIRECT = "#195c9c", "#aa2941", "#b26309"
SIGHT = "#707981"
SHADOW, SHADOW_EDGE = "#526372", "#566775"
# Full-surface tint, local sector fill and arc colour.
SKY = ("#f0f6fa", "#d8eaf3", "#49758b")
WALL = ("#fff8eb", "#f6e1bd", "#977249")
FLOOR = ("#eff4ec", "#dcead7", "#587753")
SANS = "Arial, DejaVu Sans, sans-serif"

HEIGHT_M, WIDTH_M, RECEPTOR_M = 10., 11., 1.1
SCALE = 44  # drawing units per metre in the transverse section
BODY_HEIGHT = RECEPTOR_M * SCALE
PERSON_SCALE = BODY_HEIGHT / 39  # the receptor is 39 units above the feet in the silhouette
# Projected heights of the surfaces extending towards the reader.
ROOF_DEPTH, FLOOR_DEPTH = 28, 88


def text(x, y, value, size=18, *, color=LABEL, bold=False, anchor="start"):
    return (f'<text x="{x:g}" y="{y:g}" text-anchor="{anchor}" fill="{color}" '
            f'font-size="{size}" font-weight="{700 if bold else 400}">{escape(value)}</text>')


def line(x1, y1, x2, y2, color=GRAY, width=1.5, dash=None):
    path = f"M {x1:g},{y1:g} L {x2:g},{y2:g}"
    if dash:
        # Explicit segments keep the height and shadow guides light in print.
        on, off = dash
        length = hypot(x2-x1,y2-y1)
        ux, uy = (x2-x1)/length, (y2-y1)/length
        path = " ".join(f"M {x1+ux*t:.2f},{y1+uy*t:.2f} "
                        f"L {x1+ux*min(t+on,length):.2f},{y1+uy*min(t+on,length):.2f}"
                        for t in range(0,int(length)+1,on+off))
    return f'<path d="{path}" fill="none" stroke="{color}" stroke-width="{width:g}"/>'


def polygon(points, fill, stroke=INK, width=2):
    coords = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return (f'<polygon points="{coords}" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{width}" stroke-linejoin="round"/>')


def radiation_arrow(length, offset, color, shared_tail=False):
    """Draw one spectral component, with a separate arrowhead at the body."""
    start = 9 if shared_tail else 0
    end = length-8
    if color == LONG:
        halves = 2*max(1,round((end-start)/21))
        step = (end-start)/halves
        path = f"M {start},{offset:g}" + "".join(
            f" q {step/2:.3f},{-3.6 if i%2==0 else 3.6} {step:.3f},0" for i in range(halves)
        )
        shaft = f'<path d="{path}" fill="none" stroke="{color}" stroke-width="2.2"/>'
    else:
        shaft = line(start,offset,end,offset,color,2.7 if color==DIRECT else 2.15,
                     (7,5) if color==SHORT else None)
    if shared_tail:
        shaft = line(0,0,start,offset,color,2) + shaft
    tip = polygon([(length,offset),(end-1,offset-3.4),(end-1,offset+3.4)],color,"none")
    return shaft + tip


def incoming(name, source, eye, *, direct=False, shared_tail=False):
    dx, dy = eye[0]-source[0], eye[1]-source[1]
    # Keep arrowheads clear of the silhouette for steep sky and surface rays.
    if shared_tail:
        gap = 32 if abs(dy)>abs(dx) else 26
    else:
        gap = 32 if dy>1.5*abs(dx) else 18
    length = hypot(dx,dy) - gap
    transform = f"translate({source[0]:g} {source[1]:g}) rotate({degrees(atan2(dy,dx)):.4f})"
    if direct:
        rays = radiation_arrow(length,0,DIRECT)
    else:
        short_lane, long_lane = (-1.6,6.6) if shared_tail else (-4.1,4.1)
        rays = (f'<g id="{name}-shortwave">{radiation_arrow(length,short_lane,SHORT,shared_tail)}</g>'
                f'<g id="{name}-longwave">{radiation_arrow(length,long_lane,LONG,shared_tail)}</g>')
        if shared_tail:
            rays += f'<circle r="2.7" fill="{INK}"/>'
    return f'<g id="{name}" transform="{transform}">{rays}</g>'


def sun(x, y, radius):
    rays = []
    for n in range(8):
        a = (n+.5)*pi/4
        rays.append(line(x+(radius+4)*cos(a),y+(radius+4)*sin(a),
                         x+(radius+10)*cos(a),y+(radius+10)*sin(a),DIRECT,1.7))
    return (f'<g id="solar-disc"><circle cx="{x:g}" cy="{y:g}" r="{radius:g}" '
            f'fill="#ffda81" stroke="{DIRECT}" stroke-width="1.8"/>'
            + "".join(rays) + '</g>')


def direct_sunlight(street, roof, slope, sun_y):
    """Start both parallel beams on the visible limb of the same schematic Sun."""
    norm = hypot(1,slope)
    targets = (("street-direct",street),("roof-direct",roof))
    # Intersections of the two beam axes with the horizontal through the disc centre.
    at_sun = [x-slope*(y-sun_y) for _,(x,y) in targets]
    sun_x = sum(at_sun)/2
    # Leave a broad visible limb between the ray origins and the header crop.
    radius = max(75,abs(at_sun[0]-at_sun[1])/(2*norm)+22)
    beams = []
    for (name, eye), cross_x in zip(targets,at_sun):
        offset = (cross_x-sun_x)/norm
        forward = sqrt(radius**2-offset**2)
        source = (sun_x+(offset+forward*slope)/norm, sun_y+(forward-offset*slope)/norm)
        beams.append(incoming(name,source,eye,direct=True))
    return '<g id="direct-sunlight">' + "".join(beams) + sun(sun_x,sun_y,radius) + '</g>'


def person(name, x, feet):
    return f'''<g id="{name}-pedestrian" aria-labelledby="{name}-label" transform="translate({x:g} {feet:g}) scale({PERSON_SCALE:.8f})">
      <circle cy="-57" r="6.4" fill="{INK}"/>
      <path d="M -4,-48 Q -9,-47 -10,-41 L -14,-26 M 4,-48 Q 9,-47 10,-41 L 14,-26
               M -3,-28 L -4,-15 -6,-1 M 3,-28 L 4,-15 6,-1"
            fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round"/>
      <path d="M -4,-49 Q 0,-50 4,-49 L 7,-44 6,-26 Q 0,-21 -6,-26 L -7,-44 Z" fill="{INK}"/>
      <circle cy="-39" r="3.6" fill="white" stroke="{INK}" stroke-width="1.1"/>
    </g>'''


def deck(left, right, front_y, left_shift, right_shift, depth, fill, plantings=()):
    def point(u, v):
        return (left+(right-left)*u+((1-u)*left_shift+u*right_shift)*v, front_y-depth*v)

    def band(u1, u2, v1, v2):
        return [point(u1,v1),point(u2,v1),point(u2,v2),point(u1,v2)]

    parts = [polygon(band(0,1,0,1),fill)]
    for name, start, end, near, far in plantings:
        planted = polygon(band(start,end,near,far),GREEN,GREEN_EDGE,1.3)
        for u, v in ((.08,.30),(.13,.64),(.85,.29),(.92,.62)):
            x, y = point(start+(end-start)*u,v)
            planted += line(x,y,x+2.6,y-4,GREEN_EDGE,1.2)
        parts.append(f'<g id="{name}">{planted}</g>')
    return "".join(parts)


def building(outer, inner, offset, top, bottom, plantings=()):
    left, right = sorted((outer,inner))
    front = [(outer,top),(inner,top),(inner,bottom),(outer,bottom)]
    side = [(inner,top),(inner+offset,top-ROOF_DEPTH),(inner+offset,bottom-FLOOR_DEPTH),(inner,bottom)]
    return (polygon(front,FRONT) + polygon(side,SIDE if offset>0 else ROOF) +
            deck(left,right,top,offset,offset,ROOF_DEPTH,ROOF,plantings))


def angle_sector(eye, start, end, radius, colors):
    """A circular arc and its two radii, in the actual transverse view plane."""
    x, y = eye
    span = (end-start) % (2*pi)
    ax, ay = x+radius*cos(start), y+radius*sin(start)
    bx, by = x+radius*cos(end), y+radius*sin(end)
    arc = f"A {radius:g},{radius:g} 0 {int(span>pi)} 1 {bx:.3f},{by:.3f}"
    fill = f'M {x:g},{y:g} L {ax:.3f},{ay:.3f} {arc} Z'
    rim = f'M {ax:.3f},{ay:.3f} {arc}'
    return (f'<path d="{fill}" fill="{colors[1]}"/>'
            f'<path d="{rim}" fill="none" stroke="{colors[2]}" stroke-width="2.5"/>')


def canyon_angles(left, right, roof_y, floor_y, eye, shadow_foot):
    top_left, top_right = (left,roof_y), (right,roof_y)
    base_left, base_right = (left,floor_y), (right,floor_y)
    facets = (("sky",top_left,top_right,84,SKY), ("right-wall",top_right,base_right,34,WALL),
              ("floor",base_right,base_left,31,FLOOR), ("left-wall",base_left,top_left,34,WALL))
    tints, parts = [], []
    for name, first, last, radius, colors in facets:
        start = atan2(first[1]-eye[1],first[0]-eye[0])
        end = atan2(last[1]-eye[1],last[0]-eye[0])
        tints.append(f'<g id="aperture-{name}">{polygon((eye,first,last),colors[0],"none")}</g>')
        parts.append(f'<g id="angle-{name}">{angle_sector(eye,start,end,radius,colors)}</g>')
    shadow = (f'<g id="canyon-shadow"><g opacity=".22">'
              + polygon((top_left,shadow_foot,base_left),SHADOW,"none") + '</g>'
              + line(*top_left,*shadow_foot,SHADOW_EDGE,1.5) + '</g>')
    parts.append(shadow)
    for corner in (top_left,top_right,base_right,base_left):
        parts.append(line(*eye,*corner,SIGHT,1.45,(6,5)))
    return '<g id="canyon-view-angles">' + "".join(tints+parts) + '</g>'


def receptor_height(name, x, z, surface):
    """Vertical dimension measured in the same section as the feet and receptor."""
    return f'''<g id="{name}-height">
      {line(x,z,x,surface,GRAY,1.35)}
      {line(x-4,z,x+4,z,GRAY,1.45)}{line(x-4,surface,x+4,surface,GRAY,1.45)}
      {text(x-9,(z+surface)/2+4,f"{RECEPTOR_M:g} m",15,color=GRAY,anchor="end")}
    </g>'''


def roof_angles(eye, roof_y):
    x, y = eye
    return f'''<g id="roof-view-angles">
      <g id="angle-roof-sky">{angle_sector(eye,pi,2*pi,41,SKY)}</g>
      <g id="angle-roof-surface">{angle_sector(eye,0,pi,41,FLOOR)}</g>
      {line(x-140,y,x+141,y,SIGHT,1.45,(6,5))}
      {receptor_height("roof",x-140,y,roof_y)}
      {text(x-57,y+24,"Roof view",17,color=FLOOR[2],anchor="end")}
      {text(x+94,y+15,"Horizon",13,color=GRAY)}
    </g>'''


def surface_brace(name, title, left, right, base, tip):
    """Span the contributing surface types and place the cusp at their shared flux source."""
    x, y = tip
    arm = base-7
    path = (f"M {left:g},{base:g} Q {left+2:g},{arm-2:g} {left+13:g},{arm-2:g} "
            f"C {left+21:g},{arm-2:g} {left+24:g},{arm:g} {left+34:g},{arm:g} "
            f"H {x-16:g} C {x-6:g},{arm:g} {x-3:g},{arm-2:g} {x:g},{y:g} "
            f"C {x+3:g},{arm-2:g} {x+6:g},{arm:g} {x+16:g},{arm:g} H {right-34:g} "
            f"C {right-24:g},{arm:g} {right-21:g},{arm-2:g} {right-13:g},{arm-2:g} "
            f"Q {right-2:g},{arm-2:g} {right:g},{base:g}")
    return f'''<g id="{name}-flux-brace">
      <title>{escape(title)}</title>
      <path d="{path}" fill="none" stroke="white" stroke-width="4.5"/>
      <path d="{path}" fill="none" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>
    </g>'''


def street_and_roof():
    left, roof_y = 342., 285.
    right, floor_y = left+WIDTH_M*SCALE, roof_y+HEIGHT_M*SCALE
    # The back edge is the true transverse section. The closer section is
    # taller and wider by the same perspective scale factor.
    spread = .5*(right-left)*(FLOOR_DEPTH-ROOF_DEPTH)/(floor_y-roof_y)
    near_left, near_right = left-spread, right+spread
    top, bottom = roof_y+ROOF_DEPTH, floor_y+FLOOR_DEPTH
    roof_outer = 58.

    def floor_x(fraction, y):
        depth_fraction = (y-floor_y)/FLOOR_DEPTH
        return left+fraction*(right-left)+(2*fraction-1)*spread*depth_fraction

    roof = (left-63,roof_y-BODY_HEIGHT)
    slope = .42  # cross-street displacement per unit vertical drop of sunlight

    def shadow_x(y):
        return left+slope*(y-roof_y)

    receptor_y = floor_y-BODY_HEIGHT
    shadow_foot = (shadow_x(floor_y),floor_y)
    shadow_at_body = shadow_x(receptor_y)
    ground_fraction = (shadow_foot[0]-left)/(right-left)
    height_fraction = (shadow_at_body-left)/(right-left)
    shadow_front = (floor_x(ground_fraction,bottom),bottom)
    # The shaded head and the sunlit left shoe are closest to the sloping shadow edge.
    # Leave 2.5 drawing units of perpendicular clearance around each outline.
    normal = hypot(1,slope)
    clearance = 2.5
    shaded_x = shadow_x(floor_y-57*PERSON_SCALE) - (6.4*PERSON_SCALE+clearance)*normal
    shoe_x = shadow_x(floor_y-PERSON_SCALE) + (2.5*PERSON_SCALE+clearance)*normal
    street = (shoe_x+6*PERSON_SCALE,receptor_y)
    street_label_y = receptor_y-35  # just above the two heads
    garden_strip = .30/2  # divide the illustrated garden area equally between the two verges
    plantings = (("garden-left",0,garden_strip,0,1),("garden-right",1-garden_strip,1,0,1))
    floor_brace_y = floor_y+.73*FLOOR_DEPTH
    joint_y = floor_brace_y-18
    # An offset cusp keeps both outgoing arrows visible alongside the pedestrian.
    floor_joint = (floor_x(.30,joint_y),joint_y)
    floor_span = (floor_x(0,floor_brace_y)+5,floor_x(1,floor_brace_y)-5)
    roof_brace_y = roof_y+.82*ROOF_DEPTH
    roof_shift = spread*(top-roof_brace_y)/ROOF_DEPTH
    roof_span = (roof_outer+roof_shift+7,near_left+roof_shift-7)
    roof_joint = (sum(roof_span)/2,roof_brace_y-15)
    ruler = bottom+49
    width_cut = floor_x(height_fraction,bottom)

    return f'''<g id="street-and-roof">
      <title>Local angular apertures and incident radiation in a single street cross-section</title>
      {canyon_angles(left,right,roof_y,floor_y,street,shadow_foot)}
      <g id="street-deck">
        {deck(near_left,near_right,bottom,spread,-spread,FLOOR_DEPTH,PAVEMENT,plantings)}
        <g id="floor-shadow">
          <g opacity=".28">{polygon(((left,floor_y),shadow_foot,shadow_front,(near_left,bottom)),SHADOW,"none")}</g>
          {line(*shadow_foot,*shadow_front,SHADOW_EDGE,1.5)}
        </g>
      </g>
      <g id="roof-bearing-building">{building(roof_outer,near_left,spread,top,bottom,(("green-roof",.02,.275,.08,.92),))}</g>
      <g id="right-building">{building(974,near_right,-spread,top,bottom)}</g>
      <g id="surface-labels">
        {text(floor_x(garden_strip/2,bottom),bottom+23,"Garden",16,color="#2e4d29",bold=True,anchor="middle")}
        {text(floor_x(.5,bottom),bottom+23,"Paved road",16,bold=True,anchor="middle")}
        {text(floor_x(1-garden_strip/2,bottom),bottom+23,"Garden",16,color="#2e4d29",bold=True,anchor="middle")}
        {text(104,top+23,"Green roof",15,color="#365628",bold=True,anchor="middle")}
        {text(228,top+23,"Conventional roof",15,bold=True,anchor="middle")}
      </g>
      {roof_angles(roof,roof_y)}
      <g id="street-calculation-level">
        {line(shadow_at_body,street[1],right-21,street[1],GRAY,1.15,(3,5))}
        <circle cx="{shadow_at_body:g}" cy="{street[1]:g}" r="3.1" fill="white" stroke="{SHADOW_EDGE}" stroke-width="1.4"/>
        {text(right-20,street[1]-8,"Receptor level",15,color=GRAY,anchor="end")}
        {receptor_height("street",right-21,street[1],floor_y)}
      </g>
      <g id="canyon-angle-labels">
        {text(street[0]+12,roof_y+121,"Sky view",18,color=SKY[2],bold=True,anchor="middle")}
        {text(left+13,roof_y+287,"Left wall",17,color=WALL[2],bold=True)}
        {text(right-15,roof_y+226,"Right wall",17,color=WALL[2],bold=True,anchor="end")}
        {text(street[0]+42,floor_y-17,"Floor",15,color=FLOOR[2],bold=True)}
        <g transform="translate({left+slope*88-14:g} {roof_y+88:g}) rotate({degrees(atan2(1,slope)):.3f})">
          {text(0,0,"Shadow edge",14,color=SHADOW_EDGE)}
        </g>
      </g>
      {surface_brace("floor","Area-averaged fluxes from both garden strips and the paved road",*floor_span,floor_brace_y,floor_joint)}
      {surface_brace("roof","Area-averaged fluxes from the green and conventional roof surfaces",*roof_span,roof_brace_y,roof_joint)}
      <g id="street-radiation">
        {incoming("street-sky",(street[0]+150,roof_y-108),street)}
        {incoming("street-left-wall",(left,roof_y+165),street)}
        {incoming("street-right-wall",(right,receptor_y-44),street)}
        {incoming("street-floor",floor_joint,street,shared_tail=True)}
      </g>
      <g id="roof-radiation">
        {incoming("roof-sky",(roof[0]-107,112),roof)}
        {incoming("roof-surface",roof_joint,roof,shared_tail=True)}
      </g>
      {direct_sunlight(street,roof,slope,48)}
      {person("shaded",shaded_x,floor_y)}
      {person("sunlit",street[0],floor_y)}
      {person("roof",roof[0],roof_y)}
      <g id="output-labels" font-size="14" font-weight="700" fill="{INK}">
        <text id="roof-label" x="{roof[0]-43:g}" y="{roof[1]-19:g}" font-size="15" text-anchor="end">MRT_ROOF</text>
        <text id="shaded-label" x="{shaded_x-2:g}" y="{street_label_y:g}" text-anchor="end">MRT_ROAD_SHADE</text>
        <text id="sunlit-label" x="{street[0]+39:g}" y="{street_label_y:g}">MRT_ROAD_SUN</text>
      </g>
      <g id="sunlit-width">
        {line(near_left,ruler,width_cut,ruler,GRAY,1.7)}{line(width_cut,ruler,near_right,ruler,DIRECT,1.7)}
        {line(near_left,ruler-4,near_left,ruler+4)}{line(width_cut,ruler-4,width_cut,ruler+4)}{line(near_right,ruler-4,near_right,ruler+4)}
        {text((near_left+width_cut)/2,ruler+22,"Shade",15,color=GRAY,anchor="middle")}
        {text((width_cut+near_right)/2,ruler+22,"Sunlit width at 1.1 m",15,color=DIRECT,anchor="middle")}
      </g>
    </g>'''


def build_svg():
    header_bottom = 63
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1030" height="985" viewBox="0 0 1030 985"
     role="img" aria-labelledby="title description" xml:lang="en">
  <title id="title">TEB-MSU pedestrian mean radiant temperature</title>
  <desc id="description">Sightlines from the chest of a sunlit pedestrian to the eaves and wall bases
  bound four viewing angles: sky, left wall, right wall and street floor. On the open roof the horizon
  through the pedestrian separates the sky and roof semicircles. MRT_ROOF marks the roof pedestrian.
  Adjacent pedestrians on opposite sides of the shadow edge mark MRT_ROAD_SHADE and MRT_ROAD_SUN.
  All receptors are 1.1 m above their surfaces. The two street cases share the same background radiation.
  Garden strips flank the paved road. The left strip is in the building
  shadow and the right strip is in full sun. One brace spans both garden strips and the paved road.
  Another spans the green and conventional surfaces of the roof. From each brace, two arrows carry
  area-averaged reflected shortwave and outgoing longwave radiation to the rooftop or sunlit street pedestrian.
  Parallel beams from the visible solar limb reach the pedestrians on the roof and on the sunlit road.</desc>
  <rect width="1030" height="985" fill="white"/>
  <g font-family="{SANS}">
    {street_and_roof()}
    <g id="figure-header">
      <rect width="1030" height="{header_bottom}" fill="white"/>
      {text(34,43,"TEB-MSU",28,color="#a14b1c",bold=True)}
      {text(185,43,"Pedestrian mean radiant temperature",29,bold=True)}
      {line(34,header_bottom,996,header_bottom,"#c6c2b9",1.4)}
    </g>
    <g id="figure-key" transform="translate(0 134)">
      {line(34,770,996,770,"#c6c2b9",1.3)}
      <g transform="translate(40 800)">
        {angle_sector((0,0),-pi/3,0,21,SKY)}
        {line(0,0,13,-22,SIGHT,1.1)}{line(0,0,26,0,SIGHT,1.1)}
      </g>
      {text(74,801,"Local viewing angle",16)}
      <g transform="translate(240 796)">{radiation_arrow(41,0,SHORT)}</g>
      {text(293,801,"Diffuse / reflected shortwave",16)}
      <g transform="translate(532 796)">{radiation_arrow(40,0,LONG)}</g>
      {text(582,801,"Longwave",16)}
      <g transform="translate(750 796)">{radiation_arrow(40,0,DIRECT)}</g>
      {text(800,801,"Direct sunlight",16)}
      {text(40,833,"Surface fluxes are area-weighted. Both street cases share the width-averaged background and differ only in direct sunlight.",16,color=GRAY)}
    </g>
  </g>
</svg>
'''


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "img" / "mrt_scheme.svg"
    target.write_text(build_svg(), encoding="utf-8")
    print(target)
