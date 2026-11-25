from math import hypot
from pathlib import Path


OUTLINE_COLOR = "#555555"
CAR_TIRE_FILL = "#38342e"
LABEL_TEXT = "#413a31"
SECONDARY_TEXT = "#514a42"
EXCHANGE = "#276649"
MATERIALS = ("#8b8b85", "#c2b3a2", "#ab947d", "#8d725b")
BUILDING_LAYER_FILL = "#fff19a"
FRONT_WALL_FILL = "#fbd17e"
SIDE_WALL_FILL = "#efa523"
ROOF_FILL = "#ffe0a1"
LAYER_EDGE = OUTLINE_COLOR
LAYER_LINE_WIDTH = 1.2
LAYER_NODE_RADIUS = 3
DOMAIN_FILL = "#fcfaf6"
INTERACTION_COLOR = "#000000"
INTERACTION_WIDTH = 1.8
NODE = "#c42d31"
MODEL_HEADING_SIZE = 16.5
MODEL_DETAIL_SIZE = 13
EXCHANGE_LABEL_SIZE = 13.5
FEATURE_LABEL_SIZE = 15.5
LAYER_LABEL_SIZE = 14.5
ROOF_LABEL_Y = 314
BEM_AIR_EXCHANGE = "#713d8a"
BEM_FACADE_SLOPE = -39 / 33
BEM_OPENINGS_Y = 482
BEM_OPENING_HALF_HEIGHT = 18
BEM_OPENING_WIDTH = 10
BEM_WINDOW_OFFSET = 4
BEM_LOWER_WINDOW_OFFSET = 19.5
BEM_AC_OFFSET = BEM_LOWER_WINDOW_OFFSET
BEM_AC_DEPTH = 8
LEFT_WALL_FACE_X = 1037
TRAFFIC_HEAT = "#9f5729"
ROAD_SURFACE_Y = 599
CAR_X = 1190
CAR_SCALE = 1.12
CAR_WHEEL_RADIUS = 4.2
CAR_BASE_Y = ROAD_SURFACE_Y - CAR_WHEEL_RADIUS * CAR_SCALE
CAR_ROOF_HEIGHT = 20
ROAD_SURFACE_NODE = (1256, ROAD_SURFACE_Y)
ROAD_LAYER_TOP = 614
ROAD_LAYER_HEIGHT = 15
ROAD_FAR_Y = 575
ROAD_NEAR_LEFT, ROAD_NEAR_RIGHT = 1150, 1411
ROAD_FAR_LEFT, ROAD_FAR_RIGHT = 1162, 1378
ROAD_NEAR_CENTRE = (ROAD_NEAR_LEFT + ROAD_NEAR_RIGHT) / 2
ROAD_LAYER_BOTTOM = ROAD_LAYER_TOP + len(MATERIALS) * ROAD_LAYER_HEIGHT
GARDEN_SURFACE_X = 1135
GARDEN_SURFACE_Y = 592
ROAD_WATER_NODE = (1322, ROAD_SURFACE_Y)
ROAD_SNOW_NODE = (1372, ROAD_SURFACE_Y)
ROAD_WATER_BAND = (.62, .785)
ROAD_SNOW_BAND = (.81, .975)
ROAD_SNOW_DEPTH = 4
RIGHT_ROOF_WATER_BAND = (.283, .465)
RIGHT_ROOF_SNOW_BAND = (.04, .24)
RIGHT_ROOF_SNOW_DEPTH = 3
GREEN_ROOF_BAND = (.02, .275)
SOLAR_PANEL_BAND = (.59, .92)
ROOF_STRIP_EDGE = OUTLINE_COLOR
ROOF_STRIP_EDGE_WIDTH = 1.6
SNOW_FILL = "#f9fdff"
SNOW_EDGE = "#6f8da7"
SNOW_SIDE_FILL = "#c6dce8"
WATER_FILL = "#78b6dc"
WATER_EDGE = "#3d759e"
WATER_BAND_DEPTH_INSET = .115
WATER_CORNER_DEPTH = .22
ROAD_SNOW_DEPTH_RANGE = (
    WATER_BAND_DEPTH_INSET + ROAD_SNOW_DEPTH / (ROAD_LAYER_TOP - ROAD_FAR_Y),
    1 - WATER_BAND_DEPTH_INSET,
)
ROOF_DEPTH = 39
ROOF_SURFACE_DEPTH_RANGE = (WATER_BAND_DEPTH_INSET, 1 - WATER_BAND_DEPTH_INSET)
# Offset the far edge of the snow footprint so the raised cap shares the same visible margin.
ROOF_SNOW_DEPTH_RANGE = (
    ROOF_SURFACE_DEPTH_RANGE[0] + RIGHT_ROOF_SNOW_DEPTH / ROOF_DEPTH,
    ROOF_SURFACE_DEPTH_RANGE[1],
)
EXTERNAL_MODEL_FILL = "#f2f3f3"
EXTERNAL_MODEL_EDGE = "#858a8f"
EXTERNAL_MODEL_TEXT = "#3f454b"
LAND_INTERFACE_PALETTE = ("#e9f1e1", "#658052", "#304a29", "#395333")
ATMOSPHERIC_INTERFACE_PALETTE = ("#e4eef7", "#4d6885", "#223c56", "#46596b")
LAYOUT_SHIFT_X = -188
CANVAS_WIDTH = 1776 + LAYOUT_SHIFT_X
LAND_MODEL_X = 18 - LAYOUT_SHIFT_X
LAND_MODEL_WIDTH = 185
LAND_MODEL_ARROW_X = LAND_MODEL_X + LAND_MODEL_WIDTH
LAND_INTERFACE_ARROW_X = LAND_MODEL_ARROW_X + 130
LAND_INTERFACE_WIDTH = 116
LAND_INTERFACE_X = LAND_INTERFACE_ARROW_X + LAND_INTERFACE_WIDTH // 2
LAND_EXCHANGE_LABEL_X = (LAND_MODEL_ARROW_X + LAND_INTERFACE_ARROW_X) // 2
LAND_PROXY_X = LAND_INTERFACE_ARROW_X + LAND_INTERFACE_WIDTH + 8
LAND_PROXY_WIDTH = 168
EXCHANGE_ARROW_OFFSET = 11
LAND_CHOICE_RADIUS = 18
LAND_CHOICE_X = LAND_PROXY_X + LAND_PROXY_WIDTH + 18
LAND_SURFACE_LINK_X = LAND_CHOICE_X + LAND_CHOICE_RADIUS
DOMAIN_LEFT = LAND_INTERFACE_X
DOMAIN_RIGHT = 1552
ATMOSPHERE_X = 1224
LEFT_INDOOR_X = 979
RIGHT_INDOOR_X = 1469
ATMOSPHERIC_LEVEL = 222
ATMOSPHERIC_INTERFACE_X = DOMAIN_RIGHT + 40
ATMOSPHERIC_INTERFACE_WIDTH = 148
ATMOSPHERIC_INTERFACE_LEFT = ATMOSPHERIC_INTERFACE_X - ATMOSPHERIC_INTERFACE_WIDTH // 2
ROOF_NODE_LEVEL = 402
GREEN_ROOF_X = 961.5
RIGHT_ROOF_WATER_NODE = (1436, ROOF_NODE_LEVEL)
RIGHT_ROOF_SNOW_NODE = (1410, ROOF_NODE_LEVEL)
SOLAR_PANEL_X = 1026


def dashed_line(x1, y1, x2, y2):
    length = hypot(x2 - x1, y2 - y1)
    ux, uy = (x2 - x1) / length, (y2 - y1) / length
    segments = []
    for start in range(0, int(length) + 1, 10):
        stop = min(start + 6, length)
        segments.append(
            f"M {x1 + start*ux:.2f},{y1 + start*uy:.2f} "
            f"L {x1 + stop*ux:.2f},{y1 + stop*uy:.2f}"
        )
    return " ".join(segments)


def exchange_arrow(x1, y1, x2, y2, *, weight=2.3, size=8, dashed=False, color=EXCHANGE):
    length = hypot(x2 - x1, y2 - y1)
    ux, uy = (x2 - x1) / length, (y2 - y1) / length
    dx, dy = ux * size, uy * size
    sx, sy = -uy * .49 * size, ux * .49 * size
    end = f"M {x2},{y2} L {x2-dx+sx:.2f},{y2-dy+sy:.2f} {x2-dx-sx:.2f},{y2-dy-sy:.2f} Z"
    line = f"M {x1},{y1} L {x2-.78*dx:.2f},{y2-.78*dy:.2f}"
    if dashed:
        line = dashed_line(x1, y1, x2 - .78 * dx, y2 - .78 * dy)
    return (
        f'<path d="{line}" fill="none" stroke="{color}" stroke-width="{weight}"/>'
        f'<path d="{end}" fill="{color}" stroke="none"/>'
    )


def air_resistance_points(x1, y1, x2, y2):
    dx, dy = x2 - x1, y2 - y1
    length = hypot(dx, dy)
    ux, uy = dx / length, dy / length
    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    profile = ((-7, 0), (-5.25, 2.8), (-1.75, -2.8), (1.75, 2.8), (5.25, -2.8), (7, 0))
    return " L ".join(
        f"{cx + ux*along - uy*across:.2f},{cy + uy*along + ux*across:.2f}"
        for along, across in profile
    )


def interaction(x1, y1, x2, y2, *, air_exchange=False):
    middle = f" L {air_resistance_points(x1, y1, x2, y2)}" if air_exchange else ""
    classes = "physical-interaction air-resistance" if air_exchange else "physical-interaction"
    return (
        f'<path class="{classes}" d="M {x1},{y1}{middle} L {x2},{y2}" fill="none" '
        f'stroke="{INTERACTION_COLOR}" stroke-width="{INTERACTION_WIDTH}" '
        'stroke-linecap="round" stroke-linejoin="round"/>'
    )


def model_node(x, y, radius=4.15):
    return f'<circle cx="{x}" cy="{y}" r="{radius}" fill="{NODE}" stroke="#76272a" stroke-width="1"/>'


def building_temperature_nodes(indoor_x, wall_surface, wall_centres, *, label_x):
    roof_levels = (429, 441, 453)
    wall_levels = (*wall_centres, wall_surface)
    elements = [
        interaction(indoor_x, ROOF_NODE_LEVEL, indoor_x, roof_levels[0]),
        model_node(indoor_x, ROOF_NODE_LEVEL),
    ]
    for top, bottom in zip(roof_levels, roof_levels[1:]):
        elements.append(interaction(indoor_x, top, indoor_x, bottom))
    for near, far in zip(wall_levels, wall_levels[1:]):
        elements.append(interaction(near, 500, far, 500))
    elements.append(interaction(indoor_x, roof_levels[-1], indoor_x, 500, air_exchange=True))
    elements.append(interaction(indoor_x, 500, wall_centres[0], 500, air_exchange=True))
    elements.extend(model_node(indoor_x, y, LAYER_NODE_RADIUS) for y in roof_levels)
    elements.extend(model_node(x, 500, LAYER_NODE_RADIUS) for x in wall_centres)
    elements.append(model_node(wall_surface, 500))
    elements.append(model_node(indoor_x, 500, 5))
    elements.append(
        f'<text x="{label_x}" y="523" text-anchor="middle" fill="{LABEL_TEXT}" '
        f'font-size="{FEATURE_LABEL_SIZE}">Indoor air</text>'
    )
    elements.append(
        f'<text x="{label_x}" y="543" text-anchor="middle" fill="{LABEL_TEXT}" '
        'font-size="17" font-style="italic">Tᵢ, qᵢ</text>'
    )
    return "\n".join(elements)


def external_profile(left, top):
    layers = ("#dedfe1", "#c7c9cc", "#aeb2b6", "#979ca1")
    sides = ("#bfc2c5", "#a8adb1", "#90969b", "#7d8389")
    width = 34
    right = left + width
    pieces = ['<g stroke="#565b60" stroke-width="1.1" stroke-linejoin="round">']
    for i, (layer, side) in enumerate(zip(layers, sides)):
        y = top + i * 9
        pieces.append(
            f'<path d="M {right},{y} l 10,-6 v 9 l -10,6 Z" fill="{side}"/>'
            f'<rect x="{left}" y="{y}" width="{width}" height="9" fill="{layer}"/>'
        )
    pieces.append(f'<path d="M {left},{top} l 10,-6 h {width} l -10,6 Z" fill="#f1f2f3"/></g>')
    return "\n".join(pieces)


def interface_card(x, y, name, label, *, width=124, palette=LAND_INTERFACE_PALETTE):
    fill, border, heading, subtitle = palette
    return f'''<rect x="{x - width // 2}" y="{y - 37}" width="{width}" height="74" rx="3" ry="3"
          fill="{fill}" stroke="{border}" stroke-width="1.8"/>
    <text x="{x}" y="{y - 5}" text-anchor="middle" fill="{heading}" font-size="19" font-weight="700">{name}</text>
    <text x="{x}" y="{y + 16}" text-anchor="middle" fill="{subtitle}" font-size="14.5">{label}</text>'''


def exchange_label(x, y, lines, *, anchor="middle"):
    body = " ".join(
        f'<text x="{x}" y="{y + row * 17}">{line}</text>'
        for row, line in enumerate(lines)
    )
    return f'<g text-anchor="{anchor}" fill="{EXTERNAL_MODEL_TEXT}" font-size="{EXCHANGE_LABEL_SIZE}">{body}</g>'


def branch(surface, y, key, surface_route, forcing_groups, *, dashed_return=False):
    incoming_y = y - EXCHANGE_ARROW_OFFSET
    outgoing_y = y + EXCHANGE_ARROW_OFFSET
    interface_right = LAND_INTERFACE_ARROW_X + LAND_INTERFACE_WIDTH
    proxy_right = LAND_PROXY_X + LAND_PROXY_WIDTH
    proxy_y = y + 77
    surface_groups = ("Surface state", "and properties", "Heat and moisture", "fluxes and runoff")
    surface_path = " ".join(dashed_line(*start, *end) for start, end in zip(surface_route, surface_route[1:]))
    return f'''
  <g id="{key}-surface-options">
    <title>{surface}: external layered land surface model or built-in diagnostic proxy</title>
    <g id="{key}-external-model">
      <rect x="{LAND_MODEL_X}" y="{y-42}" width="{LAND_MODEL_WIDTH}" height="84" rx="3" ry="3"
            fill="{EXTERNAL_MODEL_FILL}" stroke="{EXTERNAL_MODEL_EDGE}" stroke-width="1.6"/>
      {external_profile(LAND_MODEL_X + 12, y - 15)}
      <g fill="{EXTERNAL_MODEL_TEXT}">
        <text x="{LAND_MODEL_X + 64}" y="{y-14}" font-size="{MODEL_HEADING_SIZE}" font-weight="700">External land</text>
        <text x="{LAND_MODEL_X + 64}" y="{y+5}" font-size="{MODEL_HEADING_SIZE}" font-weight="700">surface model</text>
        <text x="{LAND_MODEL_X + 64}" y="{y+24}" font-size="{MODEL_DETAIL_SIZE}">Layered column</text>
      </g>
    </g>
    <g id="{key}-external-exchanges">
      {exchange_arrow(LAND_MODEL_ARROW_X, incoming_y, LAND_INTERFACE_ARROW_X, incoming_y)}
      {exchange_label(LAND_EXCHANGE_LABEL_X, incoming_y - 60, surface_groups)}
      {exchange_arrow(LAND_INTERFACE_ARROW_X, outgoing_y, LAND_MODEL_ARROW_X, outgoing_y,
                      dashed=dashed_return)}
      {exchange_label(LAND_EXCHANGE_LABEL_X, outgoing_y + 21, forcing_groups)}
    </g>
    <g id="{key}-interface-links" fill="none" stroke="{EXCHANGE}" stroke-width="1.65" stroke-linecap="round">
      <path d="{dashed_line(interface_right, y, LAND_CHOICE_X - LAND_CHOICE_RADIUS, y)}"/>
      <path d="{dashed_line(proxy_right, proxy_y, LAND_CHOICE_X, proxy_y)}
               {dashed_line(LAND_CHOICE_X, y + LAND_CHOICE_RADIUS, LAND_CHOICE_X, proxy_y)}"/>
      <path d="{surface_path}"/>
    </g>

    {interface_card(LAND_INTERFACE_X, y, surface, "LSM interface", width=LAND_INTERFACE_WIDTH)}

    <rect x="{LAND_PROXY_X}" y="{y+48}" width="{LAND_PROXY_WIDTH}" height="59" rx="3" ry="3"
          fill="#eef5e7" stroke="#658052" stroke-width="1.6"/>
    <path d="M {LAND_PROXY_X + 10},{y+82} l 8,-9 h 24 l -8,9 Z" fill="#93c653" stroke="#466d36" stroke-width="1.3"/>
    <path d="M {LAND_PROXY_X + 17},{y+80} l 2,-3 m 5,3 l 2,-3 m 5,3 l 2,-3"
          fill="none" stroke="#4e7935" stroke-width="1.15" stroke-linecap="round"/>
    <text x="{LAND_PROXY_X + 47}" y="{y+74}" fill="{LAND_INTERFACE_PALETTE[2]}"
          font-size="{MODEL_HEADING_SIZE}" font-weight="700">Built-in proxy</text>
    <text x="{LAND_PROXY_X + 47}" y="{y+94}" fill="{LAND_INTERFACE_PALETTE[3]}"
          font-size="{MODEL_DETAIL_SIZE}">Diagnostic surface</text>

    <circle cx="{LAND_CHOICE_X}" cy="{y}" r="{LAND_CHOICE_RADIUS}" fill="#fff" stroke="#666054" stroke-width="1.6"/>
    <text x="{LAND_CHOICE_X}" y="{y+5}" text-anchor="middle" fill="{LABEL_TEXT}"
          font-size="{EXCHANGE_LABEL_SIZE}" font-weight="700">OR</text>
  </g>'''


def building_layers(front, inside, right=False):
    roof_y, width = 423, 116
    parts = []
    for i in range(3):
        y = roof_y + i * 12
        parts.append(f'<rect x="{front}" y="{y}" width="{width}" height="12"/>')
    for i in range(3):
        x = inside + 12 * i if right else inside - 12 * (i + 1)
        parts.append(f'<rect x="{x}" y="459" width="12" height="155"/>')
    return (
        f'<g fill="{BUILDING_LAYER_FILL}" stroke="{LAYER_EDGE}" stroke-width="{LAYER_LINE_WIDTH}">\n'
        + "\n".join(parts) + '\n</g>'
    )


def road_layers():
    return "\n".join(
        f'<rect x="{ROAD_NEAR_LEFT}" y="{ROAD_LAYER_TOP + i * ROAD_LAYER_HEIGHT}" '
        f'width="{ROAD_NEAR_RIGHT - ROAD_NEAR_LEFT}" height="{ROAD_LAYER_HEIGHT}" fill="{fill}"/>'
        for i, fill in enumerate(MATERIALS)
    )


def road_hatching():
    paths = []
    depth = ROAD_LAYER_TOP - ROAD_FAR_Y
    for fraction in (i / 16 for i in range(1, 16)):
        near = ROAD_NEAR_LEFT + fraction * (ROAD_NEAR_RIGHT - ROAD_NEAR_LEFT)
        far = ROAD_FAR_LEFT + fraction * (ROAD_FAR_RIGHT - ROAD_FAR_LEFT)
        paths.append(f"M {near + (far - near) * 3 / depth:.2f},611 L {far + (near - far) * 4 / depth:.2f},579")
    return " ".join(paths)


def road_point(fraction, depth, *, lift=0):
    near = ROAD_NEAR_LEFT + fraction * (ROAD_NEAR_RIGHT - ROAD_NEAR_LEFT)
    far = ROAD_FAR_LEFT + fraction * (ROAD_FAR_RIGHT - ROAD_FAR_LEFT)
    x = far + (near - far) * depth
    y = ROAD_FAR_Y + (ROAD_LAYER_TOP - ROAD_FAR_Y) * depth - lift
    return f"{x:.2f},{y:.2f}"


def left_roof_point(fraction, depth, *, lift=0):
    x = 954 + 116 * fraction - 33 * depth
    y = 384 + ROOF_DEPTH * depth - lift
    return f"{x:.2f},{y:.2f}"


def right_roof_point(fraction, depth, *, lift=0):
    x = 1378 + 116 * fraction + 33 * depth
    y = 384 + ROOF_DEPTH * depth - lift
    return f"{x:.2f},{y:.2f}"


def surface_band(point, start, end, *, lift=0, depth_range=(0, 1)):
    far, near = depth_range
    corners = ((start, near), (end, near), (end, far), (start, far))
    return " ".join(point(fraction, depth, lift=lift) for fraction, depth in corners)


def rounded_water_band(point, start, end):
    # Round the corners in the projected surface plane.
    corner_width = (end - start) * 4 / 15
    left, right = start + corner_width, end - corner_width
    near, far = 1 - WATER_BAND_DEPTH_INSET, WATER_BAND_DEPTH_INSET
    near_tangent, far_tangent = near - WATER_CORNER_DEPTH, far + WATER_CORNER_DEPTH
    return (
        f"M {point(left, near)} L {point(right, near)} "
        f"Q {point(end, near)} {point(end, near_tangent)} "
        f"L {point(end, far_tangent)} Q {point(end, far)} {point(right, far)} "
        f"L {point(left, far)} Q {point(start, far)} {point(start, far_tangent)} "
        f"L {point(start, near_tangent)} Q {point(start, near)} {point(left, near)} Z"
    )


def snow_band_side(point, start, end, thickness, *, depth_range=(0, 1)):
    far, near = depth_range
    edge = ((start, far), (start, near), (end, near))
    upper = [point(fraction, depth, lift=thickness) for fraction, depth in edge]
    lower = [point(fraction, depth) for fraction, depth in reversed(edge)]
    return " ".join([*upper, *lower])


def traffic_vehicle():
    return f'''
    <g id="traffic-vehicle" transform="translate({CAR_X},{CAR_BASE_Y:.3f}) scale({CAR_SCALE})"
       stroke="#694836" stroke-width="1.15" stroke-linejoin="round">
      <title>Side view of the car on the left side of the road</title>
      <path d="M -22,0 V -6 Q -22,-8 -17,-10 L -14,-11 L -9,{-CAR_ROOF_HEIGHT}
               H 5 Q 10,{-CAR_ROOF_HEIGHT} 14,-11 L 19,-9 Q 22,-8 22,-4 V 0 Z"
            fill="#cb8055"/>
      <path d="M -11,-11 L -7,-17 H 5 Q 8,-17 11,-11 Z" fill="#f1efe1" stroke-width=".85"/>
      <path d="M 1,-17 V -11 M -16,-3 H 16" fill="none" stroke-width=".85"/>
      <path d="M 19,-6 H 22" fill="none" stroke="#fff2d4" stroke-width="1.7"/>
      <g fill="{CAR_TIRE_FILL}" stroke="none">
        <circle cx="-13" cy="0" r="{CAR_WHEEL_RADIUS}"/>
        <circle cx="13" cy="0" r="{CAR_WHEEL_RADIUS}"/>
      </g>
      <g fill="#d8d1c3" stroke="none">
        <circle cx="-13" cy="0" r="1.4"/>
        <circle cx="13" cy="0" r="1.4"/>
      </g>
    </g>'''


def road_layer_interactions():
    x, surface_y = ROAD_SURFACE_NODE
    centres = [ROAD_LAYER_TOP + (i + .5) * ROAD_LAYER_HEIGHT for i in range(len(MATERIALS))]
    levels = [surface_y, *centres]
    links = [
        interaction(x, upper, x, lower)
        for upper, lower in zip(levels, centres)
    ]
    return "\n".join([*links, *(model_node(x, y, LAYER_NODE_RADIUS) for y in centres)])


def bem_window(x):
    return f'''<rect x="{x}" y="{-BEM_OPENING_HALF_HEIGHT}" width="{BEM_OPENING_WIDTH}" height="{2 * BEM_OPENING_HALF_HEIGHT}"
                    fill="#c4dce4" stroke-width="1.3"/>
          <path d="M {x + 5},{-BEM_OPENING_HALF_HEIGHT} V {BEM_OPENING_HALF_HEIGHT}
                   M {x},0 H {x + 10}" fill="none" stroke-width=".95"/>'''


def bem_outdoor_unit():
    left, right = BEM_AC_OFFSET, BEM_AC_OFFSET + BEM_OPENING_WIDTH
    top, bottom = -BEM_OPENING_HALF_HEIGHT, BEM_OPENING_HALF_HEIGHT
    depth = BEM_AC_DEPTH
    lift = round(-depth * BEM_FACADE_SLOPE, 4)
    fan_centre_x = (left + right) / 2
    fan_blade = "M 0,-.6 C -1.7,-.85 -2.4,-2.4 -1.05,-2.95 C .38,-3.52 1.55,-1.57 .57,-.83 Z"
    return f'''
        <g id="left-bem-outdoor-unit" stroke-width="1.2">
          <title>Outdoor air-conditioning unit on the canyon-facing wall</title>
          <path d="M {left},{top} H {right} l {depth},{lift} H {left+depth} Z" fill="#f8faf9"/>
          <path d="M {left},{top} l {depth},{lift} V {bottom+lift} l {-depth},{-lift} Z" fill="#c9d3d7"/>
          <g id="left-bem-outdoor-unit-face" transform="translate({depth},{lift})">
            <rect x="{left}" y="{top}" width="{BEM_OPENING_WIDTH}" height="{2 * BEM_OPENING_HALF_HEIGHT}" fill="#edf0f1"/>
            <path d="M {left+2},8 H {right-2} M {left+2},11 H {right-2} M {left+2},14 H {right-2}"
                  fill="none" stroke-width=".9" stroke-linecap="round"/>
            <g id="left-bem-outdoor-unit-fan" transform="translate({fan_centre_x},-9) scale(1,1.9)" stroke="none">
              <title>Condenser fan</title>
              <circle r="4" fill="#43606d"/>
              <g fill="#f5f8f7">
                <path d="{fan_blade}"/>
                <path d="{fan_blade}" transform="rotate(120)"/>
                <path d="{fan_blade}" transform="rotate(240)"/>
                <circle r=".65"/>
              </g>
            </g>
          </g>
        </g>'''


roof = branch(
    "Green Roof", 300, "green-roof",
    ((LAND_SURFACE_LINK_X, 300), (851, 300), (GREEN_ROOF_X, ROOF_NODE_LEVEL)),
    ("Atmospheric forcing", "Exchange", "coefficients"), dashed_return=True,
)
garden = branch(
    "Garden", 523, "garden",
    ((LAND_SURFACE_LINK_X, 523), (872, 523), (872, 650), (GARDEN_SURFACE_X, 650), (GARDEN_SURFACE_X, GARDEN_SURFACE_Y)),
    ("Canyon air and", "radiative forcing", "Exchange", "coefficients"),
)
air_to_teb = ("Air state and wind", "Downward radiation", "Precipitation")
teb_to_air = ("Urban surface fluxes", "Surface state", "Radiative properties", "Exchange coefficients")
bem_fork = (989, 483)
bem_indoor_bend_x = LEFT_WALL_FACE_X - 12
window_centre_offset = BEM_WINDOW_OFFSET + BEM_OPENING_WIDTH / 2
ac_centre_offset = BEM_AC_OFFSET + BEM_OPENING_WIDTH / 2
window_centre_x = LEFT_WALL_FACE_X + window_centre_offset
ac_centre_x = LEFT_WALL_FACE_X + ac_centre_offset + BEM_AC_DEPTH
window_line_y = round(BEM_OPENINGS_Y + window_centre_offset * BEM_FACADE_SLOPE, 2)
ac_line_y = round(BEM_OPENINGS_Y + ac_centre_offset * BEM_FACADE_SLOPE, 2)
window_outer_x = LEFT_WALL_FACE_X + BEM_WINDOW_OFFSET + BEM_OPENING_WIDTH
# The window branch passes below the outdoor unit on the projected façade.
window_bend = (LEFT_WALL_FACE_X + ac_centre_offset - 1.5, 487)
bem_merge_x = 1110
green_roof_marks = " ".join(
    f"M {left_roof_point(fraction, depth)} l 3,-4"
    for depth in (.37, .57, .79)
    for fraction in (.075, .17)
)
solar_panel_centre = sum(SOLAR_PANEL_BAND) / 2
solar_panel_grid = " ".join(
    f"M {left_roof_point(SOLAR_PANEL_BAND[0], depth)} L {left_roof_point(SOLAR_PANEL_BAND[1], depth)}"
    for depth in (.25, .5, .75)
)
svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_WIDTH}" height="752"
     viewBox="0 0 {CANVAS_WIDTH} 752" xml:lang="en" role="img" aria-labelledby="title description"
     font-family="Arial, DejaVu Sans, sans-serif">
  <title id="title">TEB-MSU urban canopy thermal network and coupling interfaces</title>
  <desc id="description">
    Each arrow between an external model and an interface is labelled with the groups of data exchanged in that direction.
    The atmosphere supplies air state, wind, radiation and precipitation and receives urban surface fluxes, properties and exchange coefficients.
    The external garden receives canyon air and radiative forcing and exchange coefficients. Garden and Green Roof return surface states and properties, heat and moisture fluxes and runoff.
    A dashed arrow marks the potential return path for atmospheric forcing and exchange coefficients for the green roof.
    The atmospheric coupling interface connects to the dashed horizontal forcing line on the right. A green brace groups the urban surfaces and one arrow carries their aggregate heat and moisture fluxes to this line.
    Purple BEM links connect indoor air in the left building to canyon air via a window and an outdoor air-conditioning unit.
    The canyon-side segments meet the centres of the window and the unit. At the matching heights, the branches run horizontally from the cut edge before turning toward the indoor air node.
    The BEM label identifies windows, HVAC and internal heat gains. Two more windows sit below the openings.
    An orange arrow with right-angle bends marks sensible heat entering the canyon air from the car on the left side of the road. The car rests at the same schematic road level as the road surface, standing water and snow nodes.
    Road and roof puddles are drawn as rounded bands separated from the front and back edges and from the adjacent snow bands.
    The road snow band matches the width and the visible front and back margins of the road puddle.
    Aligned labels identify the garden, road, puddle and snow links to canyon air.
    The road temperature node connects to four subsurface layer nodes. Road snow and liquid water exchange with canyon air.
    In each building, indoor air, three roof layer nodes and the conventional roof surface line up vertically beneath the atmospheric forcing level. Separate thermal links pass through the wall layer nodes.
    The snow and water bands sit in that order from the canyon side of the right roof. On the left roof, the green roof sits to the left of the conventional surface node, and the solar panel sits to the right.
    Nodes on both roof surfaces share one drawing height.
    All four features have matching visible margins at the front and back roof edges.
    The roof snow, liquid water and solar panel exchange with the atmosphere. Red dots mark model nodes. Solid lines show physical interactions, with a short zigzag for turbulent exchange with a computed coefficient.
    Garden and Green Roof can each use an external layered land surface model or the built-in diagnostic proxy. Green dashed links connect each interface through the model choice to its red surface node.
  </desc>

  <g id="teb-msu-layout" transform="translate({LAYOUT_SHIFT_X},0)"
     font-family="Arial, DejaVu Sans, sans-serif">
  <g fill="{EXTERNAL_MODEL_TEXT}" font-size="17.5" font-weight="700">
    <text x="{LAND_MODEL_X}" y="211">External land</text>
    <text x="{LAND_MODEL_X}" y="231">surface models</text>
  </g>
  <g id="teb-msu-domain">
    <rect x="{DOMAIN_LEFT}" y="139" width="{DOMAIN_RIGHT-DOMAIN_LEFT}" height="598" rx="4" ry="4"
          fill="{DOMAIN_FILL}" stroke="#aa9786" stroke-width="1.8"/>
    <text x="{DOMAIN_LEFT + 26}" y="188" fill="#924820" font-size="27" font-weight="700">TEB-MSU</text>
  </g>
  <g id="network-key" transform="translate({DOMAIN_LEFT + 26},0)"
     fill="{SECONDARY_TEXT}" font-size="{LAYER_LABEL_SIZE}">
    {model_node(4.15, 205)}
    <text x="56" y="210">Model node</text>
    {interaction(0, 224, 44, 224)}
    <text x="56" y="229">Physical interaction</text>
    {interaction(0, 243, 44, 243, air_exchange=True)}
    <text x="56" y="248">Turbulent exchange</text>
  </g>
  <g id="atmospheric-coupling">
    <rect x="{ATMOSPHERIC_INTERFACE_X - LAND_MODEL_WIDTH / 2}" y="20" width="{LAND_MODEL_WIDTH}" height="56" rx="3" ry="3"
          fill="{EXTERNAL_MODEL_FILL}" stroke="{EXTERNAL_MODEL_EDGE}" stroke-width="1.6"/>
    <text x="{ATMOSPHERIC_INTERFACE_X}" y="54" text-anchor="middle" fill="{EXTERNAL_MODEL_TEXT}"
          font-size="{MODEL_HEADING_SIZE}" font-weight="700">Atmospheric model</text>
    <g id="atmosphere-to-teb">
      {exchange_arrow(ATMOSPHERIC_INTERFACE_X - EXCHANGE_ARROW_OFFSET, 76,
                      ATMOSPHERIC_INTERFACE_X - EXCHANGE_ARROW_OFFSET, 185)}
      {exchange_label(ATMOSPHERIC_INTERFACE_X - EXCHANGE_ARROW_OFFSET - 12, 98, air_to_teb, anchor="end")}
    </g>
    <g id="teb-to-atmosphere">
      {exchange_arrow(ATMOSPHERIC_INTERFACE_X + EXCHANGE_ARROW_OFFSET, 185,
                      ATMOSPHERIC_INTERFACE_X + EXCHANGE_ARROW_OFFSET, 76)}
      {exchange_label(ATMOSPHERIC_INTERFACE_X + EXCHANGE_ARROW_OFFSET + 12, 98, teb_to_air, anchor="start")}
    </g>
    <g id="atmospheric-forcing-interface">
      <path id="atmospheric-level-line"
            d="{dashed_line(925, ATMOSPHERIC_LEVEL, ATMOSPHERIC_INTERFACE_LEFT, ATMOSPHERIC_LEVEL)}"
            fill="none" stroke="{OUTLINE_COLOR}" stroke-width="1.55" stroke-linecap="round"/>
      <text x="{ATMOSPHERIC_INTERFACE_LEFT-14}" y="{ATMOSPHERIC_LEVEL-13}" text-anchor="end"
            fill="{SECONDARY_TEXT}" font-size="{FEATURE_LABEL_SIZE}">Atmospheric forcing level</text>
      {interface_card(ATMOSPHERIC_INTERFACE_X, ATMOSPHERIC_LEVEL, "Atmosphere", "Coupling interface",
                      width=ATMOSPHERIC_INTERFACE_WIDTH, palette=ATMOSPHERIC_INTERFACE_PALETTE)}
    </g>
  </g>

  <g id="surface-network-layout">
  <g id="canyon-geometry" stroke="{OUTLINE_COLOR}" stroke-width="2" stroke-linejoin="round">
    <g id="road-layers" stroke="{LAYER_EDGE}" stroke-width="{LAYER_LINE_WIDTH}">
      {road_layers()}
    </g>
    <path id="garden-surface" d="M 1037,614 H {ROAD_NEAR_LEFT} L {ROAD_FAR_LEFT},575 H 1070 Z" fill="#93c653"/>
    <path id="road-surface" d="M {ROAD_NEAR_LEFT},614 H {ROAD_NEAR_RIGHT}
                              L {ROAD_FAR_RIGHT},575 H {ROAD_FAR_LEFT} Z" fill="#dfddd8"/>
    <path d="{road_hatching()}"
          fill="none" stroke="#aeaaa1" stroke-width="1.2" stroke-linecap="round"/>
    <g id="road-surface-hydrology" stroke-width="1.4">
      <path id="road-surface-water" d="{rounded_water_band(road_point, *ROAD_WATER_BAND)}"
            fill="{WATER_FILL}" stroke="{WATER_EDGE}"/>
      <path d="M {road_point(.646, .33)} Q {road_point(.674, .27)} {road_point(.706, .30)}
               M {road_point(.701, .75)} Q {road_point(.73, .68)} {road_point(.762, .72)}"
            fill="none" stroke="#e9f7ff" stroke-width="1" stroke-linecap="round"/>
      <g id="road-snow-cover-pack" stroke="{SNOW_EDGE}" stroke-width="1.15">
        <polygon id="road-snow-cover-side"
                 points="{snow_band_side(road_point, *ROAD_SNOW_BAND, ROAD_SNOW_DEPTH,
                                          depth_range=ROAD_SNOW_DEPTH_RANGE)}"
                 fill="{SNOW_SIDE_FILL}"/>
        <polygon id="road-snow-cover"
                 points="{surface_band(road_point, *ROAD_SNOW_BAND,
                                       lift=ROAD_SNOW_DEPTH, depth_range=ROAD_SNOW_DEPTH_RANGE)}"
                 fill="{SNOW_FILL}"/>
      </g>
    </g>
    {traffic_vehicle()}
    <path d="M 1055,608 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4
             M 1068,595 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4
             M 1082,584 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4 m 16,4 l 3,-4"
          fill="none" stroke="#4e7935" stroke-width="1.25" stroke-linecap="round"/>
    <g id="left-building">
      <path d="M 921,423 L 954,384 H 1070 L 1037,423 Z" fill="{ROOF_FILL}"/>
      <path d="M 1037,423 L 1070,384 V 575 L 1037,614 Z" fill="{SIDE_WALL_FILL}"/>
      <rect x="921" y="423" width="116" height="191" fill="{FRONT_WALL_FILL}"/>
      {building_layers(921, LEFT_WALL_FACE_X)}
      <g id="left-bem-openings" transform="matrix(1,{BEM_FACADE_SLOPE:.6f},0,1,{LEFT_WALL_FACE_X},{BEM_OPENINGS_Y})"
         stroke="#4f6f7f">
        <g id="left-bem-window">
          <title>Window on the canyon-facing wall</title>
          {bem_window(BEM_WINDOW_OFFSET)}
        </g>
        {bem_outdoor_unit()}
        <g id="left-bem-lower-windows" transform="translate(0,75)">
          <title>Two lower windows on the canyon-facing wall</title>
          {bem_window(BEM_WINDOW_OFFSET)}
          {bem_window(BEM_LOWER_WINDOW_OFFSET)}
        </g>
      </g>
      <g id="green-roof-strip">
        <polygon points="{surface_band(left_roof_point, *GREEN_ROOF_BAND, depth_range=ROOF_SURFACE_DEPTH_RANGE)}"
                 fill="#93c653" stroke="{ROOF_STRIP_EDGE}" stroke-width="{ROOF_STRIP_EDGE_WIDTH}"/>
        <path d="{green_roof_marks}"
              fill="none" stroke="#4e7935" stroke-width="1.25" stroke-linecap="round"/>
      </g>
      <g id="solar-panel-strip">
        <polygon points="{surface_band(left_roof_point, *SOLAR_PANEL_BAND, depth_range=ROOF_SURFACE_DEPTH_RANGE)}"
                 fill="#527eaa" stroke="{ROOF_STRIP_EDGE}" stroke-width="{ROOF_STRIP_EDGE_WIDTH}"/>
        <path d="M {left_roof_point(solar_panel_centre, ROOF_SURFACE_DEPTH_RANGE[0])}
                 L {left_roof_point(solar_panel_centre, ROOF_SURFACE_DEPTH_RANGE[1])}
                 {solar_panel_grid}"
              fill="none" stroke="#b5d5ef" stroke-width="1" stroke-linecap="round"/>
      </g>
    </g>
    <g id="right-building">
      <path d="M 1411,423 L 1378,384 H 1494 L 1527,423 Z" fill="{ROOF_FILL}"/>
      <path d="M 1411,423 L 1378,384 V 575 L 1411,614 Z" fill="{SIDE_WALL_FILL}"/>
      <rect x="1411" y="423" width="116" height="191" fill="{FRONT_WALL_FILL}"/>
      {building_layers(1411, 1411, right=True)}
      <g id="conventional-roof-surface-hydrology" stroke-width="1.4">
        <path id="roof-surface-water" d="{rounded_water_band(right_roof_point, *RIGHT_ROOF_WATER_BAND)}"
              fill="{WATER_FILL}" stroke="{WATER_EDGE}"/>
        <path d="M {right_roof_point(.311, .33)} Q {right_roof_point(.342, .27)} {right_roof_point(.376, .30)}
                 M {right_roof_point(.360, .75)} Q {right_roof_point(.395, .68)} {right_roof_point(.440, .72)}"
              fill="none" stroke="#e9f7ff" stroke-width="1" stroke-linecap="round"/>
        <g id="roof-snow-cover-pack" stroke="{SNOW_EDGE}" stroke-width="1.15">
          <polygon id="roof-snow-cover-side"
                   points="{snow_band_side(right_roof_point, *RIGHT_ROOF_SNOW_BAND, RIGHT_ROOF_SNOW_DEPTH,
                                            depth_range=ROOF_SNOW_DEPTH_RANGE)}"
                   fill="{SNOW_SIDE_FILL}"/>
          <polygon id="roof-snow-cover"
                   points="{surface_band(right_roof_point, *RIGHT_ROOF_SNOW_BAND,
                                         lift=RIGHT_ROOF_SNOW_DEPTH, depth_range=ROOF_SNOW_DEPTH_RANGE)}"
                   fill="{SNOW_FILL}"/>
        </g>
      </g>
    </g>
  </g>

  {roof}
  {garden}

  <g id="physical-node-interactions">
    <g id="green-roof-to-atmosphere">
      {interaction(GREEN_ROOF_X, ATMOSPHERIC_LEVEL, GREEN_ROOF_X, ROOF_NODE_LEVEL, air_exchange=True)}
      <text x="{GREEN_ROOF_X - 12}" y="{ROOF_LABEL_Y}" text-anchor="end"
            fill="{LABEL_TEXT}" font-size="{FEATURE_LABEL_SIZE}">Green roof</text>
    </g>
    <g id="left-roof-to-atmosphere">
      {interaction(LEFT_INDOOR_X, ATMOSPHERIC_LEVEL, LEFT_INDOOR_X, ROOF_NODE_LEVEL, air_exchange=True)}
    </g>
    <g id="right-conventional-roof-atmosphere-branch">
      <path class="physical-interaction" d="M {RIGHT_INDOOR_X},{ATMOSPHERIC_LEVEL} V 337 H {RIGHT_ROOF_SNOW_NODE[0]}"
            fill="none" stroke="{INTERACTION_COLOR}"
            stroke-width="{INTERACTION_WIDTH}" stroke-linecap="round" stroke-linejoin="round"/>
      <g id="roof-to-atmosphere">
        {interaction(RIGHT_INDOOR_X, 337, RIGHT_INDOOR_X, ROOF_NODE_LEVEL, air_exchange=True)}
        <text x="{RIGHT_INDOOR_X - 14}" y="{ROOF_LABEL_Y}" text-anchor="end" fill="{LABEL_TEXT}"
              font-size="{FEATURE_LABEL_SIZE}">Conventional roof</text>
      </g>
      <g id="roof-water-to-atmosphere">
        <title>Right roof liquid water storage and moisture exchange with the atmosphere</title>
        {interaction(RIGHT_ROOF_WATER_NODE[0], 337, *RIGHT_ROOF_WATER_NODE, air_exchange=True)}
        {model_node(*RIGHT_ROOF_WATER_NODE)}
      </g>
      <g id="roof-snow-to-atmosphere">
        <title>Right roof snow temperature and heat exchange with the atmosphere</title>
        {interaction(RIGHT_ROOF_SNOW_NODE[0], 337, *RIGHT_ROOF_SNOW_NODE, air_exchange=True)}
        {model_node(*RIGHT_ROOF_SNOW_NODE)}
      </g>
    </g>
    <g id="solar-panel-to-atmosphere">
      {interaction(SOLAR_PANEL_X, ATMOSPHERIC_LEVEL, SOLAR_PANEL_X, ROOF_NODE_LEVEL)}
      <g fill="{LABEL_TEXT}" font-size="{FEATURE_LABEL_SIZE}">
        <text x="{SOLAR_PANEL_X + 14}" y="{ROOF_LABEL_Y}">Solar</text>
        <text x="{SOLAR_PANEL_X + 14}" y="{ROOF_LABEL_Y + 18}">panel</text>
      </g>
    </g>
    <g id="canyon-to-atmosphere">
      {interaction(ATMOSPHERE_X, ATMOSPHERIC_LEVEL, ATMOSPHERE_X, 500, air_exchange=True)}
    </g>
    <g id="left-wall-to-canyon">
      {interaction(1055, 500, 1224, 500, air_exchange=True)}
      <text x="1094" y="490" text-anchor="middle" fill="{LABEL_TEXT}" font-size="{FEATURE_LABEL_SIZE}">Wall</text>
    </g>
    <g id="right-wall-to-canyon">
      {interaction(1224, 500, 1393, 500, air_exchange=True)}
      <text x="1354" y="490" text-anchor="middle" fill="{LABEL_TEXT}" font-size="{FEATURE_LABEL_SIZE}">Wall</text>
    </g>
    <g id="left-bem-air-link">
      <title>Building energy exchange between indoor air and canyon air via the window and outdoor unit</title>
      <g class="physical-interaction" fill="none" stroke="{BEM_AIR_EXCHANGE}" stroke-width="{INTERACTION_WIDTH}"
         stroke-linecap="round" stroke-linejoin="round">
        <g id="bem-indoor-links">
          <path d="M {LEFT_INDOOR_X},500 L {bem_fork[0]},{bem_fork[1]}"/>
          <path id="bem-indoor-window-branch"
                d="M {LEFT_WALL_FACE_X},{window_line_y} H {bem_indoor_bend_x} L {bem_fork[0]},{bem_fork[1]}"/>
          <path id="bem-indoor-ac-branch"
                d="M {LEFT_WALL_FACE_X},{ac_line_y} H {bem_indoor_bend_x} L {bem_fork[0]},{bem_fork[1]}"/>
        </g>
        <path id="bem-window-branch" class="air-resistance"
              d="M {window_centre_x:g},{window_line_y} H {window_outer_x}
                 L {window_bend[0]},{window_bend[1]}
                 L {air_resistance_points(*window_bend, bem_merge_x, ac_line_y)} L {bem_merge_x},{ac_line_y}"/>
        <path id="bem-ac-branch" d="M {ac_centre_x:g},{ac_line_y} H {bem_merge_x}"/>
        <path d="M {bem_merge_x},{ac_line_y} H 1199 L {ATMOSPHERE_X},500"/>
      </g>
      <circle cx="{bem_fork[0]}" cy="{bem_fork[1]}" r="2" fill="{BEM_AIR_EXCHANGE}"/>
      <circle cx="{bem_merge_x}" cy="{ac_line_y}" r="2" fill="{BEM_AIR_EXCHANGE}"/>
      <g id="bem-label" text-anchor="middle" fill="{BEM_AIR_EXCHANGE}">
        <text x="1146" y="401" font-size="{MODEL_HEADING_SIZE}" font-weight="700">BEM</text>
        <text x="1146" y="420" font-size="{EXCHANGE_LABEL_SIZE}">Windows and HVAC</text>
        <text x="1146" y="437" font-size="{EXCHANGE_LABEL_SIZE}">Internal heat gains</text>
      </g>
    </g>
    <path id="ground-to-canyon-bus" class="physical-interaction"
          d="M {GARDEN_SURFACE_X},540 H 1189 L {ATMOSPHERE_X},500 L 1253,540 H {ROAD_SNOW_NODE[0]}"
          fill="none" stroke="{INTERACTION_COLOR}"
          stroke-width="{INTERACTION_WIDTH}" stroke-linecap="round" stroke-linejoin="round"/>
    <g id="garden-to-canyon">
      {interaction(GARDEN_SURFACE_X, 540, GARDEN_SURFACE_X, GARDEN_SURFACE_Y, air_exchange=True)}
    </g>
    <g id="road-to-canyon">
      {interaction(ROAD_SURFACE_NODE[0], 540, *ROAD_SURFACE_NODE, air_exchange=True)}
    </g>
    <g id="road-layer-interactions">
      <title>Explicit heat conduction from the road surface through the subsurface layers</title>
      {road_layer_interactions()}
    </g>
    <g id="road-snow-to-canyon">
      <title>Road snow temperature and heat exchange with canyon air</title>
      {interaction(ROAD_SNOW_NODE[0], 540, *ROAD_SNOW_NODE, air_exchange=True)}
      {model_node(*ROAD_SNOW_NODE)}
    </g>
    <g id="road-water-to-canyon">
      <title>Road liquid water storage and moisture exchange with canyon air</title>
      {interaction(ROAD_WATER_NODE[0], 540, *ROAD_WATER_NODE, air_exchange=True)}
      {model_node(*ROAD_WATER_NODE)}
    </g>
    <g id="traffic-heat-to-canyon">
      <title>Anthropogenic sensible heat from traffic entering the canyon air balance</title>
      <path id="traffic-heat-arrow" class="physical-interaction"
            d="M {CAR_X},{CAR_BASE_Y - CAR_ROOF_HEIGHT * CAR_SCALE:.3f} V 546 H {ATMOSPHERE_X} V 511"
            fill="none" stroke="{TRAFFIC_HEAT}" stroke-width="{INTERACTION_WIDTH}" stroke-linejoin="miter"/>
      <path d="M {ATMOSPHERE_X},505 L {ATMOSPHERE_X - 3.43},512 H {ATMOSPHERE_X + 3.43} Z" fill="{TRAFFIC_HEAT}"/>
      <g id="traffic-heat-label" text-anchor="end" fill="{TRAFFIC_HEAT}" font-size="{EXCHANGE_LABEL_SIZE}" font-weight="700">
        <text x="{CAR_X - 6}" y="554">Traffic</text>
        <text x="{CAR_X - 6}" y="568">heat</text>
      </g>
    </g>
    <g id="left-building-thermal-nodes">
      {building_temperature_nodes(LEFT_INDOOR_X, 1055, (1007, 1019, 1031), label_x=961)}
    </g>
    <g id="right-building-thermal-nodes">
      {building_temperature_nodes(RIGHT_INDOOR_X, 1393, (1441, 1429, 1417), label_x=1487)}
    </g>
    {model_node(ATMOSPHERE_X, ATMOSPHERIC_LEVEL, 5)}
    {model_node(GREEN_ROOF_X, ROOF_NODE_LEVEL)}
    {model_node(SOLAR_PANEL_X, ROOF_NODE_LEVEL)}
    {model_node(1224, 500, 5)}
    {model_node(GARDEN_SURFACE_X, GARDEN_SURFACE_Y)}
    {model_node(*ROAD_SURFACE_NODE)}
    <text x="{ATMOSPHERE_X + 12}" y="488" fill="{LABEL_TEXT}"
          font-size="{MODEL_HEADING_SIZE}" font-weight="700">Canyon air</text>
  </g>

  <g id="urban-flux-aggregation" fill="{EXCHANGE}">
    <title>Aggregation of fluxes from all urban surfaces</title>
    <!-- The small gaps in the brace leave the thermal wires visually separate. -->
    <path id="urban-surfaces-brace"
          d="M 921,297 C 921,287 931,283 945,283 H {GREEN_ROOF_X - 4.5}
             M {GREEN_ROOF_X + 4.5},283 H {LEFT_INDOOR_X - 4.5}
             M {LEFT_INDOOR_X + 4.5},283 H {SOLAR_PANEL_X - 4.5}
             M {SOLAR_PANEL_X + 4.5},283 H 1219.5
             M 1228.5,283 C 1243,283 1249,270 1254,251
             C 1259,270 1267,283 1282,283 H {RIGHT_INDOOR_X - 4.5}
             M {RIGHT_INDOOR_X + 4.5},283 H 1503 C 1517,283 1527,287 1527,297"
          fill="none" stroke="{EXCHANGE}" stroke-width="2.35" stroke-linecap="round" stroke-linejoin="round"/>
    <path id="urban-flux-output" d="M 1254,251 V 232" fill="none" stroke="{EXCHANGE}" stroke-width="2.7"/>
    <path d="M 1249,234 H 1259 L 1254,222 Z"/>
    <g id="aggregation-label" font-size="{FEATURE_LABEL_SIZE}" font-weight="700">
      <text x="1270" y="239">Aggregation over</text>
      <text x="1270" y="255">different surfaces</text>
    </g>
    <text id="aggregated-fluxes" x="1270" y="273" font-size="{MODEL_DETAIL_SIZE}">Urban heat and moisture fluxes</text>
  </g>

  <g id="structural-layer-labels" fill="{LABEL_TEXT}" font-size="{LAYER_LABEL_SIZE}">
    <path d="M 1019,604 V 622 M 912,404 H 916 V 441 H 930 M {ROAD_NEAR_CENTRE},{ROAD_LAYER_BOTTOM} V 682"
          fill="none" stroke="{LAYER_EDGE}" stroke-width="1.25"/>
    <text x="1019" y="637" text-anchor="middle">Wall layers</text>
    <text x="906" y="408" text-anchor="end">Roof layers</text>
    <text x="{ROAD_NEAR_CENTRE}" y="697" text-anchor="middle">Road layers</text>
  </g>
  </g>

  <g id="surface-interaction-labels" fill="{LABEL_TEXT}" font-size="{EXCHANGE_LABEL_SIZE}" font-weight="400" text-anchor="end">
    <text x="{GARDEN_SURFACE_X - 7}" y="569">Garden</text>
    <text x="{ROAD_SURFACE_NODE[0] - 7}" y="569">Road</text>
    <text x="{ROAD_WATER_NODE[0] - 6}" y="569">Puddles</text>
    <text x="{ROAD_SNOW_NODE[0] - 6}" y="569">Snow</text>
  </g>
  </g>
</svg>
'''

svg = "\n".join(line.rstrip() for line in svg.splitlines()) + "\n"

if __name__ == "__main__":
    output = Path(__file__).resolve().parents[1] / "img" / "teb-msu-coupling.svg"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(svg, encoding="utf-8")
